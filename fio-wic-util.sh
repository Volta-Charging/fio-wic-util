#!/bin/bash
# This script can be used to mount, modify, and repackage Foundries WIC image archives.
# It may come in handy in use cases such as the following:
# - Want to examine the contents of the initramfs used to install the Foundries image.
# - Want to quickly make changes to the foundries installer or main rootfs without doing
#   a complete Yocto rebuild.
# - [Not implemented] Want to examine the contents of the rootfs from the main image.

WORKDIR=/tmp/fio-wic-util
WICMNTPATH=$WORKDIR/wic-part
INST_IRFS_PATH=$WORKDIR/installer-initramfs
TMPCPIOGZ=$WORKDIR/core-image-minimal-initramfs-intel-corei7-64.cpio.gz

WICGZ=""
WIC=""

usage()
{
  echo
  echo "Usage: $0 <command> [arguments..]"
  echo
  echo "Commands:"
  echo "  unzip <gzipped image>        Unzip the image to working directory."
  echo "  inspect                      Inspect previously unzipped WIC image."
  echo "  mount_wic_part <partition>   Mount a partition from previously unzipped WIC image."
  echo "                               - <partition> must be one of { wic1, wic2, wic3 }"
  echo "                               - Only one partition may be mounted at a time."
  echo "  umount_wic_part              Unmounts the currently mounted WIC partition."
  echo "  unpack_installer             Unpack the installer initramfs from WIC partition to working directory."
  echo "                               - The wic1 partition must be mounted already"
  echo "  repack_installer           # Repack the installer initramfs back into the mounted WIC partition."
  echo "                               - The wic1 partition must be mounted already"
  echo "  rezip                      # Re-zip previously unzipped WIC image."
  echo "                               - All WIC partitions must be unmounted already"
  echo "  help                       # Show usage."
  echo
  echo "Example flow:"
  echo
  echo "$0 unzip image.wic.gz"
  echo "sudo $0 inspect"
  echo "sudo $0 mount_wic_part wic1"
  echo "sudo $0 unpack_installer"
  echo "# Make modifications to installer"
  echo "sudo $0 repack_installer"
  echo "sudo $0 umount_wic_part"
  echo "sudo $0 rezip"
  echo
}

detect_wic()
{
  WIC=$(ls $WORKDIR | grep -E "\.wic$")
  if [ $? -ne 0 ]; then
    echo "ERROR: No previously extracted .wic file detected."
    echo " Please use the unzip command to unzip a wic.gz first."
    usage
    exit 1
  fi
  WIC=$WORKDIR/$WIC
}

inspect_wic()
{  
  fdisk -l $WIC
}

wic_unzip()
{
  WICGZ=$1

  if [ -z "$WICGZ" ]; then
    echo "ERROR: No .wic.gz file specified!"
    usage
    exit 1
  elif [ ! -f $WICGZ ]; then
    echo "ERROR: File does not exist: $WICGZ"
    usage
    exit 1
  fi

  WIC=$WORKDIR/$(basename ${WICGZ::-3})

  echo "Extracting $WICGZ to $WIC ..."
  gunzip -ck $WICGZ > $WIC  

  echo "Extraction complete."
  echo

  inspect_wic
}

wic_rezip()
{
  detect_wic
  verify_wic_not_mounted

  echo
  echo "Rezipping the WIC image..."
  gzip -ck $WIC > $WORKDIR/volta-factory-image-intel-corei7-64.modified.wic.gz

  echo
  echo "Successfully rezipped the image to $WORKDIR/volta-factory-image-intel-corei7-64.modified.wic.gz"
}

mount_wic_part()
{
  WICPART=$1
  if [ -z "$WICPART" ]; then
    echo "ERROR: No wic partition specified!"
    usage
    exit 1
  elif [ ! $WICPART = "wic1" ] && [ ! $WICPART = "wic2" ] && [ ! $WICPART = "wic3" ]; then
    echo "ERROR: Invalid wic partition specified: $WICPART"
    usage
    exit 1
  fi

  mkdir -p $WICMNTPATH

  echo "Mounting $WIC to $WICMNTPATH ..."
  OFFSET=$(fdisk -l $WIC | grep $WICPART | awk '{ print $2 }')
  sudo mount -o loop,offset=$((512 * $OFFSET)) $WIC $WICMNTPATH
  if [ $? -ne 0 ]; then
    echo
    echo "ERROR: Failed to mount!"
    exit 1
  else
    echo
    echo "Successfully mounted $WIC partition $WICPART on $WICMNTPATH"
  fi
}

unmount_wic_part()
{
  echo
  echo "Unmounting the WIC image from $WICMNTPATH ..."
  umount $WICMNTPATH > /dev/null 2>&1
  echo "Successfully unmounted $WICMNTPATH"
}

verify_wic1_mounted()
{
  if [ ! -f $WICMNTPATH/core-image-minimal-initramfs-intel-corei7-64.cpio.gz ]; then
    echo "ERROR: The wic1 partition has not been mounted."
    echo " Please mount it first using the mount_wic_part command."
    usage
    exit 1
  fi
}

verify_wic_not_mounted()
{
  if [ -n "$(ls $WICMNTPATH)" ]; then
    echo "ERROR: No wic partition may be mounted for this operation."
    echo " Please unmount first using the umount_wic_part command."
    usage
    exit 1
  fi
}

installer_initramfs_unpack()
{
  verify_wic1_mounted

  echo
  echo "Extracting the installer initramfs to $INST_IRFS_PATH ..."
  rm -rf $INST_IRFS_PATH
  mkdir -p $INST_IRFS_PATH
  pushd .
  cd $INST_IRFS_PATH
  sudo gzip -cd $WICMNTPATH/core-image-minimal-initramfs-intel-corei7-64.cpio.gz | cpio -idm 
  popd

  echo
  echo "Now you may examine or make changes as needed in the initramfs extracted to $INST_IRFS_PATH."
  echo "If changes are made, you may use the repack_installer and rezip commands to pack it back up"
  echo "into a wic.gz for installation using USB installer or OTA migration."
}

installer_initramfs_repack()
{
  verify_wic1_mounted

  pushd .
  cd $INST_IRFS_PATH

  echo
  echo "Packing the extracted files back into a cpio.gz initramfs..."
  find . | cpio -H newc -o | gzip -9 > $TMPCPIOGZ

  echo
  echo "Copying the repacked initramfs back into the mounted wic partition..."
  cp $TMPCPIOGZ $WICMNTPATH/
  rm $TMPCPIOGZ > /dev/null 2>&1

  popd
}

CMD=$1

if [ -z "$CMD" ]; then
  usage
  exit 1
fi

case $CMD in
  unzip)
    mkdir -p $WORKDIR
    wic_unzip $2
    ;;
  inspect)
    detect_wic
    inspect_wic
    ;;
  mount_wic_part)
    detect_wic
    mount_wic_part $2
    ;;
  umount_wic_part)
    unmount_wic_part
    ;;
  unpack_installer)
    installer_initramfs_unpack
    ;;
  repack_installer)
    installer_initramfs_repack
    ;;
  rezip)
    wic_rezip
    ;;
  help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: Invalid command!"
    usage
    exit 1
    ;;
esac