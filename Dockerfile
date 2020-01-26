#
# Docker VNC container for Openbuudai, to isolate yourself from the build requirements.
#   https://github.com/doctormord/OpenBuudai
# 
# VNC password is:"secret" (set below)
# usage e.g.:
#
#   docker build -t scipilot/openbuudai .
#
# Connecting the USB through is a bit tricky!
#
# Linux host: 
#   docker run --device /dev/ttyUSB0 
#
# Mac host: See macosx.md - it only works in Docker Machine (not Docker Desktop)
#   docker run -it --rm -p 5901:5900  --privileged -v /dev/bus/usb:/dev/bus/usb --name openbuudai scipilot/openbuudai
#   open vnc://0.0.0.0:5901
#
#   - Or Finder: connect to server `vnc://0.0.0.0:5901`   (aka "Screen Sharing")
#   - where 0.0.0.0 is the docker-machine's IP from `$DOCKER_HOST` (without the tcp: and :port)
#   - or from `docker-machine ip default` (if 'default' is your boot2docker name)
#
# Windows host: (todo - I don't have one! But the original software runs natively anyway.)
#
#==================================================================================================
FROM ubuntu

# Prerequisite Packages ===========================================================================

# stop tzdata interaction
ENV DEBIAN_FRONTEND=noninteractive
# Note: defaults to UTC, Run 'dpkg-reconfigure tzdata' if you wish to change it.

# usbutils for diagnostics inc. lsusb (not needed to run)
# build-essential: gcc, g++, make
# supervisor: is in the ubuntu-universe repo, so first add the apt-add-repository command via software-properties-common
# Openbuudai requires: libqt4-dev libfftw3-dev libusb-1.0-0-dev 
# VNC gui: x11vnc xvfb fluxbox 
# All done in one RUN and cleaned up to reduce image layer size.
RUN apt-get update -qqy \
 && apt-get install -qqy apt-utils
RUN apt-get install -qqy wget zip usbutils vim \
 && apt-get install -qqy build-essential \
 && apt-get install -qqy libqt4-dev libfftw3-dev libusb-1.0-0-dev \
 && apt-get install -qqy software-properties-common \
 && apt-add-repository universe \
 && apt-get install -qqy supervisor \
 && apt-get install -qqy x11vnc xvfb fluxbox 
# && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# OpenBuudai ==============================

# grab the source e.g. git clone https://github.com/doctormord/OpenBuudai.git 
RUN mkdir /app && cd app \
 && wget https://github.com/doctormord/OpenBuudai/archive/master.zip \
 && unzip master.zip 

# Edit the OpenBuudai makefile to switch to Linux
# (No need to add includes for libqt-dev and libfftw-dev)
# For libs /usr/lib/x86_gnu_linux seems already in the libpath, so just need:
#   LIBS += -lusb-1.0
#   LIBS += -lfftw3
#   this is already provided by the "Find .lib files Linux Build" but it has windows paths! which will be ignored (note talk to developer to remove those)
#   so just swap the comments and it works
RUN cd /app/OpenBuudai-master/Source \
 && sed -ie '/Find \.lib files$/ s/^/#/' OpenHantek.pro \ 
 && sed -ie '/Find .lib files Linux Build/ s/^#//' OpenHantek.pro

# build OpenBuudai
RUN cd /app/OpenBuudai-master/Source \
 && qmake PREFIX=/usr \
 && make \
 && make install

# it now should be in /usr/local/bin/openhantek

# GUI ==============================
# VNC, Xvfb - in-memory virtual screen required for Fluxbox
# fluxbox -  A fast, lightweight and responsive window manager

# Taking inspiration from Selenium Standalone Debug, which uses x11-vnc, fluxbox and Xvfb
#   e.g. https://github.com/SeleniumHQ/docker-selenium/blob/master/NodeFirefoxDebug/Dockerfile and others
# I skipped all the user stuff.

# see top for: apt-get x11vnc xvfb fluxbox 

# Set VNC password
RUN mkdir -p ${HOME}/.vnc \
  && x11vnc -storepasswd secret ${HOME}/.vnc/passwd

# Scripts to run fluxbox and x11vnc and 
# Make sure these are chmod +x locally first
COPY start-fluxbox.sh start-vnc.sh start-xvfb.sh /opt/bin/

# Some configuration options
ENV SCREEN_WIDTH 1360
ENV SCREEN_HEIGHT 1020
ENV SCREEN_DEPTH 24
ENV DISPLAY :99.0
ENV START_XVFB true

# Supervisor configuration, in case the programs crash.
COPY openbuudai.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc
RUN  mkdir -p /var/run/supervisor /var/log/supervisor

#====================================================
# Make this tool for USB diagnosis
# COPY listUSBDevices.c /app/
# RUN cd /app && gcc -o listUSBDevices listUSBDevices.c -lusb-1.0

#====================================================

# Install Docker entry point to run everything
COPY entry_point.sh /opt/bin/
CMD ["/opt/bin/entry_point.sh"]
