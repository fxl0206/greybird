%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(auth_handler).
-include_lib("amqp_client/include/amqp_client.hrl").
-export([init/2]).
init(Req, Opts) ->
	Method = cowboy_req:method(Req),
	HasBody = cowboy_req:has_body(Req),
	io:format(" ~p  ~n",[Method]),
	Req2 = maybe_echo(Method, HasBody, Req),
	{ok, Req2, Opts}.

%token auth action
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

%acception message and auto reply action
maybe_echo(<<"POST">>, true, Req) ->
	%{data, Result} = 
        %Rows = mysql:get_result_rows(Result),
	%io:format("~p ~n",[Result]),
	{ok, [{Body,_}], _} = cowboy_req:body_qs(Req),
	io:format("~ts",[Body]),
	MetaData=xml_parse(binary_to_list(Body)),
	rmq_worker:cast_msg(Body),
	{FromUserName,ToUserName,Content}=MetaData,
	case Content of
        %查询记事本所有内容
         "LS" ->        
			{data, Result} = mysql:fetch(conn,<<"select * from wx_msg order by seq desc">>),
	        	Rows = mysql:get_result_rows(Result),
			Msg=get_top6asc(Rows),
			Ctent="灰色的记事本:"++Msg,
			io:format("~p ~n",[Rows]);
        %RabitMQ 测试
		"TS" ->
		    Ctent="收到一条测试消息："++Content,
		    io:format("~n ~p @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  ~n",[Ctent]),
			rmq_worker:send_msg(Body);
        %匹配"CX"打头的关键字，查询并返回查询结果
        [$C|[$X|Condition]] ->
            case Condition of
                [] ->
                    Ctent="查询条件不符合规范，请确认！";
                _ ->
                    Sql="select * from azw_book where name like '%"++Condition++"%'",
                    io:format("~ts",[Sql]),
                    {data, Result} = mysql:fetch(conn,unicode:characters_to_binary(Sql)),
                    Rows = mysql:get_result_rows(Result),
                    Msg=parse_azw(Rows),
                    Ctent="查询结果:"++Msg
            end,
            rmq_worker:send_msg(Body);
        %在记事本中记录日志
         _ ->
			Sql="insert into wx_msg(msgid,type,content,fuser,tuser,create_time) values('1','text','"++Content++"','"++FromUserName++"','"++ToUserName++"',now())",
	        	mysql:fetch(conn,unicode:characters_to_binary(Sql)),
			Ctent="你刚写了日志："++Content
        end,
    {{Year,Month,Day},{Hour,Min,Second}}=calendar:local_time(),
     case {Month,Day}  of 
        {4,27} ->
           Spstr="\n\n祝小鸟生日快乐，天天开心！";
        {5,10} ->
           Spstr="\n\n祝小鸟生日快乐，天天开心！";
        _ ->
           Spstr=" "
      end,
	Rep="<xml>
		<ToUserName><![CDATA["++ToUserName++"]]></ToUserName>
		<FromUserName><![CDATA["++FromUserName++"]]></FromUserName>
		<CreateTime>12345678</CreateTime>
		<MsgType><![CDATA[text]]></MsgType>
		<Content><![CDATA["++Ctent++Spstr++"]]></Content>
		</xml>",
	io:format("~ts",[Rep]),
	cowboy_req:reply(200, [
		{<<"content-type">>, <<"xml/plain; charset=utf-8">>}
	], unicode:characters_to_binary(Rep), Req);

%default action
maybe_echo(_, _, Req) ->
	io:format(" ~p  ~n",["Method not allowed"]),
	cowboy_req:reply(405, Req).

%发送消息到RabbitMQ
main(Msg) ->
    {ok, Connection} =amqp_connection:start(#amqp_params_network{host = "localhost"}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'queue.declare'{queue = <<"hello">>}),
    amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = <<"hello">>},
                      #amqp_msg{payload = Msg}),
    io:format(" [x] Send ~ts",[Msg]),
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.
%记录转换
get_top6asc(Rows)->
	case Rows of 
		[] ->
			[];
		[Row|Ohters] ->
			[MsgId|[MsgType|[Content|[Fuser|[Tuser|[Seq|[CreateTime|_]]]]]]]=Row,
			{date,{Year,Month,Day}}=CreateTime,
			Date=lists:flatten(
      				io_lib:format("~4..0w-~2..0w-~2..0w",
            			[Year, Month, Day])),
			%io:format("~ts",[Date]),
			[get_top6asc(Ohters)|["\n\n","["++Date++"]"++Content]]
    end.	
parse_azw(Rows)->
    case Rows of 
        [] ->
            [];
        [Row|Ohters] ->
            [Id|[Name|[Path|[Index|[DownPath|_]]]]]=Row,
            [parse_azw(Ohters)|["\n\n",Name]]
    end.    		
%weixin xml parse 
xml_parse(Xml)->
	%io:format("~p ~n ", [code:get_path()]), 
 	{Doc, _} =xmerl_scan:string(Xml),
	%[{xmlText,[{'Content',10},{xml,1}],
    %      1,[],"this is a test",cdata}]
	[{_,_,_,_,Content,_}]=xmerl_xpath:string("/xml/Content/text()", Doc),
	[{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
	[{_,_,_,_,ToUserName,_}]=xmerl_xpath:string("/xml/FromUserName/text()", Doc),
	{FromUserName,ToUserName,Content}.
