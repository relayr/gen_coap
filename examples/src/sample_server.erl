-module(sample_server).
-export([start/0]).

-behaviour(coap_resource).

-export([coap_discover/2,
         coap_get/6,
         coap_post/6,
         coap_put/6,
         coap_delete/5,
         coap_observe/6,
         coap_unobserve/2,
         handle_info/2,
         coap_ack/2]).

-include("coap.hrl").

% resource operations
coap_discover(Prefix, _Args) ->
    io:format("discover ~p~n", [Prefix]),
    [{absolute, Prefix++Name, []} || Name <- mnesia:dirty_all_keys(resources)].

coap_get(_ChId, Port, Prefix, [<<"oic">>, <<"res">>] = Name, Query, _Request) ->
    io:format("get ~p ~p ~p ~p~n", [Port, Prefix, Name, Query]),
    #coap_content{etag = <<"1234">>,
                  format = <<"text/plain">>};
coap_get(_ChId, Port, Prefix, Name, Query, _Request) ->
    io:format("get ~p ~p ~p ~p~n", [Port, Prefix, Name, Query]),
    case mnesia:dirty_read(resources, Name) of
        [{resources, Name, Resource}] -> Resource;
        [] -> {error, not_found}
    end.

coap_post(_ChId, _Port, _Prefix, [<<"stop">>], _Content, _Request) ->
    main ! stop,
    {ok, content, #coap_content{}};
coap_post(_ChId, Port, Prefix, Name, Content, _Request) ->
    io:format("post ~p ~p ~p ~p~n", [Port, Prefix, Name, Content]),
    {error, method_not_allowed}.

coap_put(_ChId, Port, Prefix, Name, Content, _Request) ->
    io:format("put ~p ~p ~p ~p~n", [Port, Prefix, Name, Content]),
    mnesia:dirty_write(resources, {resources, Name, Content}),
    coap_responder:notify(Prefix++Name, Content),
    ok.

coap_delete(_ChId, Port, Prefix, Name, _Request) ->
    io:format("delete ~p ~p ~p~n", [Port, Prefix, Name]),
    mnesia:dirty_delete(resources, Name),
    coap_responder:notify(Prefix++Name, {error, not_found}),
    ok.

coap_observe(_ChId, Port, Prefix, Name, _Ack, _Request) ->
    io:format("observe ~p ~p ~p~n", [Port, Prefix, Name]),
    {ok, {state, Prefix, Name}}.

coap_unobserve(Port, {state, Prefix, Name}) ->
    io:format("unobserve ~p ~p ~p~n", [Port, Prefix, Name]),
    ok.

handle_info(_Message, State) -> {noreply, State}.
coap_ack(_Ref, State) -> {ok, State}.

start() ->
    register(main, self()),
    ok = application:start(mnesia),
    {atomic, ok} = mnesia:create_table(resources, []),
    {ok, _} = application:ensure_all_started(gen_coap),
    {ok, _} = coap_server:start_udp(coap_udp_socket),
    % {ok, _} = coap_server:start_dtls(coap_dtls_socket, [{certfile, "cert.pem"}, {keyfile, "key.pem"}]),
    coap_server_registry:add_handler([], ?MODULE, undefined).

% end of file
