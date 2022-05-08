#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

window="conky-lcc"
out_file="lcc.$(date +%H%M%S).png"
xdotool search --name ${window} >/dev/null &&
    import -window ${window} ${out_file} &&
    echo "snapped to: ${out_file}" &&
    feh ${out_file}
