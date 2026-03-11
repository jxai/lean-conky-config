#!/usr/bin/fontforge -lang=py
# vim: ft=python:ts=4:sw=4:et:ai:cin

# Build LeanConkyConfig font - requiring FontForge to run

import argparse
import logging
import sys
import os.path as osp
import tempfile
from glob import glob
from datetime import date
import fontforge as ff
import psMat

tmp_dir = tempfile.gettempdir()

# Font Awesome settings
FA_URL = (
    "https://github.com/FortAwesome/Font-Awesome/releases/download/"
    + "7.2.0/fontawesome-free-7.2.0-desktop.zip"
)
FA_DIR = osp.join(tmp_dir, "lcc_fontawesome")
FA_SUBSET = """
f007    #user
f013    #cog
f015    #home
f017    #clock
f019    #download
f01c    #inbox
f073    #calendar
f085    #cogs
f093    #upload
f0a0    #hdd
f0ac    #globe
f0e8    #sitemap
f108    #desktop
f1c0    #database
f1eb    #wifi
f233    #server
f293    #bluetooth
f2db    #microchip
f2dc    #snowflake
f2f5    #sign-out-alt
f2f6    #sign-in-alt
f381    #cloud-download-alt
f382    #cloud-upload-alt
f3c5    #map-marker-alt
f538    #memory
f56e    #file-export
f56f    #file-import
f6ff    #network-wired
f7c2    #sd-card
"""

# Bootstrap font settings
FB_URL = "https://github.com/twbs/icons/raw/v1.13.1/font/fonts/bootstrap-icons.woff"
FB_FILE = osp.join(tmp_dir, "bootstrap-icons.woff")
FB_SUBSET = """
f6e2    #gpu-card
# weather: clouds
f29c    #cloud-drizzle-fill
f29d    #cloud-drizzle
f29e    #cloud-fill
f29f    #cloud-fog-fill
f2a0    #cloud-fog
f2a1    #cloud-fog2-fill
f2a2    #cloud-fog2
f2a3    #cloud-hail-fill
f2a4    #cloud-hail
f2a6    #cloud-haze-fill
f2a7    #cloud-haze
f2a8    #cloud-haze2-fill
f2a9    #cloud-lightning-fill
f2aa    #cloud-lightning-rain-fill
f2ab    #cloud-lightning-rain
f2ac    #cloud-lightning
f2af    #cloud-moon-fill
f2b0    #cloud-moon
f2b3    #cloud-rain-fill
f2b4    #cloud-rain-heavy-fill
f2b5    #cloud-rain-heavy
f2b6    #cloud-rain
f2b9    #cloud-sleet-fill
f2ba    #cloud-sleet
f2bb    #cloud-snow-fill
f2bc    #cloud-snow
f2bd    #cloud-sun-fill
f2be    #cloud-sun
f2c1    #cloud
f2c2    #clouds-fill
f2c3    #clouds
f2c4    #cloudy-fill
f2c5    #cloudy
# weather: droplets
f30b    #droplet-fill
f30c    #droplet-half
f30d    #droplet
# weather: storms
f427    #hurricane
# weather: lightning
f46c    #lightning-charge-fill
f46d    #lightning-charge
f46e    #lightning-fill
f46f    #lightning
# weather: moon/night
f494    #moon-fill
f495    #moon-stars-fill
f496    #moon-stars
f497    #moon
# weather: phenomena
f50d    #rainbow
# weather: snow
f56d    #snow
#f56e    #snow2 - collide with FA file-export
#f56f    #snow3 - collide with FA file-import
# weather: sun
f5a1    #sun-fill
f5a2    #sun
f5a4    #sunrise-fill
f5a5    #sunrise
f5a6    #sunset-fill
f5a7    #sunset
# weather: temperature
f5cd    #thermometer-half
f5ce    #thermometer-high
f5cf    #thermometer-low
f5d0    #thermometer-snow
f5d1    #thermometer-sun
f5d2    #thermometer
# weather: extreme
f5dc    #tornado
f5e8    #tropical-storm
f5eb    #tsunami
# weather: rain accessories
f5fc    #umbrella-fill
f5fd    #umbrella
f617    #water
# weather: wind
f61d    #wind
# weather: thunder
f6ef    #thunderbolt-fill
f6f0    #thunderbolt
f6f7    #cloud-haze2
"""

# parse command line
parser = argparse.ArgumentParser(description="Build LeanConkyConfig font file.")
parser.add_argument(
    "-verbose", help="output debug information", action="count", default=0
)
parser.add_argument("-lcd-font", help="lcd font file", default="TRS-Million-mod.otf")
parser.add_argument("-output", help="output file", default="lean-conky-config.otf")
parser.add_argument("-view", "-v", help="open built font in FontForge", action="store_true")
parser.add_argument("-dry-run", "-n", help="skip generation, log what would be done", action="store_true")
args = parser.parse_args()

# logger
logging.basicConfig(
    level=logging.DEBUG if args.verbose else logging.INFO,
    style="{",
    format="{asctime} {message}",
    stream=sys.stdout,
)
logging.info("Building custom font")


def parse_subset(subset):
    parsed = []
    for l in subset.split("\n"):
        x = l.split("#", maxsplit=1)[0].strip()
        if x:
            parsed.append(int(x, base=16))
    return parsed


