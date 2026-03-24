#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

window="conky-lcc"
out_file="lcc.$(date +%y%m%d-%H%M%S).png"
conky_only=false
height=""
verbose=false

log() {
    [ "$verbose" = true ] && echo "$@"
}

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo
    echo "Capture a screenshot of the conky-lcc window."
    echo
    echo "Options:"
    echo "  -c            Capture conky-lcc window only (black background)"
    echo "  -H, --height  Height of the captured region"
    echo "  -v, --verbose Show intermediate status"
    echo "  -h, --help    Show this help message and exit"
}

while [ $# -gt 0 ]; do
    case "$1" in
        -c)
            conky_only=true
            shift
            ;;
        -H|--height)
            height="$2"
            shift 2
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

snap_lcc() {
    region=$(xwininfo -name "$window" -shape | perl -0pe "s/^.*corners\:\s+([^\s]+).*geometry\s+(\d+x\d+).*$/\2\1/si")
    log "region: ${region}"
    if [ -n "$height" ]; then
        region=$(echo "$region" | perl -pe "s/^(\d+)x\d+/\${1}x${height}/")
        log "region (height adjusted): ${region}"
    fi

    if [ "$conky_only" = true ]; then
        # conky window only (black background)
        crop=$(echo "$region" | perl -pe "s/\+.*$/+0+0/")
        log "crop: ${crop}"
        import -window ${window} -crop ${crop} ${out_file}
    else
        # desktop background blended with conky
        import -window root -crop ${region} ${out_file}
    fi
}

xdotool search --name ${window} >/dev/null &&
    snap_lcc &&
    echo "snapped to: ${out_file}" &&
    feh ${out_file}
