#!/bin/bash
set -eux

usage_exit() {
  echo "Usage: $0 ome2019_branch_name" 1>&2
  exit 1
}

OME_PACKAGES_BRANCH=master
while getopts hp: OPT
do
  case $OPT in
    p) OME_PACKAGES_BRANCH=$OPTARG
      ;;
    h) usage_exit
      ;;
    \?) usage_exit
      ;;
  esac
done

shift $((OPTIND - 1))
if [ $# -ne 1 ]; then
  usage_exit
fi
OME2019_BRANCH_NAME=$1

if [ ! -e 2018-04-18-raspbian-stretch.zip ]; then
    wget http://ftp.jaist.ac.jp/pub/raspberrypi/raspbian/images/raspbian-2018-04-19/2018-04-18-raspbian-stretch.zip
fi
unzip 2018-04-18-raspbian-stretch.zip
truncate -s $((7800000000/512*512)) 2018-04-18-raspbian-stretch.img

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
    git clone git@adaptive.u-aizu.ac.jp:ome/ome2019.git -b $OME2019_BRANCH_NAME --recurse-submodules
fi

if [ ! -d ome-packages ]; then
    git clone git@adaptive.u-aizu.ac.jp:yshimmyo/ome-packages.git -b $OME_PACKAGES_BRANCH
    make -C ome-packages
fi

MOUNT_POINT=mount_point
mkdir -p $MOUNT_POINT/boot

mount ${DEVICE_PATH}p2 $MOUNT_POINT
mount ${DEVICE_PATH}p1 $MOUNT_POINT/boot

sed $MOUNT_POINT/boot/config.txt -i -e 's/#hdmi_force_hotplug=1/hdmi_force_hotplug=1/g'
rsync -auvP --chown=1000:1000 ome-packages/obj $MOUNT_POINT/home/pi --exclude .git
mv $MOUNT_POINT/home/pi/obj $MOUNT_POINT/home/pi/ome-packages
rsync -auvP --chown=1000:1000 ome2019 $MOUNT_POINT/home/pi --exclude .git --exclude .gitlab/issue_templates/テスト報告.md
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

LOCALE_CONF="LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:en LC_CTYPE=ja_JP.UTF-8 LC_NUMERIC=ja_JP.UTF-8 LC_TIME=ja_JP.UTF-8 LC_COLLATE=ja_JP.UTF-8 LC_MONETARY=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 LC_PAPER=ja_JP.UTF-8 LC_NAME=ja_JP.UTF-8 LC_ADDRESS=ja_JP.UTF-8 LC_TELEPHONE=ja_JP.UTF-8 LC_MEASUREMENT=ja_JP.UTF-8 LC_IDENTIFICATION=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8"

chroot $MOUNT_POINT sh -c "$LOCALE_CONF apt update"
chroot $MOUNT_POINT sh -c "$LOCALE_CONF apt install -y /home/pi/ome-packages/*.deb"
chroot $MOUNT_POINT sh -c "apt install xdg-user-dirs-gtk ; LANG=C xdg-user-dirs-gtk-update --force"
chroot $MOUNT_POINT su -c 'xdg-user-dirs-update' pi
chroot $MOUNT_POINT sh -c "cd /home/pi/ome/OpenHSP; make -f makefile.raspbian"
chroot $MOUNT_POINT sh -c "rsync -a /home/pi/ome/OpenHSP/ /home/pi/ome/bin"

# These are not necessary because raspberry pi does not actually launch and initial resize does not execute.
# sed -i 's;$; init=/usr/lib/raspi-config/init_resize.sh;g' ${MOUNT_POINT}/boot/cmdline.txt
# cp assets/resize2fs_once ${MOUNT_POINT}/etc/init.d/
# ln -s ../init.d/resize2fs_once ${MOUNT_POINT}/etc/rc3.d/S01resize2fs_once

umount_sysfds


umount $MOUNT_POINT/boot
umount $MOUNT_POINT

# Truncate filesystem and partition
e2fsck -f ${DEVICE_PATH}p2 && resize2fs -M ${DEVICE_PATH}p2
P2_BLOCK_COUNT=$(dumpe2fs -h ${DEVICE_PATH}p2 2>/dev/null | grep "Block count" | awk -F':' -e '{print $2}' | xargs)
P2_BLOCK_SIZE=$(dumpe2fs -h ${DEVICE_PATH}p2 2>/dev/null | grep "Block size" | awk -F':' -e '{print $2}' | xargs)

fdisk -w never -W never ${DEVICE_PATH} <<EEOF
d
2
n
p
2
98304
$((98304 + (P2_BLOCK_COUNT*P2_BLOCK_SIZE/512)))
EEOF
# dumpe2fs -h ${DEVICE_PATH}p2 | grep Block # to show shrinked filesystem size

TARGET_FILENAME=itschool-raspbian-$(date "+%Y-%m-%dT%H.%M.%S").img
# truncate -s ${FINAL_SIZE} $TARGET_FILENAME
COUNT=$(fdisk -l ${DEVICE_PATH} | grep -i 'Disk /dev' | sed 's/^.* \([0-9]\+\) sectors$/\1/g')
BS=$(fdisk -l ${DEVICE_PATH} | grep -i 'Units: ' | sed 's/^.* \([0-9]\+\) bytes$/\1/g')
dd if=2018-04-18-raspbian-stretch.img of=${TARGET_FILENAME} bs=$BS count=$COUNT status=progress

losetup -d $DEVICE_PATH
rm -rf $MOUNT_POINT
