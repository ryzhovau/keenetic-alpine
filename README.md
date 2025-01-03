# keenetic-alpine
Alpine Linux on Keenetic

## Requirements
* Keenetic router with aarch64 CPU,
* ext2/3/4 formatted USB storage,
* 3.9 Alpha 0.3 (3.09.A.0.0-3) firmware or newer.

## Installation
* Make an installation archive from Entware/Alpine on router or [download](https://github.com/ryzhovau/keenetic-alpine/releases) it from here,
* Put `install-alpine-minirootfs-*-aarch64.tar.gz` into `install` folder on USB storage,
* Pick appropriate partition from Keenetic CLI:

```
opkg chroot
opkg initrc /opt/etc/ndm/initrc
opkg opkg disk <volume>
```

## Usage
You may connect to Alpine Linux via SSH root:alpine, TCP2222 port.

See you on https://forum.keenetic.com
