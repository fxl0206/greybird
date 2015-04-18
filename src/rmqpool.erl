-module(rmqpool).
-behaviour(gen_server).
-include_lib("amqp_client/include/amqp_client.hrl").
-export([start/0,start_link/0,init/1,handle_call/3,handle_cast/2,code_change/3,handle_info/2,terminate/2]).
-export([send_msg/1]).
start_link() ->   
 gen_server:start_link({local, rmqpool}, rmqpool, [], []).
send_msg(Msg) ->  
  io:format(" #############################################[x] Sent 'Hello World!'~n"),
	gen_server:call(rmqpool, Msg).
send(Msg) ->   
 gen_server:cast(rmqpool, Msg).
init(_Args) ->   
register(ch1,spawn(rmqpool,start,[])), 
{ok, ok}.
handle_call(Msg, _From, State) -> 
   ch1!Msg,
   {reply,ok,State}.   
handle_cast({msg,_}, Chs) -> 
  conn!msg,
  {noreply,ok}.
code_change(_,_,_) ->
ok.
handle_info(_,_) ->
ok.
terminate(_,_) ->
ok.
start() ->
	{ok, Connection} =amqp_connection:start(#amqp_params_network{host = "localhost"}),
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'queue.declare'{queue = <<"hello">>}),
	loop2(Channel),
	ok = amqp_channel:close(Channel),
	ok = amqp_connection:close(Connection),
	ok.
loop2(Channel) -> 
     receive 
	{msg,Msg} -> 
		amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = <<"hello">>},
                      #amqp_msg{payload = <<"Hello World!">>}),
        	  io:format(" [x] Sent 'Hello World!'~n"),
                  io:format("Receive abc. ~n "),
                  loop2(Channel)
	end.
