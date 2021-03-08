# Lean Conky Config

A lean [Conky](https://github.com/brndnmtthws/conky/wiki) config that just works.

One notable feature is automatic discovery of system devices such as network interfaces and mounted disks. Unlike many others this config works out-of-box, saving the trouble of manually specifying those devices. Also it keeps information up-to-date, for example when toggling WiFi the NETWORK section is dynamically updated. Similarly when you plug or unplug USB drives, DISK USAGE will reflect the change.

## Installation
First you need Conky installed. On Ubuntu, simply:
``` bash
sudo apt install conky-all
```
For other operating systems, refer to [Conky documentation](https://github.com/brndnmtthws/conky/wiki/Installation).

To install this config, just put it in any directory you like. If you don't have `~/.config/conky` yet, you may simply (use it as the default Conky config):
``` bash
git clone https://github.com/jxai/lean-conky-config.git ~/.config/conky
```

Now run
``` bash
/path/to/lean-conky-config/start.sh
```
to start Conky. In a moment you should see the panel showing up, docked to the right side your desktop. If you have multiple monitors, the panel should appear on one of them.

In order to autostart Conky, follow [this tutorial](https://linuxconfig.org/ubuntu-20-04-system-monitoring-with-conky-widgets#h2-enable-conky-to-start-at-boot) if you use Ubuntu, just replacing Command with the full path to the `start.sh` script. For other desktop environments, check the information [here](https://wiki.archlinux.org/index.php/Autostarting#On_desktop_environment_startup).

## More Information
To further customize the config for your specific needs, create a `local.conf` file:
``` bash
cp local.conf.example local.conf
```
and make changes there, this way your customizations wouldn't get lost accidentally when updating to a newer version.

For reference of Conky setting variables, check its [documentation](http://conky.sourceforge.net/config_settings.html), or `man` page:
``` bash
man -P "less -p 'CONFIGURATION SETTINGS'" conky 
```
