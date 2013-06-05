-module (wf_core).
-author('Maxim Sokhatsky').
-include_lib("n2o/include/wf.hrl").
-compile (export_all).

run(Req) ->
    Ctx = wf_context:init_context(Req),
    Ctx1 = fold(init,Ctx#context.handlers,Ctx),
    wf_context:actions(Ctx1#context.actions),
    Module = Ctx1#context.module,
    Params = Ctx1#context.params,
    wf_context:page_module(Module),
    wf_context:params(Params),
    wf_context:context(Ctx1),
    render(Module:main()), % render the actions
    Actions = wf_context:actions(),
    Pid = spawn(fun() -> transition(Actions) end),
    PidString = io_lib:format("~p",[Pid]),
    wf_context:script(["TransitionProcess = '", PidString, "'"]),
    Elements = Module:main(),
    Html = render(Elements),
    Ctx2 = fold(finish,Ctx#context.handlers,Ctx1),
    Req2 = wf:response(Html,Ctx2#context.req),
    {ok, _ReqFinal} = wf:reply(200, Req2).

fold(Fun,Handlers,Ctx) ->
    lists:foldl(fun({_,Module},Ctx1) ->
        {ok,_,NewCtx} = Module:Fun([],Ctx1),
        NewCtx end,Ctx,Handlers).

transition(Actions) -> receive {'N2O',Pid} -> Pid ! Actions end.

render_item(E) when element(2,E) == is_element -> wf_render_elements:render_element(E);
render_item(E) when element(2,E) == is_action  -> wf_render_actions:render_action(E);
render_item(E) -> E.

render(<<E/binary>>) -> E;
render(undefined) -> undefined;
render(Elements) when is_list(Elements) -> [ render_item(E) || E <- lists:flatten(Elements) ];
render(Elements) -> render_item(Elements).
