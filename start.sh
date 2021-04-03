#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

cd $(dirname $0)
killall conky 2>/dev/null
font/install
if [ "$1" = "-n" ]; then
    pause_flag=""
else
    pause_flag="--pause=5"
    echo "Conky waiting 5 seconds to start..."
fi
if conky --daemonize --quiet "$pause_flag" --config=./conky.conf ; then
    echo "Started"
else
    echo "Failed"
fi
