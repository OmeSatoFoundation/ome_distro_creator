#!/bin/sh
BASEIMAGE=2018-04-18-raspbian-stretch
MOUNT_POINT=mount_point

umount -R $MOUNT_POINT
rm -rf $BASEIMAGE.zip $BASEIMAGE.img
rm -rf ome2019 ome-doc ome-packages

# TODO: parse `losetup` and detach loop devices related to $BASEIMAGE.img
