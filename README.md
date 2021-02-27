# Conky Configuration

A lean and practical [Conky](https://github.com/brndnmtthws/conky/wiki) configuration. It is based on [this tutorial](https://linuxconfig.org/ubuntu-20-04-system-monitoring-with-conky-widgets), with a bunch of tweaks to better suite my monitoring needs.

## Installation
First you need Conky installed. On Ubuntu, simply:
``` bash
sudo apt install conky conky-all
```
For other operating systems, refer to [Conky documentation](https://github.com/brndnmtthws/conky/wiki/Installation).

To install this configuration:
``` bash
cd ~/.config
git clone https://github.com/jxai/conky-config.git conky
```

Now run
``` bash
~/.config/conky/startup.sh
```
You should see the Conky panel docked to the right side your desktop. If you have multiple monitors, the panel should appear on one of them.

In order to automatically start Conky on boot, follow [this](https://linuxconfig.org/ubuntu-20-04-system-monitoring-with-conky-widgets#h2-enable-conky-to-start-at-boot) but replace the Command with `/home/<USER>/.config/conky/start.sh`, where `<USER>` is your user name.

## More Information
One notable feature of this config is that it automatically discovers system devices such as network interfaces and mounted disks. Unlike many other configs it works out-of-box, saving the trouble of manually specifying those devices. Also it keeps information up-to-date, for example when toggling WiFi the NETWORK section is dynamically updated. Similarly when you plug or unplug USB drives, DISK USAGE will reflect the change.

To further customize the config, check Conky reference documentation:
* [Settings](http://conky.sourceforge.net/config_settings.html)
* [Variables](http://conky.sourceforge.net/variables.html)

You can also find up-to-date info in its man page:
``` bash
man -P "less -p 'CONFIGURATION SETTINGS'" conky 
man -P "less -p 'OBJECTS/VARIABLES'" conky
```
