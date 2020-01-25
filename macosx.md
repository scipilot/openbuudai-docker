# Mac host

10/03/2019 

Notes on trying to get this working via a Mac host.

   You need "Docker Toolbox" (VirtualBox, Docker Machine) 
   not "Docker [Desktop] for Mac" (Hyperkit) which can't/won't support device passthrough.
   Explanation and status of "Docker for Mac" ever supporting it: https://github.com/docker/for-mac/issues/900
   With Docker Machine/VirtualBox:
     Enable USB in VirtualBox
     docker run --volume /dev/bus/usb:/dev/bus/usb:rw
     - but this is only useful for reading memory sticks and the like with mounted filesystems. No good for us!
 
   See
     https://docs.docker.com/docker-for-mac/docker-toolbox/docker-toolbox-and-docker-desktop-for-mac-coexistence
     Various articles on how to do it (with VirtualBox, Docker Machine directly, not mentioning toolbox)
     https://milad.ai/docker/2018/05/06/access-usb-devices-in-container-in-mac.html
     http://gw.tnode.com/docker/docker-machine-with-usb-support-on-windows-macos/
 
     docker-machine create --driver virtualbox default
     docker-machine stop
     vboxmanage modifyvm default --usb on        ; for without VB Ext pack
     vboxmanage modifyvm default --usbxhci on    ; for with VB Ext Pack
     docker-machine start
     vboxmanage list usbhost
       Host USB Devices:
       UUID:               15e20325-d03d-4f81-8a4c-f828366f1923
       VendorId:           0x8102 (8102)
       ProductId:          0x8102 (8102)
       Revision:           0.0 (0000)
       Port:               1
       USB version/speed:  0/High
       Manufacturer:       BUUDAI 
       Product:            USB102
       Address:            p=0x8102;v=0x8102;s=0x00110f29920f4dc0;l=0x14100000
       Current State:      Available
    vboxmanage usbfilter add 1 --target default --name 'USB102' --vendorid 0x8102 --productid 0x8102
    vboxmanage usbfilter add 2 --target default --name 'USB-Serial Controller D' --vendorid 0x067b --productid 0x2303

    eval "$(docker-machine env default)"
     docker-machine ssh

   But... if you need VirtualBox anyway, you might as well just run Linux in it.
   It segfaults when I added a USB filter (as others have reported)
     It's fixed in Test build >= 128880 for VirtualBox 6.0 https://www.virtualbox.org/ticket/18341
     I have VB 6.0.4 = r128413 ! just downloaded today, so the fix is not released yet.
     Latest build is:  revision 129220
     Yes - this fixes it! in 6.0.5

   When it works you see:
     vboxmanage list usbhost
       Current State:      Captured

But finding the device is another matter. It doesn't appear as a /dev/ so I guess I need a driver - which comes full circle!?
    https://apple.stackexchange.com/questions/242104/is-there-a-way-to-access-a-usb-serial-port-by-the-device-id-not-by-the-tty-po 
    ioreg -r -c IOUSBHostDevice -l
    - there is no IOSerialBSDClient/ IODialinDevice

https://github.com/OpenHantek/openhantek/issues/6
    A 6022 libusb1.0 driver:
    https://github.com/rpm2003rpm/HT6022_Driver
        Uses libusb, opens the device directly using the vendorId and ModelId
        So this doesn't provide a general OS driver to make a /dev appear - perhaps that's not even expected? It's not a stream device.
    A cocoa (MacOSX) based GUI for the 6022 based on the driver:
        https://github.com/SergeOkon/HT6022_OSX

Similarly
https://sigrok.org/wiki/SainSmart_DDS120
fx2lafw is an open-source firmware for Cypress FX2 chips
- explains that the firmware in the FX2 chip is temporarily replaced with their OSS version when you plug it in. 
    This is why there's firmware in the drivers, which puzzled me.


Raw USB passthrough?

    https://github.com/boot2docker/boot2docker/issues/707

docker run -it --rm -p 5901:5900 --privileged -v /dev/bus/usb:/dev/bus/usb
When running in docker machine/VBOX  0.0.0.0 doesn't work. 
    Finder: connect to server `vnc://192.168.99.101:5901`  (the Docker Engine "default" VM address from `docker-machine env default`)

Apparently MacosX Sierra dropped the dev/bus/usb ? So the mount works, but it's empty!
https://stackoverflow.com/questions/29776333/mobile-devices-under-mac-os-x-to-connect-to-docker

This makes a list-usb tool, which show NONE.
http://www.michaelmcguffin.com/code/cintiq/listUSBDevices.c

