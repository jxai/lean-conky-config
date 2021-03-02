#!/bin/sh

cd $(dirname $0)
killall conky 2>/dev/null
conky --daemonize --quiet --pause=5 --config=./conky.conf
