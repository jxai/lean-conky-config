#!/bin/sh

cd $(dirname $0)
killall conky 2>/dev/null
conky -d -q -p 5
