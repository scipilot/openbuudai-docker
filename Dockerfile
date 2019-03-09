# docker build -t openbuudai .
FROM ubuntu

RUN apt-get update \
 && apt-get install -y wget \
 && apt-get install -y zip \
 && apt-get install -y build-essential \
 && apt-get install -y libqt4-dev \
 && apt-get install -y libfftw3-dev \
 && apt-get install -y libusb-1.0-0-dev

# supervisor is in the ubuntu-universe repo, but first add apt-add-repository command
RUN apt-get install -y software-properties-common \
 && apt-add-repository universe \
 && apt-get install -y supervisor


# grab the source e.g. git clone https://github.com/doctormord/OpenBuudai.git 
RUN mkdir /app && cd app \
 && wget https://github.com/doctormord/OpenBuudai/archive/master.zip \
 && unzip master.zip \
 && cd OpenBuudai-master/Source

# Edit the makefile to switch to Linux
# (No need to add includes for libqt-dev and libfftw-dev)
# For libs /usr/lib/x86_gnu_linux seems already in the libpath, so just need:
#   LIBS += -lusb-1.0
#   LIBS += -lfftw3
#   this is already provided by the "Find .lib files Linux Build" but it has windows paths! which will be ignored (note talk to developer to remove those)
#   so just swap the comments and it works
RUN cd /app/OpenBuudai-master/Source \
 && sed -ie '/Find \.lib files$/ s/^/#/' OpenHantek.pro \ 
 && sed -ie '/Find .lib files Linux Build/ s/^#//' OpenHantek.pro

# build
RUN cd /app/OpenBuudai-master/Source \
 && qmake PREFIX=/usr \
 && make \
 && make install

# it now should be in /usr/local/bin/openhantek
#   openhantek: cannot connect to X server 

# With Joe's window manager https://joshh.info/2016/xserver-inside-docker-container/
#RUN apt-get install -y xserver-xorg xorg jwm
# ...didn't work.

# Selenium Standalone Debug uses fluxbox and vnc
#   https://github.com/SeleniumHQ/docker-selenium/blob/master/NodeFirefoxDebug/Dockerfile
# so could base this image off NodeDebug?
# XVFB in-memory display, is required by Fluxbox (Selenium splits out the Dockerfiles I've re-combined them) 
# I also skipped all the user stuff.

# stop tzdata interaction
ENV DEBIAN_FRONTEND=noninteractive
# Note: defaults to UTC, Run 'dpkg-reconfigure tzdata' if you wish to change it.

#=====
# VNC
#=====
RUN apt-get update -qqy \
  && apt-get -qqy install \
  x11vnc \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#==============
# Xvfb
#==============
RUN apt-get update -qqy \
  && apt-get -qqy install \
    xvfb \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#=========
# fluxbox
# A fast, lightweight and responsive window manager
#=========
RUN apt-get update -qqy \
  && apt-get -qqy install \
    fluxbox \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN mkdir -p ${HOME}/.vnc \
  && x11vnc -storepasswd secret ${HOME}/.vnc/passwd

#==============================
# Scripts to run fluxbox and x11vnc and 
#==============================
# Make sure these are chmod +x locally before copy
COPY start-fluxbox.sh \
      start-vnc.sh \
      start-xvfb.sh \
      /opt/bin/

#============================
# Some configuration options
#============================
ENV SCREEN_WIDTH 1360
ENV SCREEN_HEIGHT 1020
ENV SCREEN_DEPTH 24
ENV DISPLAY :99.0
ENV START_XVFB true

#==============================
# Supervisor configuration file
#==============================
# I removed selenium itself, we just want the X stack!
COPY selenium.conf selenium-debug.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc

RUN  mkdir -p /opt/selenium /var/run/supervisor /var/log/supervisor

COPY entry_point.sh /opt/bin/

CMD ["/opt/bin/entry_point.sh"]

# docker run -it --rm -p 5901:5900 openbuudai
#  Finder: connect to server vnc://0.0.0.0:5901 
#  bash > /usr/local/bin/openhantek

# How to connect usb?
# Linux host: docker run --device /dev/ttyUSB0 
# Mac:
# Apparently need "Docker Toolbox" (VirtualBox, Docker Machine) not "Docker for Mac" (Hyperkit)?
#   might be because "Docker Desktop for Mac can’t route traffic to containers, so you can’t directly access an exposed port on a running container from the hosting machine."
# Explanation: https://github.com/docker/for-mac/issues/900
# Use Docker Toolbox:
# 	enable USB in VirtualBox
# 	Mac Host: --volume /dev/bus/usb:/dev/bus/usb:rw
# test:
# docker run --rm -it -v `pwd`:/app --device /dev/tty.usbserial node bash
#	yes this errors as described.
# https://milad.ai/docker/2018/05/06/access-usb-devices-in-container-in-mac.html
# http://gw.tnode.com/docker/docker-machine-with-usb-support-on-windows-macos/
# https://docs.docker.com/docker-for-mac/docker-toolbox/#docker-toolbox-and-docker-desktop-for-mac-coexistence
# 