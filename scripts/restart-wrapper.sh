#!/bin/sh
# wrapper script to start flagd/sync, and restart it every 5 seconds (to test reconnec functionality)

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

while [ "$killed" -eq 0 ]; # stop looping if we were interupted
do
    # start change script and our server
    echo 'starting process...' 
    "$@" &
    child=$!
    sleep 5
    echo "killing pid $child..." && sleep 5 && kill -9 "$child"
done