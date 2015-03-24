%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(auth_handler).

-export([init/2]).

init(Req, Opts) ->
	Method = cowboy_req:method(Req),
	HasBody = cowboy_req:has_body(Req),
	io:format(" ~p  ~n",[Method]),
	Req2 = maybe_echo(Method, HasBody, Req),
	{ok, Req2, Opts}.
maybe_echo(<<"GET">>, false, Req) ->
	Token="myluckyfxl",
	#{signature:=Signature,timestamp:=Timestamp,nonce:=Nonce,echostr:=Echostr} = cowboy_req:match_qs([signature,timestamp,nonce,echostr], Req),
	Tmps = [Token,Timestamp,Nonce],
	io:format("~p ~n ~p ~n", [Token, Signature]),
	List2=lists:usort(Tmps),
	%%crypto:md5_mac(sha,List2),
	%string:to_lower(lists:flatten([[integer_to_list(N, 16) || <<N:4>> <= crypto:sha_mac("hello", "world")]])),
	io:format(" ~p  ~n",[List2]),
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"text/plain; charset=utf-8">>}
	], Echostr, Req);
maybe_echo(<<"POST">>, true, Req) ->
	Token="myluckyfxl",
	io:format("~p ~n ", [Token]),
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
	io:format(" ~p  ~n",["ttt"]),
	cowboy_req:reply(405, Req).