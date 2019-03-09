#
# Docker VNC container for Openbuudai, to isolate yourself from the build requirements.
#   https://github.com/doctormord/OpenBuudai
# 
# VNC password is:"secret" (set below)
# usage e.g.:
#
#   docker build -t openbuudai .
#   docker run -it --rm -p 5901:5900 --device /dev/ttyUSB0 openbuudai
#   (mac) Finder: connect to server `vnc://0.0.0.0:5901`   
#   bash> /usr/local/bin/openhantek
#
# How to connect USB through?
#
# Linux host: 
#   docker run --device /dev/ttyUSB0 
#
# Mac host:
#   You need "Docker Toolbox" (VirtualBox, Docker Machine) not "Docker for Mac" (Hyperkit) which 
#   can't/won't support device passthrough.
#   Explanation and status of Docker for Mace ever supporting it: https://github.com/docker/for-mac/issues/900
#   In Docker Toolbox:
#     Enable USB in VirtualBox
#     docker run --volume /dev/bus/usb:/dev/bus/usb:rw
# 
#   See
#     https://docs.docker.com/docker-for-mac/docker-toolbox/#docker-toolbox-and-docker-desktop-for-mac-coexistence
#     Various articles on how to do it (with VirtualBox, Docker Machine directly, not mentioning toolbox)
#     https://milad.ai/docker/2018/05/06/access-usb-devices-in-container-in-mac.html
#     http://gw.tnode.com/docker/docker-machine-with-usb-support-on-windows-macos/
# 
#   But... if you need VirtualBox anyway, you might as well jut run Linux in it.
#
# Windows host: (todo - I don't have one!)
#
#==================================================================================================
FROM ubuntu

# Prerequisite Packages ===========================================================================

# stop tzdata interaction
ENV DEBIAN_FRONTEND=noninteractive
# Note: defaults to UTC, Run 'dpkg-reconfigure tzdata' if you wish to change it.

# build-essential: gcc, g++, make
# supervisor: is in the ubuntu-universe repo, so first add the apt-add-repository command via software-properties-common
# Openbuudai requires: libqt4-dev libfftw3-dev libusb-1.0-0-dev 
# VNC gui: x11vnc xvfb fluxbox 
# All done in one RUN and cleaned up to reduce image layer size.
RUN apt-get update -qqy \
 && apt-get install -qqy wget zip \
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
# so could base this image off NodeDebug?
# I also skipped all the user stuff.

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

# Supervisor configuration file
COPY openbuudai.conf /etc/supervisor/conf.d/
COPY supervisord.conf /etc
RUN  mkdir -p /var/run/supervisor /var/log/supervisor

#====================================================

# Install Docker entry point to run everything
COPY entry_point.sh /opt/bin/
CMD ["/opt/bin/entry_point.sh"]
