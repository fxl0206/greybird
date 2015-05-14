-module(status_server).

-behaviour(gen_server).

-export([start_link/0,handle_call/3,init/1,terminate/2,handle_cast/2,handle_info/2,code_change/3]).
-export([get_stat/1,change_stat/2]).
-define(TAB,status).
start_link() ->
    gen_server:start_link({local,?MODULE},?MODULE,[],[]).

get_stat(UserId) ->
    gen_server:call(?MODULE,{qrystat,UserId}).

change_stat(UserId,Stat) ->
    gen_server:cast(?MODULE,{change_state,UserId,Stat}).

handle_call({qrystat,UserId},_From,State) ->
    Stat=ets:lookup_element(?TAB, {userid, UserId}, 2),
    {reply,Stat,State}.

init([]) ->
    io_log("init msg status !"),
    State = ets:new(?TAB, [
        ordered_set, public, named_table]),
    {ok,State}.

handle_cast({change_state,UserId,Stat}, State) -> 
    ets:insert_new(?TAB, {{userid, UserId}, Stat}),
    {noreply,State}.

code_change(_,_,_) ->
    ok.

handle_info(_,_) ->
    ok.

terminate(_,State) ->
    io_log("release pool").

io_log(Info) ->
    io:format("~n ***************  ~p *****************  ~n",[Info]).