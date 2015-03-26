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
	{ok, [{Body,_}], _} = cowboy_req:body_qs(Req),
	io:format("~ts",[Body]),
    Xml = binary_to_list(Body),
	{FromUserName,ToUserName,Content}=xml_parse(Xml),
	Rep="<xml>
		<ToUserName><![CDATA["++ToUserName++"]]></ToUserName>
		<FromUserName><![CDATA["++FromUserName++"]]></FromUserName>
		<CreateTime>12345678</CreateTime>
		<MsgType><![CDATA[text]]></MsgType>
		<Content><![CDATA[自动回复：哈儿 你说了："++Content++"]]></Content>
		</xml>",
	io:format("~ts",[Rep]),
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"xml/plain; charset=utf-8">>}
	], unicode:characters_to_binary(Rep), Req);
maybe_echo(_, _, Req) ->
	%% Method not allowed.
	io:format(" ~p  ~n",["ttt"]),
	cowboy_req:reply(405, Req).
xml_parse(Xml)->
	%io:format("~p ~n ", [code:get_path()]), 
	io:format("~p ~n ", [Xml]), 
 	{Doc, _} =xmerl_scan:string(Xml),
	%io:format(" ~p  ~n",[Doc]),
	[{_,_,_,_,Content,_}]=xmerl_xpath:string("/xml/Content/text()", Doc),
	[{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
	[{_,_,_,_,ToUserName,_}]=xmerl_xpath:string("/xml/FromUserName/text()", Doc),
	%[{xmlText,[{'Content',10},{xml,1}],
    %      1,[],"this is a test",cdata}]
	{FromUserName,ToUserName,Content}.