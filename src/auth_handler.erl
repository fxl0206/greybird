%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(auth_handler).

-export([init/2]).

init(Req, Opts) ->
	Method = cowboy_req:method(Req),
	HasBody = cowboy_req:has_body(Req),
	Req2 = maybe_echo(Method, HasBody, Req),
	{ok, Req2, Opts}.

maybe_echo(<<"POST">>, true, Req) ->
	Token="myluckyfxl",
	{ok, PostVals, _} = cowboy_req:body_qs(Req),
	Signature = proplists:get_value(<<"signature">>, PostVals),
	Timestamp = proplists:get_value(<<"timestamp">>, PostVals),
	Nonce = proplists:get_value(<<"nonce">>, PostVals),
	Echostr = proplists:get_value(<<"echostr">>, PostVals),
	Tmps = [Token,Timestamp,Nonce],
	io:format("~p ~n ~p ~n", [Token, Signature]),
	lists:usort(Tmps),
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"text/plain; charset=utf-8">>}
	], Echostr, Req);
maybe_echo(_, _, Req) ->
	%% Method not allowed.
	cowboy_req:reply(405, Req).