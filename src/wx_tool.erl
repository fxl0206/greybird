-module(wx_tool).
-export([msg_body_parse/1,msg_package_parse/1,create_dev_signature/5]).
-export ([random/0]).

%消息体
msg_body_parse(Xml)->
    {Doc, _} =xmerl_scan:string(Xml),
    [{_,_,_,_,Content,_}]=xmerl_xpath:string("/xml/Content/text()", Doc),
    [{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
    [{_,_,_,_,ToUserName,_}]=xmerl_xpath:string("/xml/FromUserName/text()", Doc),
    {FromUserName,ToUserName,Content}.

msg_package_parse(Xml)->
    {Doc, _} =xmerl_scan:string(Xml),
    [{_,_,_,_,AgentID,_}]=xmerl_xpath:string("/xml/AgentID/text()", Doc),
    [{_,_,_,_,FromUserName,_}]=xmerl_xpath:string("/xml/ToUserName/text()", Doc),
    [{_,_,_,_,Encrypt,_}]=xmerl_xpath:string("/xml/Encrypt/text()", Doc),
    %io:format("######~ts########",[FromUserName]),
    {FromUserName,AgentID,Encrypt}.

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

%生成签名
create_dev_signature(Token,Signature,Timestamp,Nonce,Encrypt) ->
    [P1,P2,P3,P4]=lists:sort([Token,binary_to_list(Timestamp),binary_to_list(Nonce),binary_to_list(Encrypt)]),
    string:to_lower(utils:def_to_hex_string(crypto:sha(list_to_binary(P1++P2++P3++P4)))).

%随机生成16位值
 random() ->
  Str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_",
  %%一次随机取多个，再分别取出对应值
  N = [random:uniform(length(Str)) || _Elem <- lists:seq(1,16)],
  RandomKey = [lists:nth(X,Str) || X<- N ],
  RandomKey. 