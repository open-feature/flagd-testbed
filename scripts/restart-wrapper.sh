#!/bin/sh
# wrapper script to start flagd/sync, and restart it every 5 seconds (to test reconnect functionality)

killed=0

# handle SIGINTs and SIGTERMs so we can kill the container
handle_term() { 
  kill -TERM "$child" 2>/dev/null
  killed=1
}

handle_int() { 
  kill -INT "$child" 2>/dev/null
  killed=1
}

trap handle_term SIGTERM
trap handle_int SIGINT

while [ "$killed" -eq 0 ]; # stop looping if we were interrupted
do
    # start change script and our server
    echo 'starting process...' 
    "$@" &
    child=$!
    sleep 5
    echo "killing pid $child..." && sleep 5 && kill -9 "$child"
    while kill -0 "$child" 2> /dev/null; do # wait for child to exit (kill -0 is falsy if pid is gone)
        sleep 1
    done
done