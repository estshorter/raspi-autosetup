# Assumption
- Raspberry Pi 3 only (due to optimization option)
- OS: Raspbian stretch (2017-11-29)
- Music format: mp3, m4a, flac (no dsd)
- Play music stored in a NAS via wired lan (no usb)
- Scrobble to last.fm
- I2S DAC: Hifiberry DAC+ Pro compatible board
- For Japanese (NTP, timezone and language setting)
- Network: dhcp, wired lan
- Write the raspbian image on Windows

# Download image
Mirror on Japan
- http://ftp.jaist.ac.jp/pub/raspberrypi/raspbian_lite/images/
- https://www.raspbian.org/RaspbianMirrors

# Write image
Use [etcher](https://etcher.io/)

# Enable ssh
**Create a file named `ssh` on the root folder**
- user: pi
- pass: raspberry

# Minimum raspbian setting for Music
## Setting overview
The following are configured automatically.
- **Build the latest alsa-lib, libflac, mpg123, FFmpeg and MPD with optimization options for Raspberry Pi 3**
- **Specify high priority to MPD tasks**
- Turn off the power led after initialization
- Provide cover art via http using nginx
- Scrobble to last.fm using mpdas
- Disable swap, HDMI, Wi-Fi, Bluetooth, UART, onboard audio, usb-power and unnecessary service
- Put temp and log files to RAM disk
- Decrease GPU assigned memory
- Suppress rsyslog and nginx output
- Specify NTP server, timezone and language for Japanese
- Configure NAS

## Setting script
Download files:
```bash
mkdir ~/setup
cd ~/setup
wget https://raw.githubusercontent.com/estshorter/raspi-autosetup/master/setup.sh -O ./setup.sh
chmod u+x ./setup.sh
```

Execute all scripts:

Note: specify `NAS_USER, NAS_PASS, NAS_ADDR, LAST_FM_USER, LAST_FM_PASS` before third executing.
```bash
cd ~/setup
./setup.sh
sudo reboot

cd ~/setup
./setup.sh
sudo reboot

export NAS_USER=user
export NAS_PASS='pass'
export NAS_ADDR=addr
export LAST_FM_USER=user
export LAST_FM_PASS='pass'

cd ~/setup
./setup.sh
sudo reboot
```

Note: I'm afraid most references in the scripts are written in Japanese.

# Optional scripts
## Disable LEDs
One time
```bash
#!/bin/bash -e
echo none | sudo tee /sys/class/leds/led0/trigger > /dev/null # disable green led
echo none | sudo tee /sys/class/leds/led1/trigger > /dev/null # disable red led
echo 0 | sudo tee /sys/class/leds/led1/brightness > /dev/null
```

Forever
```bash
#!/bin/bash -ue
GREEN_LED_CMD="dtparam=act_led_trigger=none
dtoverlay=pi3-act-led,activelow=on"

echo "${GREEN_LED_CMD}" | sudo tee -a /boot/config.txt > /dev/null
echo "dtparam=pwr_led_trigger=none,pwr_led_activelow=on" | sudo tee -a /boot/config.txt > /dev/null
```

Ref: https://azriton.github.io/2017/09/20/Raspberry-Pi%E5%9F%BA%E7%9B%A4%E3%81%AELED%E3%82%92%E6%B6%88%E7%81%AF%E3%81%99%E3%82%8B/

## Overclocking
For CPU/GPU
- Ref: https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
- Ref: http://community.phileweb.com/mypage/entry/4787/20171122/

For SD card
- Ref: https://github.com/raspberrypi/linux/blob/rpi-4.9.y/arch/arm/boot/dts/overlays/README
- Ref: http://community.phileweb.com/mypage/entry/4787/20171105/57539/

## Install the latest kernel
`sudo rpi-update`

## Install upmpdcli
Create and edit `/etc/apt/sources.list.d/upmpdcli.list` and add the following lines.
```
deb http://www.lesbonscomptes.com/upmpdcli/downloads/raspbian-stretch/ stretch main
deb-src http://www.lesbonscomptes.com/upmpdcli/downloads/raspbian-stretch/ stretch main
```
Setup:
```bash
sudo apt -y install dirmngr
gpg --keyserver pool.sks-keyservers.net --recv-key 'F8E3 3472 5692 2A8A E767 605B 7808 CE96 D38B 9201'
gpg --export '7808CE96D38B9201' | sudo apt-key add -
sudo apt -y update
sudo apt -y install upmpdcli
```