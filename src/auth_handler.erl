%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(auth_handler).

-export([init/2]).

init(Req, Opts) ->
	Method = cowboy_req:method(Req),
	#{echo := Echo} = cowboy_req:match_qs([echo], Req),
	Req2 = echo(Method, Echo, Req),
	{ok, Req2, Opts}.
echo(<<"POST">>,undefined,Req) ->
	Token="myluckyfxl",
	#{signature:=Signature,timestamp:=Timestamp,nonce:=Nonce,echostr:=Echostr} = cowboy_req:match_qs([echo], Req),
	Tmps = [Token,Timestamp,Nonce],
	lists:usort(Tmps),
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"text/plain; charset=utf-8">>}
	], Echostr, Req);
echo(<<"GET">>, undefined, Req) ->
	cowboy_req:reply(400, [], <<"Missing echo parameter.">>, Req);
echo(<<"GET">>, Echo, Req) ->
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"text/plain; charset=utf-8">>}
	], Echo, Req);
echo(_, _, Req) ->
	%% Method not allowed.
	cowboy_req:reply(405, Req).
