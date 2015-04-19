-module(rmq_worker).

-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

-define(QUEUE, <<"wx_msg">>).
-define(POOL_NUM, 5).

-export([start_link/0,handle_call/3,init/1,terminate/2,handle_cast/2,handle_info/2,code_change/3]).
-export([send_msg/1,cast_msg/1]).

start_link() ->
	gen_server:start_link({local,?MODULE},?MODULE,[],[]).

send_msg(Msg) ->
	gen_server:call(?MODULE,{send_msg,Msg}).

cast_msg(Msg) ->
	gen_server:cast(?MODULE,{send_msg,Msg}).

handle_call({send_msg,Msg},_From,State) ->
	io_log(State),
	{Channel,Connection}=lists:nth(random:uniform(?POOL_NUM),State),
	mq_send(Channel,Msg),
	%{reply,data,[Rest|{Channel,Connection}]}.
	{reply,data,State}.

mq_send(Channel,Msg) ->
	amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = ?QUEUE},
                      #amqp_msg{payload = Msg}),
	ok.
init([]) ->
	io_log("init pool"),
	State=init_pool(?POOL_NUM,?QUEUE),
	{ok,State}.

init_pool(Poolnum,Queue) ->
	case Poolnum of
		0 ->
			[];
		_ ->
			{ok, Connection} =amqp_connection:start(#amqp_params_network{host = "localhost"}),
			{ok, Channel} = amqp_connection:open_channel(Connection),
			amqp_channel:call(Channel, #'queue.declare'{queue =Queue}),
			[{Channel,Connection}|init_pool(Poolnum-1,Queue)]
	end.

handle_cast({send_msg,Msg}, State) -> 
	{Channel,Connection}=lists:nth(random:uniform(?POOL_NUM),State),
	mq_send(Channel,Msg),
	{noreply,State}.

code_change(_,_,_) ->
	ok.

handle_info(_,_) ->
	ok.

terminate(_,State) ->
	io_log("release pool"),
	release_res(State).

release_res(State) ->
	[{Channel,Connection}|End]=State,
	ok = amqp_channel:close(Channel),
	ok = amqp_connection:close(Connection),
	case End of
		[] ->
			ok;
		_ ->
			release_res(End)
	end.

io_log(Info) ->
		io:format("~n ***************  ~p *****************  ~n",[Info]).