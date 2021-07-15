#!/bin/bash
set -eux

if [ ! -e 2018-04-18-raspbian-stretch.zip ]; then
    wget http://ftp.jaist.ac.jp/pub/raspberrypi/raspbian/images/raspbian-2018-04-19/2018-04-18-raspbian-stretch.zip
fi
unzip 2018-04-18-raspbian-stretch.zip
truncate -s $((7000*1000000/512*512)) 2018-04-18-raspbian-stretch.img

DEVICE_PATH=`losetup -P --show -f 2018-04-18-raspbian-stretch.img`
echo $DEVICE_PATH

set +e
growpart $DEVICE_PATH 2
EXITCODE=$?
if [ $EXITCODE -ne 0 ] && [ $EXITCODE -ne 1 ]; then
  echo "growpart unexpectedly exited."
  exit $EXITCODE
fi
set -e

e2fsck -f ${DEVICE_PATH}p2 && resize2fs ${DEVICE_PATH}p2 

if [ ! -d ome2019 ]; then
    git clone git@adaptive.u-aizu.ac.jp:ome/ome2019.git
fi

if [ ! -d ome-doc ]; then
    git clone git@adaptive.u-aizu.ac.jp:ome/ome-doc.git
fi

if [ ! -d ome-packages ]; then
    git clone git@adaptive.u-aizu.ac.jp:yshimmyo/ome-packages.git
fi

MOUNT_POINT=mount_point
mkdir -p $MOUNT_POINT/boot

mount ${DEVICE_PATH}p2 $MOUNT_POINT
mount ${DEVICE_PATH}p1 $MOUNT_POINT/boot

sed $MOUNT_POINT/boot/config.txt -i -e 's/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/g'
rsync -auvP --chown=1000:1000 ome-doc $MOUNT_POINT/home/pi --exclude .git
rsync -auvP --chown=1000:1000 ome-packages $MOUNT_POINT/home/pi --exclude .git
rsync -auvP --chown=1000:1000 ome2019 $MOUNT_POINT/home/pi --exclude .git
mv $MOUNT_POINT/home/pi/ome2019 $MOUNT_POINT/home/pi/ome

# Install package dependencies
MOUNT_SYSFD_TARGETS="$MOUNT_POINT/proc $MOUNT_POINT/sys $MOUNT_POINT/dev $MOUNT_POINT/dev/shm $MOUNT_POINT/dev/pts"
MOUNT_SYSFD_SRCS="proc sysfs devtmpfs tmpfs devpts"

umount_sysfds () {
  /bin/cp -f $MOUNT_POINT/etc/hosts.org $MOUNT_POINT/etc/hosts || /bin/true
  /bin/cp -f $MOUNT_POINT/etc/resolv.conf.org $MOUNT_POINT/etc/resolv.conf || /bin/true
  for i in $(echo $MOUNT_SYSFD_SRCS | wc -w); do
    SRC=$(echo $MOUNT_SYSFD_SRCS | cut -d " " -f $i)
    TARGET=$(echo $MOUNT_SYSFD_TARGETS | cut -d " " -f $i)
    umount $TARGET || /bin/true
  done
}

for i in $(echo $MOUNT_SYSFD_SRCS | wc -w); do
  SRC=$(echo $MOUNT_SYSFD_SRCS | cut -d " " -f $i)
  TARGET=$(echo $MOUNT_SYSFD_TARGETS | cut -d " " -f $i)
  mount -t $SRC $SRC $TARGET
done

cp -f $MOUNT_POINT/etc/hosts $MOUNT_POINT/etc/hosts.org
cp -f $MOUNT_POINT/etc/resolv.conf $MOUNT_POINT/etc/resolv.conf.org
cp -f /etc/hosts $MOUNT_POINT/etc/
cp -f /etc/resolv.conf $MOUNT_POINT/etc/resolv.conf
cp /usr/bin/qemu-arm-static $MOUNT_POINT/usr/bin/

chroot $MOUNT_POINT sh -c "LANG=ja_JP.UTF-8 apt update"
chroot $MOUNT_POINT sh -c "LANG=ja_JP.UTF-8 apt install -y /home/pi/ome-packages/*.deb"

umount_sysfds

umount $MOUNT_POINT/boot
umount $MOUNT_POINT
losetup -d $DEVICE_PATH
rm -rf $MOUNT_POINT
