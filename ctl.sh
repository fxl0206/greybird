#!/bin/sh
SOCK=/tmp/mysql.sock
SERVER_NAME=greybird
status(){
   echo "==========status======="
}
start() {
	domake
	echo "================ start ${SERVER_NAME} ===========";
	./_rel/grey_bird/bin/grey_bird start	
	echo "==========${SERVER_NAME} start success===========";
}
domake(){
echo "==========make ${SERVER_NAME}===========";
make
echo "==========   make finish     ===========";

}
stop() {
    	./_rel/grey_bird/bin/grey_bird stop
	echo "===========${SERVER_NAME} stop success !============";
}

debug(){
	make
	./_rel/grey_bird/bin/grey_bird console
	}
restart() {
    stop;
    echo "sleeping.........";
    sleep 3;
    start;
}
case "$1" in
    'start')
        start
        ;;
    'stop')
        stop
        ;;
    'status')
        status
        ;;
	'debug')
        debug
        ;;
    'restart')
        restart
        ;;
    *)
    echo "usage: $0 {start|stop|restart|status|link}"
    exit 1
        ;;
    esac
