#!/bin/sh

set -e

echo 'Downloading sources…'
SRC_URL='http://dl-cdn.alpinelinux.org/alpine/v3.16/releases/aarch64/alpine-minirootfs-3.16.0-aarch64.tar.gz'
SRC=$(echo $SRC_URL | grep -o '[^/]*$')
[ -f $SRC ] || wget $SRC_URL

echo 'Unpacking…'
BASE='chroot_alpine'

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
# Adding folders for hooks
for i in button fs ifcreated ifdestroyed ifipchanged ifstatechanged neighbour netfilter schedule sms time usb user wan; do
    mkdir -p $BASE/etc/ndm/$i.d
done

# Adding necessary packages
mount -o bind /dev $BASE/dev
mount -o bind /proc $BASE/proc
mount -o bind /sys $BASE/sys
PATH=/usr/sbin:/usr/bin:/sbin:/bin SHELL=/bin/sh HOME=/root TERM=xterm \
    /opt/sbin/chroot $BASE /bin/sh -x <<'EOF'
apk add --no-cache alpine-base dropbear
rc-update add dropbear
echo 'root:alpine' | chpasswd
EOF
umount $BASE/dev
umount $BASE/proc
umount $BASE/sys

# Few fixes for OpenRC init system
echo 'nameserver 127.0.0.1' > $BASE/etc/resolv.conf
echo > $BASE/etc/fstab
sed -i -e 's|^DROPBEAR_OPTS.*|DROPBEAR_OPTS="-p 2222"|' $BASE/etc/conf.d/dropbear
rm $BASE/lib/sysctl.d/*
for i in dev devfs firstboot fsck killprocs localmount logger loopback mdev \
    modloop mount-ro mtab networking procfs root sysfs sysfsconf syslog \
    termencoding udhcpd urandom watchdog; do
    cat <<'EOF' > $BASE/etc/init.d/$i
#!/sbin/openrc-run

start()
{
    return 0
}
EOF
    chmod +x $BASE/etc/init.d/$i
done

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
