# Dockerised Openbuudai

This is a VNC enabled container for Openbuudai / OpenHantek DSO Oscilloscope software.

If you don't want to install random stuff on your machine, this isolates you from all the build dependencies.

   https://github.com/doctormord/OpenBuudai

See the Dockerfile for detailed build and usage notes.

## Caveats

It doesn't work with "Docker (Desktop) for Mac", as they have removed the USB support.
You must use Docker Machine, and configure the Virtual Box USB "filter".

In Mac you have to use --privileged and also mount part of /dev which can be a security risk.

I found it very difficult to get this working, but once you get the magic recipe, it's actually quite reliable.

## MacOSX Magic Recipe

After a lot of experiments it turns out you need:

 - Docker-machine + Virtual Box
 - USB 2.0 enabled in Virtual Box
 - USB "filter" set up for the device in Virtual Box (plug it in and press the + icon)
 - `--privileged`  always seems needed
 - `-v /dev/usb/bus:/dev/usb/bus` mapped as a volume but only for it's just been plugged in. You can run a container without this if it's been run once with. I think this is flashing the firmware.

