%% Feel free to use, reuse and abuse the code in this file.

%% @doc GET echo handler.
-module(auth_handler).
-include_lib("amqp_client/include/amqp_client.hrl").
-export([init/2]).

-record(meta,{fuser,tuser,msgtype,data}).

init(Req, Opts) ->
	Method = cowboy_req:method(Req),
	HasBody = cowboy_req:has_body(Req),
	% io:format(" ~p  ~n",[Req]),
	Req2 = msg_controler(Method, HasBody, Req),
	{ok, Req2, Opts}.

msg_controler(Method,HashBody,Req) ->
    case Method of
        <<"GET">> ->
           maybe_echo(get,false,Req);
        <<"POST">> when HashBody == true ->
           Meta=meta(Req),
           rep_post(Meta, Req);
        _ ->
           maybe_echo(other,false,Req) 
    end.

%acception message and auto reply action
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "text" , data = [Content|[]]} , Req) ->
    State=status_server:get_stat(ToUserName),
    % io:format("~n$$$ ~p  $$$~n",[State]),
    case State of
        error ->
            Ctent="请先在消息模式菜单设置消息模式！当前支持如下模式：\n\n[1]写日志\n\n[2]查电子书\n\n[3]测试消息回复";
        %RabitMQ 测试
		"DO_TEST" ->
		    Ctent="收到一条测试消息："++Content;
			% rmq_worker:send_msg(Body);
        "QRY_BOOK" ->
            case Content of
                [] ->
                    Ctent="查询条件不符合规范，请确认！";
                _ ->
                    Sql="select * from azw_book where name like '%"++Content++"%'",
                    io:format("~ts",[Sql]),
                    {data, Result} = mysql:fetch(conn,unicode:characters_to_binary(Sql)),
                    Rows = mysql:get_result_rows(Result),
                    Msg=parse_azw(Rows),
                    Ctent="查询结果:"++Msg
            end;
        %在记事本中记录日志
         "NEW_NOTE" ->
			Sql="insert into wx_msg(msgid,type,content,fuser,tuser,create_time) values('1','text','"++Content++"','"++FromUserName++"','"++ToUserName++"',now())",
	        status_server:cache_msg(ToUserName,Sql),
            % mysql:fetch(conn,unicode:characters_to_binary(Sql)),
			Ctent="你刚写了日志："++Content++"\n\n确认提交请到记事本菜单操作!"
        end,
	rep_return(ToUserName,FromUserName,Ctent,Req);

%响应事件消息
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["HIS_NOTE"|[]]]}, Req) ->
            {data, Result} = mysql:fetch(conn,<<"select * from wx_msg order by seq desc">>),
            Rows = mysql:get_result_rows(Result),
            Msg=get_top6asc(Rows),
            Ctent="our记事本:"++Msg,
            rep_return(ToUserName,FromUserName,Ctent,Req);

%切换用户消息操作为写日志
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["NEW_NOTE"|[]]]}, Req) ->
            status_server:change_stat(ToUserName,"NEW_NOTE"),
            Ctent="已切换到写日志模式!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

%切换用户消息操作为查询电子书
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["QRY_BOOK"|[]]]}, Req) ->
            status_server:change_stat(ToUserName,"QRY_BOOK"),
            Ctent="已切换到查电子书模式!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

%切换用户消息操作为测试消息应答
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["DO_TEST"|[]]]}, Req) ->
            status_server:change_stat(ToUserName,"DO_TEST"),
            Ctent="已切换到测试消息回复模式!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

%万年历
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["calendar"|[]]]}, Req) ->
            Ctent="即将考虑实现!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

%生日本
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["birthdays"|[]]]}, Req) ->
            Ctent="即将考虑实现!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["DO_TEST1"|[]]]}, Req) ->
            Ctent="即将考虑实现!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["DO_TEST2"|[]]]}, Req) ->
            Ctent="即将考虑实现!",
            rep_return(ToUserName,FromUserName,Ctent,Req);