So in summary: 
 - I can capture the USB successfully via VBox into Docker Machine, 
 - but cannot list the "non-storage" USB device inside a container. (even a tty-serial)
 - and I cannot share volume from /dev/bus which doesn't exist on my Mac (Sierra 10.12.6), even though many say they've done it. 
    One said Sierra "doesn't expose /dev/bus any more". --device doesn't seem to work either, but people can share phones and stuff via volumes.

USB/IP
http://usbip.sourceforge.net/
- no mac builds to date.

https://virtualhere.com/osx_server_software
https://virtualhere.com/sites/default/files/usbclient/vhclienti386
  Sigh, on installing it:   sh: 1: modprobe: not found
    "apt-get install kmod should do it, but I don't think you can load kernel modules in a Docker container. You need to load them on the host"
  https://hub.docker.com/r/virtualhere/virtualhere-client
    docker run -it --rm --privileged virtualhere/virtualhere-client:latest ash
       ./vhclientx86_64 -n
      "VirtualHere Client: init_module error inserting 'usbip-core.ko': -1 Bad file descriptor. Your kernel probably was not compiled with dynamic module loading functionality"
    but why is the OS wrong?? this is the VM host, not the guest?
      uname -a:     Linux acf8ee2e943f 4.14.104-boot2docker #1 SMP Thu Feb 28 20:58:57 UTC 2019 x86_64 Linux
    https://superuser.com/questions/889472/docker-containers-have-their-own-kernel-or-not
  So Boot2Docker needs dynamic module loading... feck.

    Try it in "Docker Desktop for Mac"...
    uname: Linux a8e079429a51 4.9.87-linuxkit-aufs #1 SMP Wed Mar 14 15:12:16 UTC 2018 x86_64 Linux
      VirtualHere Client: init_module error inserting 'usbip-core.ko': -1 Bad file descriptor. Your kernel probably was not compiled with dynamic module loading functionality

    I updated to D4M 18.06.1 (last one before 2.0.0.0 change)
      Linux d9db11894294 4.9.93-linuxkit-aufs #1 SMP Wed Jun 6 16:55:56 UTC 2018 x86_64 Linux
      Same problem.

  Changing the LinuxKit VM, seriously?
    It's possible, but not simple to modify the original VM .iso with D4M loads:    https://medium.com/@notsinge/making-your-own-linuxkit-with-docker-for-mac-5c1234170fb1

--

Recap from scratch

  Initialise Docker Machine

     docker-machine create --driver virtualbox default
     docker-machine stop
     ;vboxmanage modifyvm default --usb on        ; for without VB Ext pack
     vboxmanage modifyvm default --usbxhci on    ; for with VB Ext Pack
     vboxmanage usbfilter add 1 --target default --name 'USB102' --vendorid 0x8102 --productid 0x8102
     docker-machine start
     vboxmanage list usbhost

  eval "$(docker-machine env default)"

  Make this again (added to Dockerfile)
  http://www.michaelmcguffin.com/code/cintiq/listUSBDevices.c

--

After looking at the Dockerfile for VirtualHere - I realised, it's patching the kernel during the build 
- but I did `docker run` which downloads the image they built!
So I downloaded the Dockerfile and built it against my Docker Machine.

  error: Cannot generate ORC metadata for CONFIG_UNWINDER_ORC=y, please install libelf-dev, libelf-devel or elfutils-libelf-devel
  make: *** [Makefile:1103: prepare-objtool] Error 1

  libelf-dev

WORKS in LinuxKit (docker for mac) but not boot2docker (machine).


./vhclientx86_64 -t "MANUAL HUB ADD,10.0.1.7"  
./vhclientx86_64 -t list

OSX Hub (Pips-MacBook-Pro.local:7575) 
   --> USB-Serial Controller D (Pips-MacBook-Pro.local.336592896) 
   --> Apple Internal Keyboard / Trackpad (Pips-MacBook-Pro.local.339738624) 
   --> Bluetooth USB Host Controller (Pips-MacBook-Pro.local.338690048) 

AT LAST!!

