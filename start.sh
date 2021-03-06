#!/bin/sh

cd $(dirname $0)
killall conky 2>/dev/null
echo "Conky waiting 5 seconds to start..."
if conky --daemonize --quiet --pause=5 --config=./conky.conf ; then
  echo "Started"
else
  echo "Failed"
fi
