#!/bin/sh
# vim: ft=sh:ts=4:sw=4:et:ai:cin

window="conky-lcc"
out_file="lcc.$(date +%y%m%d-%H%M%S).png"
conky_only=false
height=""
top=0
out_dir=""
preview=false
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
    echo "  -t, --top     Offset from the top of the conky window"
    echo "  -o, --output  Output directory for the screenshot"
    echo "  -p, --preview Preview the screenshot with feh"
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
        -t|--top)
            top="$2"
            shift 2
            ;;
        -o|--output)
            out_dir="$2"
            shift 2
            ;;
        -p|--preview)
            preview=true
            shift
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

if [ -n "$out_dir" ]; then
    if [ ! -d "$out_dir" ]; then
        echo "Error: output directory does not exist: ${out_dir}" >&2
        exit 1
    fi
    out_file="${out_dir%/}/${out_file}"
fi

snap_lcc() {
    # parse window region: WxH+X+Y
    region=$(xwininfo -name "$window" -shape | perl -0pe "s/^.*corners\:\s+([^\s]+).*geometry\s+(\d+x\d+).*$/\2\1/si")
    log "region: ${region}"
    set -- $(echo "$region" | perl -pe "s/[x+]/ /g")
    w=$1 h=$2 x=$3 y=$4

    # find monitor containing the window
    mon=$(xrandr --query | perl -ne \
        "if (/\bconnected\b.*?(\d+)x(\d+)\+(\d+)\+(\d+)/) {
            print \"\$2 \$4\" and exit if $x >= \$3 && $x < \$3 + \$1;
        }")
    if [ -n "$mon" ]; then
        mon_h=${mon% *} mon_y=${mon#* }
    else
        mon_h=$(xdpyinfo | perl -0ne "print \$1 if /dimensions:\s+\d+x(\d+)/")
        mon_y=0
    fi

    # clamp to visible monitor area, then apply top offset
    eff_y=$(( y > mon_y ? y : mon_y ))
    h=$(( h - (eff_y - y) ))
    eff_y=$(( eff_y + top ))
    h=$(( h - top ))
    max_h=$(( mon_y + mon_h - eff_y ))
    [ "$h" -gt "$max_h" ] && h=$max_h
    log "monitor: ${mon_h}px at y=${mon_y}, eff_y: ${eff_y}, max height: ${max_h}"

    # apply -H height override
    if [ -n "$height" ]; then
        [ "$height" -gt "$max_h" ] && log "clamping height ${height} to ${max_h}" && height=$max_h
        h=$height
    fi
    log "capture: ${w}x${h}"

    if [ "$conky_only" = true ]; then
        import -window ${window} -crop ${w}x${h}+0+${top} ${out_file}
    else
        import -window root -crop ${w}x${h}+${x}+${eff_y} ${out_file}
    fi
}

xdotool search --name ${window} >/dev/null &&
    snap_lcc &&
    echo "snapped to: ${out_file}" &&
    { [ "$preview" = true ] && feh ${out_file}; true; }