%提交发出的最近一条消息
rep_post(#meta{fuser = FromUserName, tuser = ToUserName ,msgtype = "event", data = ["CLICK"|["COMMIT_NOTE"|[]]]}, Req) ->
             Sql = status_server:get_cache_msg(ToUserName),
             case Sql of
                error ->
                  Ctent="没有要保存的日志！";
                _ ->
                  mysql:fetch(conn,unicode:characters_to_binary(Sql)),
                  status_server:del_cache_msg(ToUserName),
                  Ctent="日志保持成功！"
             end,
            rep_return(ToUserName,FromUserName,Ctent,Req).

%通用自动消息封装
rep_return(ToUserName,FromUserName,Msg,Req) ->
    Rep="<xml>
        <ToUserName><![CDATA["++ToUserName++"]]></ToUserName>
        <FromUserName><![CDATA["++FromUserName++"]]></FromUserName>
        <CreateTime>12345678</CreateTime>
        <MsgType><![CDATA[text]]></MsgType>
        <Content><![CDATA["++Msg++spec_msg()++"]]></Content>
        </xml>",
    % io:format("~ts",[Rep]),
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"xml/plain; charset=utf-8">>}
    ], unicode:characters_to_binary(Rep), Req).

%特殊时间返回特殊消息
spec_msg() ->
    {{Year,Month,Day},{Hour,Min,Second}}=calendar:local_time(),
     case {Month,Day}  of 
        {5,11} ->
           Spstr="\n\n生日快乐！";
        {5,10} ->
           Spstr="\n\n";
        _ ->
           Spstr=" "
      end.
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
%格式化电子书查询结果	
parse_azw(Rows)->
    case Rows of 
        [] ->
            [];
        [Row|Ohters] ->
            [Id|[Name|[Path|[Index|[DownPath|_]]]]]=Row,
            [parse_azw(Ohters)|["\n\n",Name]]
    end.    		
%获取消息元数据
meta(Req) ->
       {ok, [{Body,_}], _} = cowboy_req:body_qs(Req),
       % io:format("~ts",[Body]),
       rmq_worker:cast_msg(Body),
       {Doc, _} =xmerl_scan:string(binary_to_list(Body)),
       [{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
       [{_,_,_,_,MsgType,_}]=xmerl_xpath:string("/xml/MsgType/text()", Doc),
       [{_,_,_,_,ToUserName,_}]=xmerl_xpath:string("/xml/FromUserName/text()", Doc),
        case MsgType of
            "text" ->
                [{_,_,_,_,Content,_}]=xmerl_xpath:string("/xml/Content/text()", Doc),
                Data=[Content];
            "event" ->
                [{_,_,_,_,Event,_}]=xmerl_xpath:string("/xml/Event/text()", Doc),
                [{_,_,_,_,EventKey,_}]=xmerl_xpath:string("/xml/EventKey/text()", Doc),
                Data=[Event,EventKey]
        end,
        #meta{fuser = FromUserName, tuser = ToUserName, msgtype = MsgType, data = Data}.

%服务有效验证
maybe_echo(get, false, Req) ->
    Token="myluckyfxl",
    #{signature:=Signature,timestamp:=Timestamp,nonce:=Nonce,echostr:=Echostr} = cowboy_req:match_qs([signature,timestamp,nonce,echostr], Req),
    
    Dev_msg_signature=create_dev_signature(Token,Timestamp,Nonce),
    Msg_signature=binary_to_list(Signature),
    case Dev_msg_signature of
      Msg_signature ->
          Reply=Echostr;
      _ ->
          Reply="can not know the signature!"
    end,
    cowboy_req:reply(200, [
        {<<"content-type">>, <<"text/plain; charset=utf-8">>}
    ], Reply, Req);
%default action
maybe_echo(_, _, Req) ->
    io:format(" ~p  ~n",["Method not allowed"]),
    cowboy_req:reply(405, Req).

%生成签名
create_dev_signature(Token,Timestamp,Nonce) ->
    [P1,P2,P3]=lists:sort([Token,binary_to_list(Timestamp),binary_to_list(Nonce)]),
    string:to_lower(utils:def_to_hex_string(crypto:sha(list_to_binary(P1++P2++P3)))). 