#!/bin/bash

WICGZ=$1

usage() {
  echo "$0 <wiz.gz file>"
}

if [ -z "$WICGZ" ]; then
  usage
  exit 1
fi

WIC=${WICGZ::-3}
WICMNTPATH=/tmp/fio-wic
IRFSMNTPATH=/tmp/fio-irfs

#echo "Extracting $WICGZ ..."
#gunzip -k $WICGZ

#stat $WIC

umount $WICMNTPATH > /dev/null 2>&1  
mkdir -p $WICMNTPATH

echo "Mounting $WIC to $WICMNTPATH ..."
OFFSET1=$(fdisk -l $WIC | grep wic1 | awk '{ print $2 }')
sudo mount -o loop,offset=$((512 * $OFFSET1)) $WIC $WICMNTPATH

ls $WICMNTPATH

echo ""
echo "Extracting the initramfs to $IRFSMNTPATH ..."
rm -rf $IRFSMNTPATH
mkdir -p $IRFSMNTPATH
cd $IRFSMNTPATH
sudo gzip -cd $WICMNTPATH/core-image-minimal-initramfs-intel-corei7-64.cpio.gz | cpio -idm 

ls

echo ""
echo "Now you may make changes as needed in the initramfs extracted to $IRFSMNTPATH,"
echo "then you can run the pack-initramfs.sh script to pack it back up into a wic.gz"
echo "for installation using USB installer or OTA migration."
