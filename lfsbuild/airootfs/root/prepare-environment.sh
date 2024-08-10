#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 1 ] || bail "Drive device path required."

# Export the LFS environment variable
export LFS=/mnt/lfs

# Define the minimum disk size
MinimumSizeMB=10240

# Calculate Drive Space Usages
MemSize=$(free --bytes|grep Mem|awk -F ' ' '{print $2}')
MemSizeMB=$(( $MemSize / 1024 / 1024 ))

DiskSize=$(lsblk $1 --bytes --json|jq .blockdevices[0].size)
DiskSizeMB=$(( $DiskSize / 1024 / 1024 ))

SwapSizeMB=$(( ($MemSizeMB * 2) - 1 ))
BootSizeMB=512
RootSizeMB=$(( $DiskSizeMB - $SwapSizeMB - $BootSizeMB - 2 ))

# Let the user know about the sizes that was calcualted out
echo "        Memory Size = ${MemSizeMB}MB"
echo "    Total Disk Size = ${DiskSizeMB}MB"
echo "Swap Partition Size = ${SwapSizeMB}MB"
echo "Boot Partition Size = ${BootSizeMB}MB"
echo "Root Partition Size = ${RootSizeMB}MB"
echo "  Minimum Disk Size = ${MinimumSizeMB}MB"

# The drive is too small; exit.
if [ $RootSizeMB -le $MinimumSizeMB ]; then bail "$1 is too small."; fi

# Calculates the start and end positions of the partitions
BootStart=1
BootEnd=$(( $BootStart + $BootSizeMB ))
echo "Boot Drive from ${BootStart} to ${BootEnd}"

RootStart=$(( $BootEnd ))
RootEnd=$(( $RootStart + $RootSizeMB ))
echo "Root Drive from ${RootStart} to ${RootEnd}"

SwapStart=$(( $RootEnd ))
SwapEnd=$(( $SwapStart + $SwapSizeMB ))
echo "Swap Drive from ${SwapStart} to ${SwapEnd}"

# Partition the drive
echo "Partitioning $1..."
parted --script $1 \
	mklabel msdos \
	mkpart primary fat32 ${BootStart}MiB ${BootEnd}MiB \
	mkpart primary ext4 ${RootStart}MiB ${RootEnd}MiB \
	mkpart primary linux-swap ${SwapStart}MiB ${SwapEnd}MiB

BootPartitionPath="${1}1"
BootPartitionName=$(basename $BootPartitionPath)

RootPartitionPath="${1}2"
RootPartitionName=$(basename $RootPartitionPath)

SwapPartitionPath="${1}3"
SwapPartitionName=$(basename $SwapPartitionPath)

echo "Verifying partitions on $1..."
(! lsblk $BootPartitionPath|grep -wq $BootPartitionName)&& bail "Failed to create the boot partition."
(! lsblk $RootPartitionPath|grep -wq $RootPartitionName)&& bail "Failed to create the root partition."
(! lsblk $SwapPartitionPath|grep -wq $SwapPartitionName)&& bail "Failed to create the swap partition."

# Format the drive
echo "Formatting partitions..."
mkfs.vfat -v ${1}1
mkfs.ext4 -v ${1}2
mkswap --verbose ${1}3

# Prepare the mounting directories
[ ! -d "$LFS" ]; mkdir -v $LFS
mount -v ${1}2 $LFS

mkdir -v $LFS/boot
mount -v ${1}1 $LFS/boot
swapon -v ${1}3

# Creating the required folder structure
for i in etc var usr tools; do
	[ ! -d "$LFS/$i" ]; mkdir -v $LFS/$i
done

for i in bin lib sbin; do
	[ ! -d "$LFS/usr/$i" ]; mkdir -v $LFS/usr/$i
done

for i in bin lib sbin; do
	[ ! -d "$LFS/$i" ]; ln -sv usr/$1 $LFS/$i
done

case $(uname -m) in
	x86_64) mkdir -pv $LFS/lib64 ;;
esac

chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
	x86_64) chown -v lfs $LFS/lib64 ;;
esac

cp /root/sources $LFS -Rfv
chown -Rv lfs:lfs $LFS/sources
