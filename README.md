# Lean Conky Config (v0.6.2)

Lean Conky Config (LCC) is, well, a lean [Conky](https://github.com/brndnmtthws/conky/wiki) config that just works.

![Screenshot](./screenshot.jpg?raw=true 'Screenshot')

As shown in the screenshot above, LCC offers an essential collection of system information, cleanly organized into several sections. The layout is fairly self-explanatory.

One notable feature is **automatic discovery of devices** such as network interfaces and mounted disks. Unlike many other Conky configs, LCC works out of the box, saving the trouble of manually configuring those devices. Also it keeps information up-to-date, e.g. when toggling WiFi the NETWORK section is dynamically updated, and when you plug/unplug USB drives DISK USAGE will reflect the change instantly.

## Installation

If you haven't, install Conky first. On Ubuntu/Debian:

```bash
sudo apt install conky
```

For other operating systems, refer to [Conky documentation](https://github.com/brndnmtthws/conky/wiki/Installation).

To install LCC, just download the [ZIP](https://github.com/jxai/lean-conky-config/archive/master.zip) and decompress it into any directory you like. Alternatively, clone the repository:

```bash
git clone https://github.com/jxai/lean-conky-config [/path/to/lean-conky-config]
```

If `~/.config/conky` doesn't exist yet, you may simply use that path which is for the default Conky config.

Now run

```bash
/path/to/lean-conky-config/start.sh
```

to start Conky. In a moment you should see the panel showing up, docked to the right side your desktop. If you have multiple monitors, the panel should appear on one of them.

In order to autostart Conky on Ubuntu, follow [this tutorial](https://linuxconfig.org/ubuntu-20-04-system-monitoring-with-conky-widgets#h2-enable-conky-to-start-at-boot), replacing Command with the full path to the `start.sh` script we just ran. For other desktop environments, check the information [here](https://wiki.archlinux.org/index.php/Autostarting#On_desktop_environment_startup).

You might notice the icons and LCD-style time in the screenshot above. LCC renders them with a custom font named `LeanConkyConfig`, which is automatically installed in your local font directory (`~/.local/share/fonts`) when LCC starts. If you don't see the font in effect, likely your desktop environment doesn't load it properly. In this case you can manually install the font, located at `font/lean-conky-config.otf`. This is optional though. LCC is designed to just work, it would fall back gracefully instead of breaking the layout, even if the font is not loaded by the system.

In case you prefer the plain font and simple layout, here's a workaround:

```bash
/path/to/lean-conky-config/font/install -u && \
touch ~/.local/share/fonts/lean-conky-config.otf
```

And to undo it:

```bash
/path/to/lean-conky-config/font/install -f
```

## Customization

While LCC is made to work out of the box, it is also designed to serve your needs for customization. To get started, create your local configuration file `local.conf`:

```bash
cp local.conf.example local.conf
```

and make changes there (instead of directly in `conky.conf`), this way your custom settings wouldn't get lost when LCC itself is updated.

### Scale to fit your screen

In a plain Conky config, layout parameters (`voffset` and `goto` values, font sizes etc.) are hard-coded, making it difficult to adapt to different screen resolutions. When you try a new config from the web, you might find it to appear too large or too small on your desktop, and have to manually adjust many parameters, rather tedious work.

LCC addresses this issue gracefully. To globally scale the panel while **preserving the layout**, simply change the `lcc.config.scale` variable in your `local.conf`, a value larger than 1 magnifies the LCC panel to fit a monitor of higher resolution.

Under the hood, LCC achieves this by offering several transform functions (defined in `tform.lua`), which you can apply to numerical values that need to be changed on-the-fly:

- `T_sc`: scale to a precise floating-point number, suitable for scaling a font size
- `T_sr`: scale then round to the nearest integer, suitable for use cases where an integer value is required

For values embedded in a string, wrap them with `$sc{}`/`$sr{}` and tranform the whole string with function `T_`, e.g.:

```lua
font = T_ "sans-serif:normal:size=$sc{8}"
```

### Pick your favorite colors and fonts

Colors can be customized through standard Conky settings.

To make it easy to customize fonts, LCC implements a **named fonts** mechanism. Fonts for different elements are defined in the `conky.fonts` variable (not supported by Conky per se).

Check `local.conf.example` to see how colors and fonts can be customized. For full reference, dig `conky.conf`.

## More Information

Check official Conky documentation:

- [Configuration Settings](http://conky.sourceforge.net/config_settings.html)
- [Objects/Variables](http://conky.sourceforge.net/variables.html)

And here is a great [third-party reference](http://www.ifxgroup.net/conky.htm) with examples.

Finally, the `man` page might provide more up-to-date information for the Conky version installed on your system:

```bash
man -P "less -p 'CONFIGURATION SETTINGS'" conky
man -P "less -p 'OBJECTS/VARIABLES'" conky
```
