#!/bin/sh
# wrapper script to start change-flag.sh and flagd, and forward signals to the child process

# handle SIGINTs and SIGTERMs so we can kill the container
handle_term() { 
  kill -TERM "$child" 2>/dev/null
}

handle_int() { 
  kill -INT "$child" 2>/dev/null
}

trap handle_term SIGTERM
trap handle_int SIGINT

# start change script and flagd
sh ./change-flag.sh &
"$@" &

# wait on flagd
child=$! 
wait "$child"