def copy_attrs(src, dst, attrs):
    for a in attrs:
        v = getattr(src, a)
        logging.debug("%s: %s => %s", a, getattr(dst, a), v)
        setattr(dst, a, v)


def merge_font(dst_font, src_font, selection=None):
    if selection:
        src_font.selection.select(*selection)
        dst_font.selection.select(*selection)
    else:
        src_font.selection.all()
        dst_font.selection.all()
    src_font.copy()
    dst_font.paste()


def copy_glyphnames(dst_font, src_font, unicodes):
    logging.debug(
        "Copy glyphnames: {} -> {}".format(src_font.fontname, dst_font.fontname)
    )
    logging.debug("---------------------")
    common_codes = [k for k in unicodes if k in src_font and k in dst_font]
    for k in common_codes:
        src_name = src_font[k].glyphname
        logging.debug("{} -> {}".format(src_name, dst_font[k].glyphname))
        dst_font[k].glyphname = src_name
    logging.debug("---------------------")


# fetch FA if needed
if osp.isdir(FA_DIR):
    logging.debug("FA font cache found: {}".format(FA_DIR))
else:
    fa_download = FA_DIR + ".zip"
    if osp.isfile(fa_download):
        logging.debug("FA font already downloaded: {}".format(fa_download))
    else:
        import urllib.request

        urllib.request.urlretrieve(FA_URL, fa_download)
        logging.info("Downloaded FA font: {}".format(fa_download))

    import zipfile

    with zipfile.ZipFile(fa_download, "r") as z:
        z.extractall(FA_DIR, [f for f in z.namelist() if f.endswith(".otf")])
        logging.debug("Extracted .otf files from FA")

# subset and merge fonts
# FA solid
fa = glob(osp.join(FA_DIR, "**/*Solid*"), recursive=True)
if fa:
    fa = ff.open(fa[0])
else:
    raise FileNotFoundError("FA-Solid font not found")

nf = ff.font()
nf.fontname = nf.familyname = nf.fullname = "LeanConkyConfig"
nf.version = date.today().strftime("%Y%m%d")
with open("./LICENSE", "r") as f:
    nf.copyright = f.read().strip()

logging.info("Copy essential FA font attributes")
copy_attrs(fa, nf, ["encoding", "em", "ascent", "descent"])

fa_subset = parse_subset(FA_SUBSET)
sel = [("unicode", "singletons")] + fa_subset
logging.info("Subset and merge FA-Solid font")
merge_font(nf, fa, sel)
copy_glyphnames(nf, fa, fa_subset)

# FA brands
fa = glob(osp.join(FA_DIR, "**/*Brands*"), recursive=True)
if fa:
    logging.info("Subset and merge FA-Brands font")
    fa = ff.open(fa[0])
    merge_font(nf, fa, sel)
    copy_glyphnames(nf, fa, fa_subset)
else:
    raise FileNotFoundError("FA-Brands font not found")


# Bootstrap font
if osp.isfile(FB_FILE):
    logging.debug("Bootstrap font already downloaded: {}".format(FB_FILE))
else:
    import urllib.request

    urllib.request.urlretrieve(FB_URL, FB_FILE)
    logging.info("Downloaded Bootstrap font: {}".format(FB_FILE))
fb = ff.open(FB_FILE)
fb.selection.all()
fb.transform(psMat.compose(psMat.scale(1.18 * nf.em / fb.em), psMat.translate(0, -100)))
fb_subset = parse_subset(FB_SUBSET)
sel = [("unicode", "singletons")] + fb_subset
logging.info("Subset and merge Bootstrap font")
merge_font(nf, fb, sel)
copy_glyphnames(nf, fb, fb_subset)

# LCD font (modified TRS Million by default)
logging.info("Subset and merge LCD font file: {}".format(args.lcd_font))
cf = ff.open(args.lcd_font)
cf.selection.all()
cf.transform(psMat.scale(float(nf.em) / cf.em))
merge_font(nf, cf, [" "])
merge_font(nf, cf, [("more", "ranges"), ".", ":"])  # 0-9 included
merge_font(nf, cf, [("more", "ranges"), "A", "Z"])
merge_font(nf, cf, [("more", "ranges"), "a", "z"])

# adjust specific icon
nf.selection.select(0xF2DB)  # cpu (microchip)
nf.transform(psMat.compose(psMat.scale(1.15), psMat.translate(-20, 0)))

# save the final work
if args.dry_run:
    logging.warning("\033[33m[DRY RUN] skipping generation of {}".format(args.output))
else:
    nf.generate(args.output)
    if osp.isfile(args.output) and osp.getsize(args.output):
        logging.info("Generated font file: {}".format(args.output))
    else:
        raise RuntimeError("Font generation failed: {} missing or empty".format(args.output))

if args.view:
    if osp.isfile(args.output) and osp.getsize(args.output):
        # compact view by default, easier to check all glyphs
        ff.setPrefs("CompactOnOpen", 1)
        ff.savePrefs()

        import subprocess
        subprocess.Popen(["fontforge", "-nosplash", args.output])
    else:
        raise RuntimeError("Cannot open font: {} missing or empty".format(args.output))