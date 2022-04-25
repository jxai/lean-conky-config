#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

usage() {
    echo "USAGE: $(basename $0) [-n] [-p CONKY_PATH]"
}

conky_bin="conky"
pause_flag="--pause=3"
magic_id="0ce31833f8f0bae3" # truncated md5sum of 'lean-conky-config'

while getopts "np:h" opt; do
    case $opt in
    n) # no-waiting
        pause_flag=""
        ;;
    p) # path to conky binary
        conky_bin=$(realpath -- "$OPTARG")
        if [ -x "$conky_bin" ]; then
            echo "Conky binary path: ${conky_bin}"
        else
            echo "ERROR: ${conky_bin} is not executable, path to Conky binary needed\n" >&2
            usage
            exit 1
        fi
        ;;
    h) # help
        usage
        exit
        ;;
    \?)
        echo "ERROR: Invalid option: -$OPTARG\n" >&2
        usage
        exit 2
        ;;
    esac
done
shift "$((OPTIND - 1))"

cd $(dirname $0)
pkill -f "conky.*\s-- $magic_id"
font/install

[ -z "$pause_flag" ] && echo "Starting Conky..." || echo "Conky waiting 3 seconds to start..."
if "$conky_bin" --daemonize --quiet "$pause_flag" --config=./conky.conf -- $magic_id; then
    echo "Started"
else
    echo "Failed"
fi
