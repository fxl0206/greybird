%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(qy_handler).
-export([init/2]).
-define(TOKEN,"lWpmoIilmtlWm").
-define(AESKEY,"XSODyEIWuOYwUImf9E874THanu4Zy1245sX13XXGYxG=").

init(Req, Opts) ->
    Method = cowboy_req:method(Req),
    HasBody = cowboy_req:has_body(Req),
    Req2 = maybe_echo(Method, HasBody, Req),
    {ok, Req2, Opts}.

%token auth action
maybe_echo(<<"GET">>, false, Req) ->
    Token=?TOKEN,
    Aeskey=base64:decode(?AESKEY),
    KeyList=binary_to_list(Aeskey),
    IvList=lists:sublist(KeyList,1,16),
    Iv=list_to_binary(IvList),

    #{msg_signature:=Signature,timestamp:=Timestamp,nonce:=Nonce,echostr:=Echostr} = cowboy_req:match_qs([msg_signature,timestamp,nonce,echostr], Req),

    %验证签名
    Dev_msg_signature=wx_tool:create_dev_signature(Token,Signature,Timestamp,Nonce,Echostr),
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
    io:format("echo is  ***********************############~n ~p ~n################",[Echo]),
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"text/plain; charset=utf-8">>}
    ], Echo, Req);
%acception message and auto reply action
maybe_echo(<<"POST">>, true, Req) ->
    {ok,AesBody,Headers} = cowboy_req:body(Req),
    % StartTime=timestamp(),
    % Timestamp=list_to_binary("1430801386"),
    % Nonce=list_to_binary("102039232"),
    % Signature=list_to_binary("7a523c5a28f7197bb44b10529ae24fb64eb8576e"),
    #{msg_signature:=Signature,timestamp:=Timestamp,nonce:=Nonce} = cowboy_req:match_qs([msg_signature,timestamp,nonce], Req),

    io:format("~ts~n",[AesBody]),
    io:format("~p~n",[Headers]),
    {FromUserName,AgentID,Encrypt}=wx_tool:msg_package_parse(binary_to_list(AesBody)),

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
    {FromUserName,ToUserName,Content}=wx_tool:msg_body_parse(Body),
    % io:format("~n~n~ts~n~n",[Body]),
    %rmq_worker:cast_msg(Body),
    case Content of
        %查询记事本所有内容
         "LS" ->        
            {data, Result} = mysql:fetch(conn,<<"select * from wx_msg order by seq desc">>),
                Rows = mysql:get_result_rows(Result),
            Msg=wx_tool:get_top6asc(Rows),
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
                    Msg=wx_tool:parse_azw(Rows),
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
        <Content><![CDATA["++Ctent++"88888888]]></Content>
        <AgentID>0</AgentID>
        </xml>",
    Dev_msg_signature=wx_tool:create_dev_signature(Token,Signature,Timestamp,Nonce,Str),

    % io:format("~ts",[Dev_msg_signature]),
    Ivlst=utils:def_to_hex_string(list_to_binary(IvList)),
    % io:format("******************~p~n",[Iv]),
    % io:format("******************~p~n",[[length(Rep)]]),
    % io:format("******************~p~n",[Rep]),
    LLen=length(Rep),
    % io:format("~nb**this length is ***~p~n",[length(Rep)+16+4+18]), 
    
    Rep2=wx_tool:random()++binary_to_list(<<LLen:4/unit:8>>)++Rep++"wxc02de619d60b35f4",
    %Rep2="714d8dba996d0c72"++binary_to_list(<<LLen:4/unit:8>>)++Rep++"wxc02de619d60b35f4999999",
    % io:format("~nb**this length is ***~p~n",[length(Rep2)]),

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
   %  Rep3="<xml>
   % <Encrypt><![CDATA[b4aLi9FV+3yIeONCaFhNH8rTfnWpP61uXsv6LYQ6MACB4+LSdy9yeFq7svferBBbYlOtJjBmHBpkFN92FuEQZL5IVufP17EnkWyUBOVWx/agNelWKBROeulNLtoH6HmU+qkLEEyhOOfHXkQ7IJdVcU17hkbFMMiFUVOfAY39w6oXXiQ+jnuPt0pt7ul2CkajErX6uhX8JhM4W5hDmAylioikMxPqHNsp++QQkSWitphgvIzPqJ3ORzZzPpxrZIRNqjTwmZau/zFgQSvkAorLhJ4u3/NqOnbtdjFdY8jjA2iikyw3ZkcSoHMTqVh6wSyjfNbq4QxDWrD34BPSUZH7rkH2Xp2nBSdQipe8uzGoGC3jtnQRL4mD/nH+xjaXv3PhT0ZpWNCy8MiilaejOSwD3c0BHcj1atZyiUBMqRSJwVqa6Xwq5S/LcigSathCGjwXOgMp40po/Z5LoeWoDrZrvw==]]></Encrypt>
   % <MsgSignature><![CDATA[f62866e06a6428954d316a1d4a13ed8f0452092d]]></MsgSignature>
   % <TimeStamp>1430801386</TimeStamp>
   % <Nonce><![CDATA[102039232]]></Nonce>
   % <AgentID>0</AgentID>
   %  </xml>",
    % io:format("use time is ~p~n",[timestamp()-StartTime]),
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"text/xml; charset=utf-8">>}
    ], unicode:characters_to_binary(Rep3), Req);

%default action 
maybe_echo(_, _, Req) ->
    io:format(" ~p  ~n",["Method not allowed"]),
    cowboy_req:reply(405, Req).        
timestamp() ->
    calendar:datetime_to_gregorian_seconds(erlang:universaltime()).
