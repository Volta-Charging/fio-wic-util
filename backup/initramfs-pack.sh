#!/bin/bash
# This script is intended to be run after using the mount-initramfs.sh script.
# It uses the /tmp paths from that script.

WICMNTPATH=/tmp/fio-wic
IRFSMNTPATH=/tmp/fio-irfs
TMPCPIOGZ=/tmp/core-image-minimal-initramfs-intel-corei7-64.cpio.gz

rm $TMPCPIOGZ > /dev/null 2>&1

cd $IRFSMNTPATH

echo ""
echo "Packing the extracted files back into a cpio.gz initramfs..."
find . | cpio -H newc -o | gzip -9 > $TMPCPIOGZ

echo ""
echo "Copying the repacked initramfs back into the mounted wic partition..."
cp $TMPCPIOGZ $WICMNTPATH/

echo ""
echo "Unmounting the WIC image..."
umount $WICMNTPATH > /dev/null 2>&1

echo ""
echo "Rezipping the WIC image..."
#gzip -c volta-factory-image-intel-corei7-64.wic > volta-factory-image-intel-corei7-64.modified.wic.gz
