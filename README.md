# Lean Conky Config (v0.5.1)

Lean Conky Config (LCC) is, well, a lean [Conky](https://github.com/brndnmtthws/conky/wiki) config that just works.

![Screenshot](./screenshot.jpg?raw=true "Screenshot")

As shown in the screenshot above, LCC offers an essential collection of system information, cleanly organized into several sections. The layout is fairly self-explanatory.

One notable feature is **automatic discovery of devices** such as network interfaces and mounted disks. Unlike many other Conky configs, LCC works out-of-box, saving the trouble of manually configuring those devices. Also it keeps information up-to-date, e.g. when toggling WiFi the NETWORK section is dynamically updated, and when you plug/unplug USB drives DISK USAGE will reflect the change instantly.

## Installation
If you haven't, install Conky first. On Ubuntu/Debian:
``` bash
sudo apt install conky
```
For other operating systems, refer to [Conky documentation](https://github.com/brndnmtthws/conky/wiki/Installation).

To install LCC, just download the [ZIP](https://github.com/jxai/lean-conky-config/archive/master.zip) and decompress it into any directory you like. Alternatively, clone the repository:
``` bash
git clone https://github.com/jxai/lean-conky-config [/path/to/lean-conky-config]
```

If `~/.config/conky` doesn't exist yet, you may simply use that path which is for the default Conky config.

Now run
``` bash
/path/to/lean-conky-config/start.sh
```
to start Conky. In a moment you should see the panel showing up, docked to the right side your desktop. If you have multiple monitors, the panel should appear on one of them.

You might not see the icons as shown in the screenshot above, which require [Font Awesome](https://fontawesome.com/). On Ubuntu the font can be installed via package `fonts-font-awesome`. It is optional though. LCC is designed to just work, it would fall back gracefully if the font is not found, instead of breaking the layout.

In order to autostart Conky on Ubuntu, follow [this tutorial](https://linuxconfig.org/ubuntu-20-04-system-monitoring-with-conky-widgets#h2-enable-conky-to-start-at-boot), replacing Command with the full path to the `start.sh` script we just ran. For other desktop environments, check the information [here](https://wiki.archlinux.org/index.php/Autostarting#On_desktop_environment_startup).

## Customization
To further customize the config for your specific needs, create a `local.conf` file:
``` bash
cp local.conf.example local.conf
```
and make changes there, this way your custom settings wouldn't get lost when LCC itself is updated.

Colors can be customized through standard Conky settings.

To make it easy to customize fonts, LCC implements a **named fonts** technique. The fonts for different elements are defined in the `conky.fonts` variable (not supported by Conky per se).

Check `local.conf.example` to see how colors and fonts can be customized. For full reference, dig `conky.conf`.

## More Information
For reference of Conky setting variables, check its [documentation](http://conky.sourceforge.net/config_settings.html), or `man` page:
``` bash
man -P "less -p 'CONFIGURATION SETTINGS'" conky 
```
