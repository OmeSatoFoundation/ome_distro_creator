#!/bin/bash
set -eux

bash ./clean.sh
#wget http://ftp.jaist.ac.jp/pub/raspberrypi/raspbian/images/raspbian-2018-04-19/2018-04-18-raspbian-stretch.zip
unzip 2018-04-18-raspbian-stretch.zip
truncate -s 7000MB 2018-04-18-raspbian-stretch.img

export DEVICE_PATH=`sudo losetup -P --show -f 2018-04-18-raspbian-stretch.img`
echo $DEVICE_PATH


sudo fdisk - w never -W never $DEVICE_PATH <<EEOF
p
d
2
n
p
2
98304
13671874
w
EEOF

sudo e2fsck -f ${DEVICE_PATH}p2
sudo resize2fs ${DEVICE_PATH}p2

wget https://adaptive.u-aizu.ac.jp/gitlab/ome/ome2019
wget https://adaptive.u-aizu.ac.jp/gitlab/ome/ome-doc
wget https://adaptive.u-aizu.ac.jp/gitlab/yshimmyo/ome-packages

MOUNT_POINT=mount_point
mkdir $MOUNT_POINT
sudo mount ${DEVICE_PATH}p2 $MOUNT_POINT
cp -r ome-doc ome-packages $MOUNT_POINT/home/pi
rm -rf $MOUNT_POINT/home/pi/ome
cp -r ome2019 $MOUNT_POINT/home/pi/ome

sudo umount $MOUNT_POINT
sudo losetup -d $DEVICE_PATH
rm -rf $MOUNT_POINT
