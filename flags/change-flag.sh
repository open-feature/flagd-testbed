#!/bin/sh

# this simple script toggles a flag value for a easy way of testing events
cat ./changing-flag-foo.json > ./changing-flag.json

while true
do
    sleep 1
    cat ./changing-flag-foo.json > ./changing-flag.json
    echo 'updated flag changing-flag value to "foo"'

    sleep 1
    cat ./changing-flag-bar.json > ./changing-flag.json
    echo 'updated flag changing-flag value to "bar"'
done