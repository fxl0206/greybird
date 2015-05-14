-module(status_sup).
-behaviour(supervisor).
-export([start_link/0]).
-export([init/1]).
start_link() ->    
    supervisor:start_link(status_sup, []).
init(_Args) ->  
    Procs = [{status_server, {status_server, start_link, []},permanent, brutal_kill, worker, [status_server]}],
        {ok, {{one_for_one, 10, 10}, Procs}}. 
