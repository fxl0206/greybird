
-module(utils).
-export([get_value/3,send_mq_msg/1,df_str_to_int/1,def_to_hex_string/1]).

-include_lib("amqp_client/include/amqp_client.hrl").


%% Faster alternative to proplists:get_value/3.
get_value(Key, Opts, Default) ->
    case lists:keyfind(Key, 1, Opts) of
        {_, Value} -> Value;
        _ -> Default
    end.

%发送消息到RabbitMQ
send_mq_msg(Msg) ->
    {ok, Connection} =amqp_connection:start(#amqp_params_network{host = "localhost"}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'queue.declare'{queue = <<"hello">>}),
    amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = <<"">>,
                        routing_key = <<"hello">>},
                      #amqp_msg{payload = Msg}),
    io:format(" [x] Send ~ts",[Msg]),
    ok = amqp_channel:close(Channel),
    ok = amqp_connection:close(Connection),
    ok.

%get msg_length from 
df_str_to_int(Len) ->
    lists:dropwhile(fun(E) -> 0==E end,Len).

def_to_hex_string(Bl) ->
    lists:foldl(fun(X, Sum) ->
        if 
            X>16 ->
                Sum++integer_to_list(X,16);
            X<17 ->
                Sum++"0"++integer_to_list(X band 16#FF,16)
        end end, [], binary_to_list(Bl)).