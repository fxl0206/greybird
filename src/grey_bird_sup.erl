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
        PoolOptions  = [{size, 10}, {max_overflow, 20}],
    MySqlOptions = [{user, "root"}, {password, "286955"}, {database, "greybird"},
                    {prepare, [{wx_msg, "SELECT * FROM wx_msg WHERE seq=?"}]}],
        Procs=mysql_poolboy:child_spec(pool1, PoolOptions, MySqlOptions),
	%Procs = [{mysql, {mysql, start_link, [conn,"127.0.0.1",undefined,"root","286955","greybird",utf8]},permanent, brutal_kill, worker, [mysql]}],
	%Procs=[],
	{ok, {{one_for_one, 10, 10}, Procs}}.
