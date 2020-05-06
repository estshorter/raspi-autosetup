#!/bin/bash -eu

# Specify software version
MPD_MAJOR_VER=0.21
MPD_MINOR_VER=.22
MPD_VER="${MPD_MAJOR_VER}${MPD_MINOR_VER}"

ALSA_VER=1.2.2
FLAC_VER=1.3.3
MPG123_VER=1.25.13
FDK_AAC_VER=2.0.1
FFMPEG_VER=4.2.2

LIBMPDCLIENT_VER=2.18
MPDAS_VER=0.4.5

# Optimization option for Raspberry Pi 3
OPT="-O2 -march=armv8-a -mtune=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard -ffast-math -ftree-vectorize -funsafe-math-optimizations"

CURRENT_DIR=$(pwd)

SETUP1_DONE=".setup1_done"
SETUP2_DONE=".setup2_done"
SETUP3_DONE=".setup3_done"

setup1()
{
	sudo apt -y update
	sudo apt -y dist-upgrade
}
setup2()
{
	# Make commit interval long
	# Ref: https://iot-plus.net/make/raspi/extend-sdcard-lifetime-5plus1/
	sudo sed -i 's/ext4    defaults,noatime/ext4    defaults,noatime,commit=600/' /etc/fstab
	
	# Suppress rsyslog output
	# Ref: https://azriton.github.io/2017/03/16/Raspbian-Jessie-Lite%E3%81%AESD%E3%82%AB%E3%83%BC%E3%83%89%E5%BB%B6%E5%91%BD%E5%8C%96/
	# Ref: https://qiita.com/mashumashu/items/bbc3a79bc779fe8c4f99
	# COMMENT_BGN=$(grep -n "^daemon\.\*" /etc/rsyslog.conf | sed -e 's/:.*//g')
	COMMENT_BGN=$(grep -n "^auth,authpriv" /etc/rsyslog.conf | sed -e 's/:.*//g')
	COMMENT_END=$(grep -n "mail,news.none" /etc/rsyslog.conf | sed -e 's/:.*//g')
	sudo sed -ie "${COMMENT_BGN},${COMMENT_END}s:^:#:" /etc/rsyslog.conf
	sudo systemctl restart rsyslog

	# Disable swap 
	sudo swapoff --all
	sudo apt purge -y --auto-remove dphys-swapfile
	sudo rm -fr /var/swap

	# Put temp files to RAM disk
	sudo sed -ie '$ a tmpfs /tmp tmpfs defaults,size=32m,noatime,mode=1777 0 0' /etc/fstab
	sudo sed -ie '$ a tmpfs /var/tmp tmpfs defaults,size=16m,noatime,mode=1777 0 0' /etc/fstab
	sudo rm -fr /tmp
	sudo rm -fr /var/tmp

	# Put log files to RAM disk
	# Ref: https://qiita.com/ura14h/items/da058903149c1a4f71af
	sudo sed -ie '$ a tmpfs /var/log tmpfs defaults,size=32m,noatime,mode=0755 0 0' /etc/fstab
	# Ref: http://takuya-1st.hatenablog.jp/entry/2017/03/22/144700
	sudo sed -i 's/^exit 0$//g' /etc/rc.local

	INIT_SCRIPT="mkdir -p -m 750 /var/log/samba
mkdir -p /var/log/apt
mkdir -p /var/log/mpd
mkdir -p /var/log/nginx
chown root:adm /var/log/samba
chown root:adm /var/log/nginx
touch /var/log/lastlog
touch /var/log/wtmp
touch /var/log/btmp
chmod 664 /var/log/lastlog
chmod 664 /var/log/wtmp
chmod 600 /var/log/btmp
chown root:utmp /var/log/lastlog
chown root:utmp /var/log/wtmp
chown root:utmp /var/log/btmp
exit 0"

	echo "$INIT_SCRIPT" | sudo tee /etc/rc.local -a > /dev/null
	sudo rm -rf /var/log
}

