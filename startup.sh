#!/bin/sh

sleep 5s
killall conky 2>/dev/null
conky -d -q