I copied the kernel files into the openbuudai image...


  ./vhclientx86_64 -t "use,Pips-MacBook-Pro.local.336592896"
  ./vhclientx86_64 -t "device info,Pips-MacBook-Pro.local.336592896"
  ADDRESS: Pips-MacBook-Pro.local.336592896
  VENDOR: BUUDAI 
  VENDOR ID: 0x8102
  PRODUCT: USB102
  PRODUCT ID: 0x8102
  IN USE BY: NO ONE

  But the openhantek still says "No Buudai oscilloscopes found" :(

    I tried many things, but it kept crashing the server.

  ./vhclientx86_64 -t "AUTO USE device,Pips-MacBook-Pro.local.336592896"
  ./vhclientx86_64 -t "AUTO USE PORT,Pips-MacBook-Pro.local.336592896"
  ./vhclientx86_64 -t "device info,Pips-MacBook-Pro.local.336592896"

VirtualHere Client: Error attaching remote device 336592896 to vhci_hcd virtual port 0
VirtualHere Client: Open error 30 while attaching device to the virtual host controller
VirtualHere Client: Error attaching remote device 336592896 to vhci_hcd virtual port 0

etc.
https://www.virtualhere.com/content/error-when-useing-device
  "Error 30 means cannot open /sys/devices/platform/vhci_hcd/attach for writing because its on a read-only file system. You need to make sys writable. Its an odd error to have , ive never seen this error before but i think you have built rootfs for your docker image as read-only"

  root@78ce2cb0d38e:/# ls -l /sys/devices/platform/vhci_hcd/attach
  --w------- 1 root root 4096 Mar 14 08:17 /sys/devices/platform/vhci_hcd/attach

      cp /projects/virtualhere/*.ko .
      cp /projects/virtualhere/vhclientx86_64 .
      ./vhclientx86_64 -l vhc.log &
      apt-get install usbutils
      cat ~/.vhui 
      ./vhclientx86_64 -t "MANUAL HUB ADD,10.0.1.7" 
      ./vhclientx86_64 -t list
      ./vhclientx86_64 -t "use,Pips-MacBook-Pro.local.336592896"
      ./vhclientx86_64 -t "use,Pips-MacBook-Pro.local.336592896"
      lsusb

      cp /projects/openbuudai/listUSBDevices.c .
      gcc -o listUSBDevices listUSBDevices.c -lusb-1.0
      chmod +x listUSBDevices

  It's privileged - required to write to /sys!
  https://stackoverflow.com/questions/42938992/usbip-in-docker

  docker run -it --rm -v /Users/pipjones/dev/projects:/projects --privileged -p 5901:5900 openbuudai

  root@857519e75474:/# lsusb
  Bus 001 Device 004: ID 8102:8102  
  Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub

  Now if I run budaai/openhantex I get.... a different error...

  "Couldn't open device 001:004: No such device, it may have been disconnected."

  But it's progress!

  root@7519da66624d:/# ./listUSBDevices 
  2 USB devices found
  [device 0]
    idVendor: 33026
    idProduct: 33026
      We don't have permission to open the device. Maybe try running this program as root.
    iManufacturer = 1
    iProduct = 2
    iSerialNumber = 0

  So --privileged solved *one level* of permission, but there's still a problem, even for root in the container.
  Its actually returning (from http://libusb.sourceforge.net/api-1.0/group__libusb__misc.html)
    LIBUSB_ERROR_NO_DEVICE = -4,
    LIBUSB_ERROR_NO_DEVICE = if the device has been disconnected
    ...which matches what openhantek says.

  I tried other devices (SD reader, Serial port), they are the same. So it's not specific to the Oscilloscope.
  
  I can't tell if --privileged gives cap ALL.
    docker run -it --rm -v ~/dev/projects:/projects --privileged --cap-add=ALL -p 5901:5900 --name openbuudai openbuudai
  -  cap ALL doesn't help.

  Interestingly it's NOT "LIBUSB_ERROR_ACCESS if the user has insufficient permissions"
  so perhaps not a permission thing anymore, perhaps it is a disconnection problem...


    int API_EXPORTED libusb_open(libusb_device *dev,
      libusb_device_handle **dev_handle){
      ...
      if (!dev->attached) {
        return LIBUSB_ERROR_NO_DEVICE;
      }

  So it's a very early error, and could even be tested before calling. No it can't it's an opaque type.

  I read people upgrading and fixing issues...
  I managed to re-compile libusb which was a bit old. 
  But it was the same.
  Not sure if all these are needed...
    apt-get install autoconf
    apt-get install libtool
    apt-get install libudev
    apt-get install -f udev
    apt-get install systemd
    apt-get install libudev-dev
    ./autogen.sh 
    make
    make install
  lsusb --version
  lsusb (usbutils) 007

Ubuntu bionic has Package: libusb-1.0-0 (2:1.0.21-2)
Current version of github libusb is v1.0.22

  dpkg -l libusb-1.0*
  apt-cache policy libusb-1.0*
  Show it was 1.0.21 


16/03/2019 gave up!
====================

25/01/2010 Retry!
-----------------

I thought I'd give it a quick retry, with any recent updates.

Currrent DockerDesktop:2.1.00 Engine:19.03.01 Machine:0.16.1
Updated  DockerDesktop:2.1.05 Engine:19.? Machine:0.?

Remembering what to do:
