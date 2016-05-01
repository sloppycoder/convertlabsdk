#!/bin/bash

set -o errexit
umask 0027

export CLAB_LOGGER=STDOUT

if [ "$1" = "single" ]; then

    /usr/local/bin/ruby syncer.rb

elif [ "$1" = "resque" ]; then

    rake db:migrate
    sleep 5 # wait for redis
    rake resque:web &
    rake resque:scheduler &
    rake resque:pool &

    while :; do sleep 10; done

fi

exec "$@"



