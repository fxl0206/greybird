%% Feel free to use, reuse and abuse the code in this file.

%% @private
-module(grey_bird_sup).
-behaviour(supervisor).

%% API.
-export([start_link/0]).

%% supervisor.
-export([init/1]).

%% API.

-spec start_link() -> {ok, pid()}.
start_link() ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% supervisor.

init([]) ->
	Procs = [{mysql, {mysql, start_link, [conn,"127.0.0.1",3306,"root","286955","greybird",undefined,utf8]},permanent, brutal_kill, worker, [mysql]},
		{mq_sup, {mq_sup, start_link, []},permanent, brutal_kill, supervisor, [mq_sup]}
		],
	%Procs=[],
	{ok, {{one_for_one, 10, 10}, Procs}}.
