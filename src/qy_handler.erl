%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(qy_handler).
-include_lib("amqp_client/include/amqp_client.hrl").
-export([init/2]).
-define(TOKEN,"lWpmoIilmtlWm").
-define(AESKEY,"XSODyEIWuOYwUImf9E874THanu4Zy1245sX13XXGYxG=").
def_to_hex_string(Bl) ->
    lists:foldl(fun(X, Sum) ->
        if 
            X>16 ->
                Sum++integer_to_list(X,16);
            X<17 ->
                Sum++"0"++integer_to_list(X band 16#FF,16)
        end end, [], binary_to_list(Bl)).

%生成签名
create_dev_signature(Token,Signature,Timestamp,Nonce,Encrypt) ->
    [P1,P2,P3,P4]=lists:sort([Token,binary_to_list(Timestamp),binary_to_list(Nonce),binary_to_list(Encrypt)]),
    string:to_lower(def_to_hex_string(crypto:sha(list_to_binary(P1++P2++P3++P4)))).

init(Req, Opts) ->
    Method = cowboy_req:method(Req),
    HasBody = cowboy_req:has_body(Req),
    io:format(" ~p  ~n",[Method]),
    Req2 = maybe_echo(Method, HasBody, Req),
    {ok, Req2, Opts}.
%随机生成16位值
 random() ->
  Str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",
  %%一次随机取多个，再分别取出对应值
  N = [random:uniform(length(Str)) || _Elem <- lists:seq(1,16)],
  RandomKey = [lists:nth(X,Str) || X<- N ],
  RandomKey. 

%token auth action
maybe_echo(<<"GET">>, false, Req) ->
    Token=?TOKEN,
    Aeskey=base64:decode(?AESKEY),
    KeyList=binary_to_list(Aeskey),
    IvList=lists:sublist(KeyList,1,16),
    Iv=list_to_binary(IvList),

    #{msg_signature:=Signature,timestamp:=Timestamp,nonce:=Nonce,echostr:=Echostr} = cowboy_req:match_qs([msg_signature,timestamp,nonce,echostr], Req),

    %验证签名
    Dev_msg_signature=create_dev_signature(Token,Signature,Timestamp,Nonce,Echostr),
    Msg_signature=binary_to_list(Signature),
    %io:format("############~n ~p ~n################",[Msg_signature]),
    %io:format("############~n ~p ~n################",[Dev_msg_signature]),
    case Dev_msg_signature of
        Msg_signature ->
            %AES内容解密
            EchostrAesData=base64:decode_to_string(Echostr),
            Str=crypto:aes_cbc_128_decrypt(Aeskey,Iv,list_to_binary(EchostrAesData)),

            Strlist=binary_to_list(Str),
            <<C:32>>=list_to_binary(lists:sublist(Strlist,17,4)),
            Echo=lists:sublist(Strlist,21,C);
        _ ->
            Echo="-40001"
    end,
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"text/plain; charset=utf-8">>}
    ], Echo, Req);

