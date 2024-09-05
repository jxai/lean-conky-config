#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

opt="$1"
window="conky-lcc"
out_file="lcc.$(date +%y%m%d-%H%M%S).png"

snap_lcc() {
    if [ "$opt" = "-c" ]; then
        # conky window only (black background)
        import -window ${window} ${out_file}
    else
        # desktop background blended with conky
        region=$(xwininfo -name "$window" -shape | perl -0pe "s/^.*corners\:\s+([^\s]+).*geometry\s+(\d+x\d+).*$/\2\1/si")
        import -window root -crop ${region} ${out_file}
    fi

}

xdotool search --name ${window} >/dev/null &&
    snap_lcc &&
    echo "snapped to: ${out_file}" &&
    feh ${out_file}