setup3()
{
	# Check NAS user/pass/addr
	echo "NAS_USER=${NAS_USER}"
	echo "NAS_PASS=${NAS_PASS}"
	echo "NAS_ADDR=${NAS_ADDR}"

	# Check last.fm user/pass
	echo "LAST_FM_USER=${LAST_FM_USER}"
	echo "LAST_FM_PASS=${LAST_FM_PASS}"

	# Delete message of the day
	sudo rm /etc/motd
	sudo touch /etc/motd

	sudo sed -i 's/#NTP=/NTP=ntp.nict.jp/g' /etc/systemd/timesyncd.conf #NTP setting
	sudo sed -ie "/^exit 0$/i tvservice -o" /etc/rc.local # Disable HDMI
	sudo sed -ie '$ a dtoverlay=pi3-disable-wifi' /boot/config.txt # Disable Wi-Fi
	sudo sed -ie '$ a dtoverlay=pi3-disable-bt' /boot/config.txt # Disable Bluetooth
	sudo sed -ie '$ a disable_splash=1' /boot/config.txt # Disable splash screen
	# Disable the red led after startup
	#sudo sed -i 's/^exit 0$//g' /etc/rc.local
	#LED_CMD='echo none | sudo tee /sys/class/leds/led1/trigger > /dev/null
#echo 0 | sudo tee /sys/class/leds/led1/brightness > /dev/null
#exit 0'
	#echo "$LED_CMD" | sudo tee /etc/rc.local -a > /dev/null

	# Disable the red and green led
	# Ref: https://azriton.github.io/2017/09/20/Raspberry-Pi%E5%9F%BA%E7%9B%A4%E3%81%AELED%E3%82%92%E6%B6%88%E7%81%AF%E3%81%99%E3%82%8B/
	GREEN_LED_CMD="dtparam=act_led_trigger=none
dtoverlay=pi3-act-led,activelow=on"

	echo "${GREEN_LED_CMD}" | sudo tee -a /boot/config.txt > /dev/null
	echo "dtparam=pwr_led_trigger=none,pwr_led_activelow=on" | sudo tee -a /boot/config.txt > /dev/null

	# Disable UART
	# Ref: https://qiita.com/mt08/items/d27085ac469a34526f72
	# Ref: https://github.com/raspberrypi-ui/rc_gui/blob/master/src/rc_gui.c#L23-L70
	sudo raspi-config nonint do_serial 1
	sudo sed -i 's/^dtparam=audio=on//g' /boot/config.txt # Disable onboard audio
	sudo sed -ie '$ a dtoverlay=hifiberry-dacplus' /boot/config.txt # Enable I2S DAC
	# Specify japanese-lang
	sudo sed -i 's/^# ja_JP.EUC-JP EUC-JP/ja_JP.EUC-JP EUC-JP/g' /etc/locale.gen 
	sudo sed -i 's/^# ja_JP.UTF-8 UTF-8/ja_JP.UTF-8 UTF-8/g' /etc/locale.gen
	sudo locale-gen
	sudo update-locale LANG=ja_JP.UTF-8
	sudo timedatectl set-timezone Asia/Tokyo # Specify timezone

	# Decrease GPU assigned memory
	# Ref: https://jyn.jp/raspbian-setup/#SSH-2
	sudo raspi-config nonint do_memory_split 16
	sudo raspi-config nonint do_wifi_country JP

	# Enable hardware random-number-generator
	sudo apt -y install rng-tools

	# Install vim
	sudo apt -y install vim
	sudo apt -y purge vim-tiny
	
	# Specify the path folder
	sudo sed -i '1i/usr/local/lib/arm-linux-gnueabihf' /etc/ld.so.conf
	sudo sed -i '1i/usr/local/lib' /etc/ld.so.conf

	# Build alsa-lib
	# Ref: http://mimizukobo.sakura.ne.jp/articles/articles022.html#001
	ALSA_FILE_NAME="alsa-lib-${ALSA_VER}"

	mkdir alsa-lib
	cd alsa-lib
	wget ftp://ftp.alsa-project.org/pub/lib/${ALSA_FILE_NAME}.tar.bz2
	tar xf ${ALSA_FILE_NAME}.tar.bz2
	cd ${ALSA_FILE_NAME}
	./configure CFLAGS="${OPT}" CXXFLAGS="${OPT}" --prefix=/usr/local
	make -j4
	sudo make install
	sudo ldconfig
	cd ../../

	# Build libflac
	FLAC_FILE_NAME="flac-${FLAC_VER}"
	mkdir libflac
	cd libflac
	wget https://ftp.osuosl.org/pub/xiph/releases/flac/${FLAC_FILE_NAME}.tar.xz
	tar xf ${FLAC_FILE_NAME}.tar.xz
	cd ${FLAC_FILE_NAME}
	./configure CFLAGS="${OPT}" CXXFLAGS="${OPT}"
	make -j4
	sudo make install
	sudo ldconfig
	cd ../../

	# Build mpg123
	MPG123_FILE_NAME="mpg123-${MPG123_VER}"
	mkdir mpg123
	cd mpg123
	wget https://www.mpg123.de/download/${MPG123_FILE_NAME}.tar.bz2
	tar xf ${MPG123_FILE_NAME}.tar.bz2
	cd ${MPG123_FILE_NAME}
	./configure CFLAGS="${OPT}" --with-cpu=neon --with-optimization=2
	make -j4
	sudo make install
	sudo ldconfig
	cd ../../
	
	# Build FDK-AAC
	# Ref: http://nw-electric.way-nifty.com/blog/2018/02/aacmpd-fdk-aac-.html#more
	mkdir fdk-aac
	cd fdk-aac
	wget "https://downloads.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-${FDK_AAC_VER}.tar.gz?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fopencore-amr%2Ffiles%2Ffdk-aac%2Ffdk-aac-${FDK_AAC_VER}.tar.gz%2Fdownload&ts=1520338440" -O fdk-aac-${FDK_AAC_VER}.tar.gz
	tar xf fdk-aac-${FDK_AAC_VER}.tar.gz
	cd fdk-aac-${FDK_AAC_VER}
	./configure CFLAGS="${OPT}" CXXFLAGS="${OPT}"
	make -j4
	sudo make install
	sudo ldconfig
	cd ../../

	# Build FFmpeg
	FFMPEG_FILE_NAME="ffmpeg-${FFMPEG_VER}"
	# Ref: https://github.com/MusicPlayerDaemon/MPD/blob/master/python/build/libs.py
	FFMPEG_OPTIONS="--enable-gpl --enable-version3 --enable-nonfree --disable-programs --disable-doc --disable-avdevice --disable-swresample --disable-swscale --disable-postproc --disable-avfilter --disable-lzo --disable-faan --disable-pixelutils --disable-network --disable-encoders --disable-muxers --disable-protocols --disable-devices --disable-filters --disable-filters --disable-v4l2_m2m --disable-parser=bmp --disable-parser=cavsvideo --disable-parser=dvbsub --disable-parser=dvdsub --disable-parser=dvd_nav --disable-parser=flac --disable-parser=g729 --disable-parser=gsm --disable-parser=h261 --disable-parser=h263 --disable-parser=h264 --disable-parser=hevc --disable-parser=mjpeg --disable-parser=mlp --disable-parser=mpeg4video --disable-parser=mpegaudio --disable-parser=mpegvideo --disable-parser=opus --disable-parser=vc1 --disable-parser=vp3 --disable-parser=vp8 --disable-parser=vp9 --disable-parser=png --disable-parser=pnm --disable-parser=xma --disable-demuxer=aqtitle --disable-demuxer=ass --disable-demuxer=bethsoftvid --disable-demuxer=bink --disable-demuxer=cavsvideo --disable-demuxer=cdxl --disable-demuxer=dvbsub --disable-demuxer=dvbtxt --disable-demuxer=h261 --disable-demuxer=h263 --disable-demuxer=h264 --disable-demuxer=ico --disable-demuxer=image2 --disable-demuxer=jacosub --disable-demuxer=lrc --disable-demuxer=microdvd --disable-demuxer=mjpeg --disable-demuxer=mjpeg_2000 --disable-demuxer=mpegps --disable-demuxer=mpegvideo --disable-demuxer=mpl2 --disable-demuxer=mpsub --disable-demuxer=pjs --disable-demuxer=rawvideo --disable-demuxer=realtext --disable-demuxer=sami --disable-demuxer=scc --disable-demuxer=srt --disable-demuxer=stl --disable-demuxer=subviewer --disable-demuxer=subviewer1 --disable-demuxer=swf --disable-demuxer=tedcaptions --disable-demuxer=vobsub --disable-demuxer=vplayer --disable-demuxer=webvtt --disable-demuxer=yuv4mpegpipe --disable-decoder=flac --disable-decoder=mp1 --disable-decoder=mp1float --disable-decoder=mp2 --disable-decoder=mp2float --disable-decoder=mp3 --disable-decoder=mp3adu --disable-decoder=mp3adufloat --disable-decoder=mp3float --disable-decoder=mp3on4 --disable-decoder=mp3on4float --disable-decoder=opus --disable-decoder=vorbis --disable-decoder=atrac1 --disable-decoder=atrac3 --disable-decoder=atrac3al --disable-decoder=atrac3p --disable-decoder=atrac3pal --disable-decoder=binkaudio_dct --disable-decoder=binkaudio_rdft --disable-decoder=bmv_audio --disable-decoder=dsicinaudio --disable-decoder=dvaudio --disable-decoder=metasound --disable-decoder=paf_audio --disable-decoder=ra_144 --disable-decoder=ra_288 --disable-decoder=ralf --disable-decoder=qdm2 --disable-decoder=qdmc --disable-decoder=ass --disable-decoder=asv1 --disable-decoder=asv2 --disable-decoder=apng --disable-decoder=avrn --disable-decoder=avrp --disable-decoder=bethsoftvid --disable-decoder=bink --disable-decoder=bmp --disable-decoder=bmv_video --disable-decoder=cavs --disable-decoder=ccaption --disable-decoder=cdgraphics --disable-decoder=clearvideo --disable-decoder=dirac --disable-decoder=dsicinvideo --disable-decoder=dvbsub --disable-decoder=dvdsub --disable-decoder=dvvideo --disable-decoder=exr --disable-decoder=ffv1 --disable-decoder=ffvhuff --disable-decoder=ffwavesynth --disable-decoder=flic --disable-decoder=flv --disable-decoder=fraps --disable-decoder=gif --disable-decoder=h261 --disable-decoder=h263 --disable-decoder=h263i --disable-decoder=h263p --disable-decoder=h264 --disable-decoder=hevc --disable-decoder=hnm4_video --disable-decoder=hq_hqa --disable-decoder=hqx --disable-decoder=idcin --disable-decoder=iff_ilbm --disable-decoder=indeo2 --disable-decoder=indeo3 --disable-decoder=indeo4 --disable-decoder=indeo5 --disable-decoder=interplay_video --disable-decoder=jacosub --disable-decoder=jpeg2000 --disable-decoder=jpegls --disable-decoder=microdvd --disable-decoder=mimic --disable-decoder=mjpeg --disable-decoder=mmvideo --disable-decoder=mpl2 --disable-decoder=motionpixels --disable-decoder=mpeg1video --disable-decoder=mpeg2video --disable-decoder=mpeg4 --disable-decoder=mpegvideo --disable-decoder=mscc --disable-decoder=msmpeg4_crystalhd --disable-decoder=msmpeg4v1 --disable-decoder=msmpeg4v2 --disable-decoder=msmpeg4v3 --disable-decoder=msvideo1 --disable-decoder=mszh --disable-decoder=mvc1 --disable-decoder=mvc2 --disable-decoder=on2avc --disable-decoder=paf_video --disable-decoder=png --disable-decoder=qdraw --disable-decoder=qpeg --disable-decoder=rawvideo --disable-decoder=realtext --disable-decoder=roq --disable-decoder=roq_dpcm --disable-decoder=rscc --disable-decoder=rv10 --disable-decoder=rv20 --disable-decoder=rv30 --disable-decoder=rv40 --disable-decoder=sami --disable-decoder=sheervideo --disable-decoder=snow --disable-decoder=srt --disable-decoder=stl --disable-decoder=subrip --disable-decoder=subviewer --disable-decoder=subviewer1 --disable-decoder=svq1 --disable-decoder=svq3 --disable-decoder=tiff --disable-decoder=tiertexseqvideo --disable-decoder=truemotion1 --disable-decoder=truemotion2 --disable-decoder=truemotion2rt --disable-decoder=twinvq --disable-decoder=utvideo --disable-decoder=vc1 --disable-decoder=vmdvideo --disable-decoder=vp3 --disable-decoder=vp5 --disable-decoder=vp6 --disable-decoder=vp7 --disable-decoder=vp8 --disable-decoder=vp9 --disable-decoder=vqa --disable-decoder=webvtt --disable-decoder=wmv1 --disable-decoder=wmv2 --disable-decoder=wmv3 --disable-decoder=yuv4"

	mkdir ffmpeg
	cd ffmpeg
	wget http://ffmpeg.org/releases/${FFMPEG_FILE_NAME}.tar.xz
	tar xf ${FFMPEG_FILE_NAME}.tar.xz
	cd ${FFMPEG_FILE_NAME}
	./configure --enable-shared --enable-libfdk-aac --disable-decoder=aac --disable-decoder=aac_fixed --disable-decoder=aac_latm --optflags="${OPT}" --arch=armv8-a ${FFMPEG_OPTIONS} # --cpu is not specified as it generates warnings
	make -j4
	sudo make install
	sudo ldconfig
	cd ../../

	# MPD pre-process
	sudo mkdir -p /var/lib/mpd
	sudo mkdir -p /var/lib/mpd/music
	sudo mkdir -p /var/lib/mpd/playlists
	sudo mkdir -p /var/log/mpd 
	sudo mkdir -p /var/run/mpd
	sudo useradd -r -g audio -s /sbin/nologin mpd
	sudo chown -R mpd:audio /var/lib/mpd
	sudo chown -R mpd:audio /var/log/mpd

	# NAS setting
	# Ref: http://osa030.hatenablog.com/entry/2016/08/16/221838
	echo username=${NAS_USER} | sudo tee /etc/naspasswd > /dev/null
	echo password=${NAS_PASS} | sudo tee /etc/naspasswd -a > /dev/null
	sudo chmod 0600 /etc/naspasswd
	sudo mkdir -p /mnt/nas
	sudo ln -s /mnt/nas /var/lib/mpd/music/.
	sudo sed -ie "$ a //${NAS_ADDR} /mnt/nas cifs vers=1.0,credentials=/etc/naspasswd,noserverino,iocharset=utf8,ro,defaults 0 0" /etc/fstab
	sudo raspi-config nonint do_boot_wait 0 # Enable wait boot

	# Build MPD
	# Ref: http://nw-electric.way-nifty.com/blog/2016/08/mpdpi-2-pi-3-5a.html
	# Ref: https://github.com/MusicPlayerDaemon/MPD/blob/master/doc/user.xml
	sudo wget https://raw.githubusercontent.com/estshorter/raspi-autosetup/master/mpd.conf -O /usr/local/etc/mpd.conf # Get mpd.conf
	sudo apt -y install libid3tag0-dev libboost-dev libicu-dev libsystemd-dev ninja-build meson
	
	mkdir mpd
	cd mpd
	wget "https://www.musicpd.org/download/mpd/${MPD_MAJOR_VER}/mpd-${MPD_VER}.tar.xz"
	tar xf "mpd-${MPD_VER}.tar.xz"
	cd "./mpd-${MPD_VER}"
	MPD_OPTIONS="-Dfifo=false -Dhttpd=false -Drecorder=false -Dipv6=disabled -Ddsd=false -Dlibmpdclient=disabled -Dcurl=disabled -Dsystemd_system_unit_dir=/lib/systemd/system"
	# intentionally specify "--buildtype=plain"
	CFLAGS="${OPT}" CXXFLAGS="${OPT}" meson . output/release --buildtype=plain -Db_ndebug=true
	meson configure output/release ${MPD_OPTIONS}
	ninja -C output/release
	strip ./output/release/mpd
	sudo ninja -C output/release install
	# Change owner of /var/run/mpd when starting mpd
	# Specify high priority to MPD tasks
	# Ref: https://qiita.com/s-yama/items/2d6d7964ac39b08d925e
	# Ref: http://community.phileweb.com/mypage/entry/4787/201704/55263/
	MPD_INIT_CMD='PermissionsStartOnly=true
ExecStartPre=/bin/chown -R mpd:audio /var/run/mpd
#ExecStartPost=/usr/bin/chrt -a --fifo -p 99 $MAINPID'

	echo "$MPD_INIT_CMD" | sudo sed -ie '/\[Service\]/r /dev/stdin' /lib/systemd/system/mpd.service

	# Enable MPD service
	sudo systemctl enable mpd
	
	cd ../../

	# Build libmpdclient
	mkdir libmpdclient
	cd libmpdclient
	wget https://www.musicpd.org/download/libmpdclient/2/libmpdclient-${LIBMPDCLIENT_VER}.tar.xz
	tar Jxf libmpdclient-${LIBMPDCLIENT_VER}.tar.xz
	cd libmpdclient-${LIBMPDCLIENT_VER}
	CFLAGS="${OPT}" CXXFLAGS="${OPT}" meson . output
	ninja -C output
	sudo ninja -C output install
	sudo ldconfig
	cd ../../
	
	# Build mpdas for scrobbling to last.fm
	sudo apt -y install libcurl4-gnutls-dev
	mkdir mpdas
	cd mpdas
	wget https://github.com/hrkfdn/mpdas/archive/${MPDAS_VER}.tar.gz
	tar xf ${MPDAS_VER}.tar.gz
	cd mpdas-${MPDAS_VER}
	#wget https://github.com/hrkfdn/mpdas/archive/master.zip
	#unzip master.zip
	#cd mpdas-master	
	CXXFLAGS="${OPT}" make -j4
	strip mpdas
	sudo make install

	MPDAS_CONFIG="username = ${LAST_FM_USER}
password = ${LAST_FM_PASS}
runas = pi"
	echo "$MPDAS_CONFIG" | sudo tee /usr/local/etc/mpdasrc > /dev/null
	sudo chmod 0600 /usr/local/etc/mpdasrc

	MPDAS_SYSTEMD='[Unit]
Description=AudioScrobbler Client for MPD
After=mpd.service
[Service]
ExecStart=/usr/local/bin/mpdas
Type=simple
# Suppress log
StandardOutput=null 
[Install]
WantedBy=multi-user.target'

	echo "$MPDAS_SYSTEMD" | sudo tee /lib/systemd/system/mpdas.service > /dev/null
	sudo systemctl enable mpdas
	
	cd ../../

	# Provide cover art via http
	sudo apt -y install nginx-light
	# Supress nginx log
	# Ref: https://worklog.be/archives/2890
	sudo sed -i 's:^\s.*access_log.*$:        access_log off;:' /etc/nginx/nginx.conf
	sudo sed -i 's:^\s.*error_log.*$:        error_log /dev/null crit;:' /etc/nginx/nginx.conf

	sudo ln -s /var/lib/mpd/music /var/www/html/covers

	# Disable unnecessary service
	# Ref: http://omorodive.blogspot.jp/2017/10/raspberry-pilean-mpd.html
	# Ref: http://nw-electric.way-nifty.com/blog/2017/04/raspberry-pi-ze.html
	sudo systemctl disable triggerhappy
	sudo systemctl disable keyboard-setup
	sudo systemctl disable avahi-daemon
	sudo systemctl disable hciuart
	sudo systemctl disable bluetooth
	sudo systemctl disable getty@tty1
	sudo systemctl disable rpi-display-backlight

	# Disable usb-hub power
	# Ref: http://community.phileweb.com/mypage/entry/4787/20170401/55263/
	sudo apt -y install libusb-dev
	mkdir hub-ctrl
	cd hub-ctrl
	wget https://raw.githubusercontent.com/codazoda/hub-ctrl.c/master/hub-ctrl.c
	gcc -o hub-ctrl hub-ctrl.c -lusb ${OPT}
	strip hub-ctrl
	sudo cp ./hub-ctrl /usr/local/bin
	sudo sed -ie "/^exit 0$/i /usr/local/bin/hub-ctrl -h 0 -P 2 -p 0" /etc/rc.local
	cd ../

	# Enable ls aliases
	sed -i 's/^#alias ll='\''ls -l'\''/alias ll='\''ls -l'\''/g' ~/.bashrc
	sed -i 's/^#alias la='\''ls -A'\''/alias la='\''ls -A'\''/g' ~/.bashrc

	# Delete input log
	history -c
	
	sudo apt clean

	echo Reboot your system
}

main()
{
	if test -e $SETUP3_DONE
	then
		echo Setup done!
	elif test -e $SETUP2_DONE
	then
		echo setup3 starts
		setup3
		echo setup3 finished
		cd $CURRENT_DIR
		touch $SETUP3_DONE
		echo Reboot your system
	elif test -e $SETUP1_DONE
	then
		echo setup2 starts
		setup2
		echo setup2 finished
		cd $CURRENT_DIR
		touch $SETUP2_DONE
		echo Reboot your system
	else
		echo setup1 starts
		setup1
		echo setup1 finished
		cd $CURRENT_DIR
		touch $SETUP1_DONE
		echo Reboot your system
	fi
}



main
