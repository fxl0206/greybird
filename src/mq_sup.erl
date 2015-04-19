-module(mq_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).
start_link() ->    
	supervisor:start_link(mq_sup, []).
init(_Args) ->  
	%Procs = [{rmqpool, {rmqpool, start_link, []},permanent, brutal_kill, worker, [rmqpool]}],
	Procs = [{rmq_worker, {rmq_worker, start_link, []},permanent, brutal_kill, worker, [rmq_worker]}],
        {ok, {{one_for_one, 10, 10}, Procs}}. 
