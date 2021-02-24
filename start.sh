#!/bin/sh

sleep 5s
cd $(dirname $0)
killall conky 2>/dev/null
conky -d -q
