#!/bin/sh

set -e

echo 'Downloading sources…'
SRC_URL='http://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-minirootfs-3.21.0-aarch64.tar.gz'
SRC=$(echo $SRC_URL | grep -o '[^/]*$')
[ -f $SRC ] || wget $SRC_URL

echo 'Unpacking…'
BASE='alpine_rootfs'

# Safe removing previous root folder
if [ -d  $BASE ]; then
    [ -d $BASE/dev/pts ] && umount $BASE/dev
    [ -d $BASE/proc/1 ] && umount $BASE/proc
    [ -d $BASE/sys/bus ] && umount $BASE/sys
    rm -fr $BASE
fi
mkdir -p $BASE
tar -xzf $SRC -C $BASE

echo 'Preparing chroot environment…'
# Adding folders for hooks https://github.com/ndmsystems/packages/wiki/Opkg-Component#hook-scripts
for i in wan user netfilter usb fs time button schedule neighbour ifcreated \
  ifdestroyed ifipchanged ifip6changed iflayerchanged sms; do
    mkdir -p $BASE/etc/ndm/$i.d
done
# Few fixes for OpenRC init system
touch $BASE/run/openrc/softlevel
cat <<'EOF' > $BASE/etc/rc.conf
rc_sys="prefix"
rc_controller_cgroups="NO"
rc_depend_strict="NO"
rc_need="!hwdrivers !klogd !machine-id !mdev !modloop !osclock !rdate !s6-svscan !sysfsconf !syslog !watchdog !net !dev !udev-mount !sysfs !checkfs !fsck !netmount !logger !clock !modules"
EOF

# Adding necessary packages
mount -o bind /dev $BASE/dev
mount -o bind /proc $BASE/proc
mount -o bind /sys $BASE/sys
PATH=/usr/sbin:/usr/bin:/sbin:/bin SHELL=/bin/sh HOME=/root TERM=xterm \
    /opt/sbin/chroot $BASE /bin/sh -x <<'EOF'
apk add --no-cache alpine-base dropbear
rc-update --update
rc-update add dropbear
echo 'root:alpine' | chpasswd
EOF
umount $BASE/dev
umount $BASE/proc
umount $BASE/sys

# System tweaks
echo 'nameserver 127.0.0.1' > $BASE/etc/resolv.conf
sed -i -e 's|^DROPBEAR_OPTS.*|DROPBEAR_OPTS="-p 2222"|' $BASE/etc/conf.d/dropbear

# Make start script
cat <<'EOF' > $BASE/etc/ndm/initrc
#!/bin/sh

. /etc/profile

case "$1" in
    start)
        openrc default
        ;;
    stop)
        openrc single
        ;;
    *)
        echo "Usage: $0 (start|stop)"
        exit 1
        ;;
esac

exit 0
EOF

# Fix some NDM-specific env vars
cat <<'EOF' > $BASE/etc/profile.d/ndm.sh

#!/bin/sh

unset LD_BIND_NOW
unset LD_LIBRARY_PATH

EOF

# Copy this script to target archive
cp $0 $BASE/etc/ndm

echo 'Making target archive…'
TGT=install-$SRC
[ -f $TGT ] && rm -f $TGT
tar -czf $TGT -C $BASE .

echo 'Done! Now make clean Ext2/3/4 volume,'
echo "put $TGT to 'install' folder on it,"
cat <<'EOF'
configure Keenetic from CLI:

opkg chroot
opkg initrc /opt/etc/ndm/initrc
opkg opkg disk <volume>

You may connect to Alpine Linux via SSH root:alpine, TCP2222 port.
EOF
