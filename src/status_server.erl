-module(status_server).

-behaviour(gen_server).

-export([start_link/0,handle_call/3,init/1,terminate/2,handle_cast/2,handle_info/2,code_change/3]).
-export([get_stat/1,change_stat/2]).
-export([get_cache_msg/1,del_cache_msg/1,cache_msg/2]).

-define(TAB,status).
-define(MSG_TAB,msg_cache).

start_link() ->
    gen_server:start_link({local,?MODULE},?MODULE,[],[]).

%查询当前消息模式
get_stat(UserId) ->
    gen_server:call(?MODULE,{qrystat,UserId}).

change_stat(UserId,Stat) ->
    gen_server:cast(?MODULE,{change_state,UserId,Stat}).

%缓存最近一条消息
cache_msg(UserId,Msg) ->
    gen_server:call(?MODULE,{cache_msg,UserId,Msg}).

%获取缓存的最近一条消息
get_cache_msg(UserId) ->
    gen_server:call(?MODULE,{cache_msg,UserId}).

%删除缓存的最近一条消息
del_cache_msg(UserId) ->
    gen_server:call(?MODULE,{del_cache_msg,UserId}).

handle_call({qrystat,UserId},_From,State) ->
    Stat=ets:lookup(?TAB, {userid, UserId}),
    case Stat of 
        [] ->
            Code=error;
        [{_,Tag}|[]] ->
            Code=Tag
    end,
    {reply,Code,State};

handle_call({cache_msg,UserId,Msg},_From,State) ->
     Result=ets:insert(?MSG_TAB, {{userid, UserId}, Msg}),
    {reply,Result,State};

handle_call({cache_msg,UserId},_From,State) ->
    Stat=ets:lookup(?MSG_TAB, {userid, UserId}),
    case Stat of 
        [] ->
            Ret=error;
        [{_,Msg}|[]] ->
            Ret=Msg
    end,
    {reply,Ret,State};

handle_call({del_cache_msg,UserId},_From,State) ->
    Stat=ets:delete(?MSG_TAB, {userid, UserId}),
    {reply,Stat,State}.
%
init([]) ->
    io_log("init msg status !"),
    State = ets:new(?TAB, [
        set, public, named_table]),
    _ = ets:new(?MSG_TAB, [
        set, public, named_table]),
    {ok,State}.

handle_cast({change_state,UserId,Stat}, State) -> 
    ets:insert(?TAB, {{userid, UserId}, Stat}),
    {noreply,State}.

code_change(_,_,_) ->
    ok.

handle_info(_,_) ->
    ok.

terminate(_,State) ->
    io_log("release pool").

io_log(Info) ->
    io:format("~n ***************  ~p *****************  ~n",[Info]).