%acception message and auto reply action
maybe_echo(<<"POST">>, true, Req) ->
    %{data, Result} = 
        %Rows = mysql:get_result_rows(Result),
    %io:format("~p ~n",[Result]),
    %cowboy_req:body_qs(Req), 
     #{msg_signature:=Signature,timestamp:=Timestamp,nonce:=Nonce} = cowboy_req:match_qs([msg_signature,timestamp,nonce], Req),

    {ok,AesBody,Headers} = cowboy_req:body(Req),
    io:format("~ts~n",[AesBody]),
    io:format("~p~n",[Headers]),
    {FromUserName,AgentID,Encrypt}=perse_xml_data(binary_to_list(AesBody)),

    Token=?TOKEN,
    Aeskey=base64:decode(?AESKEY),
    KeyList=binary_to_list(Aeskey),
    % io:format("~n22222~n~p~n~n",[KeyList]),
    IvList=lists:sublist(KeyList,1,16),
    Iv=list_to_binary(IvList),
    EchostrAesData=base64:decode_to_string(Encrypt),
    Str=crypto:aes_cbc_128_decrypt(Aeskey,Iv,list_to_binary(EchostrAesData)),
    % io:format("~n~n~ts~n~n",[Str]),

    Strlist=binary_to_list(Str),
    <<C:32>>=list_to_binary(lists:sublist(Strlist,17,4)),
    % io:format("~n~n~p~n~n",[lists:sublist(Strlist,17,4)]),
    % io:format("~p~n",[C]),
    %io:format("~n~n~p~n~n",[df_sum(df_str_to_int(MsgLen))]),
    Body=lists:sublist(Strlist,21, C),
    {FromUserName,ToUserName,Content}=xml_parse(Body),
    io:format("~n~n~ts~n~n",[Body]),
    %rmq_worker:cast_msg(Body),
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
            %Ctent="收到一条测试消息："++Content,
            Ctent=Content;
            % io:format("~n ~p @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  ~n",[Ctent]);
            %rmq_worker:send_msg(Body);
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
    Rep="<xml>
        <ToUserName><![CDATA["++ToUserName++"]]></ToUserName>
        <FromUserName><![CDATA["++FromUserName++"]]></FromUserName>
        <CreateTime>"++binary_to_list(Timestamp)++"</CreateTime>
        <MsgType><![CDATA[text]]></MsgType>
        <Content><![CDATA["++Ctent++"]]></Content>
        <AgentID>0</AgentID>
        </xml>",
    Dev_msg_signature=create_dev_signature(Token,Signature,Timestamp,Nonce,Str),

    % io:format("~ts",[Dev_msg_signature]),
    Ivlst=def_to_hex_string(list_to_binary(IvList)),
    % io:format("******************~p~n",[Iv]),
    % io:format("******************~p~n",[[length(Rep)]]),
    % io:format("******************~p~n",[Rep]),
    LLen=length(Rep),
    % io:format("~nb**this length is ***~p~n",[length(Rep)+16+4+18]), 
    
    Rep2=random()++binary_to_list(<<LLen:4/unit:8>>)++Rep++"wxc02de619d60b35f488888888",
    %Rep2="714d8dba996d0c72"++binary_to_list(<<LLen:4/unit:8>>)++Rep++"wxc02de619d60b35f4999999",
    io:format("~nb**this length is ***~p~n",[length(Rep2)]),

    % io:format("******************~ts~n",[list_to_binary(Rep2)]),
    Str1=crypto:aes_cbc_128_encrypt(Aeskey,Iv,list_to_binary(Rep2)),
    % io:format("******************~ts",[Str1]),

    Imsg_encrypt=base64:encode_to_string(Str1),
    Rep3="<xml>
   <Encrypt><![CDATA["++Imsg_encrypt++"]]></Encrypt>
   <MsgSignature><![CDATA["++Dev_msg_signature++"]]></MsgSignature>
   <TimeStamp>"++binary_to_list(Timestamp)++"</TimeStamp>
   <Nonce><![CDATA["++binary_to_list(Nonce)++"]]></Nonce>
   <AgentID>0</AgentID>
    </xml>",
    io:format("~ts",[Rep3]),
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"text/xml; charset=utf-8">>}
    ], unicode:characters_to_binary(Rep3), Req);

%default action
maybe_echo(_, _, Req) ->
    io:format(" ~p  ~n",["Method not allowed"]),
    cowboy_req:reply(405, Req).

%get msg_length from 
df_str_to_int(Len) ->
    lists:dropwhile(fun(E) -> 0==E end,Len).

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

perse_xml_data(Xml)->
    {Doc, _} =xmerl_scan:string(Xml),
    [{_,_,_,_,AgentID,_}]=xmerl_xpath:string("/xml/AgentID/text()", Doc),
    [{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
    [{_,_,_,_,Encrypt,_}]=xmerl_xpath:string("/xml/Encrypt/text()", Doc),
    %io:format("######~ts########",[FromUserName]),
    {FromUserName,AgentID,Encrypt}.
%     <xml> 
%    <ToUserName><![CDATA[toUser]]</ToUserName>
%    <AgentID><![CDATA[toAgentID]]</AgentID>
%    <Encrypt><![CDATA[msg_encrypt]]</Encrypt>
% </xml>
%% Faster alternative to proplists:get_value/3.
get_value(Key, Opts, Default) ->
    case lists:keyfind(Key, 1, Opts) of
        {_, Value} -> Value;
        _ -> Default
    end.