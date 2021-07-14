#!/bin/bash
set -eux

if [ ! -e 2018-04-18-raspbian-stretch.zip ]; then
    wget http://ftp.jaist.ac.jp/pub/raspberrypi/raspbian/images/raspbian-2018-04-19/2018-04-18-raspbian-stretch.zip
fi
unzip 2018-04-18-raspbian-stretch.zip
truncate -s $((9500*1000000/512*512)) 2018-04-18-raspbian-stretch.img

DEVICE_PATH=`losetup -P --show -f 2018-04-18-raspbian-stretch.img`
echo $DEVICE_PATH

growpart $DEVICE_PATH 2
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
mkdir $MOUNT_POINT
mount ${DEVICE_PATH}p2 $MOUNT_POINT
cp -r ome-doc ome-packages $MOUNT_POINT/home/pi
rm -rf $MOUNT_POINT/home/pi/ome
cp -r ome2019 $MOUNT_POINT/home/pi/ome

umount $MOUNT_POINT
losetup -d $DEVICE_PATH
rm -rf $MOUNT_POINT
