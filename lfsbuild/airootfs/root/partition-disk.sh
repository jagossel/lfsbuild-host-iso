#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 1 ] || bail "Drive device path required."

MemSize=$(free --bytes|grep Mem|awk -F ' ' '{print $2}')
MemSizeMB=$(( $MemSize / 1024 / 1024 ))

DiskSize=$(lsblk $1 --bytes --json|jq .blockdevices[0].size)
DiskSizeMB=$(( $DiskSize / 1024 / 1024 ))

SwapSizeMB=$(( ($MemSizeMB * 2) - 1 ))
BootSizeMB=512
RootSizeMB=$(( $DiskSizeMB - $SwapSizeMB - $BootSizeMB - 2 ))
MinimumSizeMB=10240

echo "        Memory Size = ${MemSizeMB}MB"
echo "    Total Disk Size = ${DiskSizeMB}MB"
echo "Swap Partition Size = ${SwapSizeMB}MB"
echo "Boot Partition Size = ${BootSizeMB}MB"
echo "Root Partition Size = ${RootSizeMB}MB"
echo "  Minimum Disk Size = ${MinimumSizeMB}MB"

if [ $RootSizeMB -le $MinimumSizeMB ]; then die "$1 is too small."; fi

BootStart=1
BootEnd=$(( $BootStart + $BootSizeMB ))
echo "Boot Drive from ${BootStart} to ${BootEnd}"

RootStart=$(( $BootEnd ))
RootEnd=$(( $RootStart + $RootSizeMB ))
echo "Root Drive from ${RootStart} to ${RootEnd}"

SwapStart=$(( $RootEnd ))
SwapEnd=$(( $SwapStart + $SwapSizeMB ))
echo "Swap Drive from ${SwapStart} to ${SwapEnd}"

echo "Partitioning $1..."
parted --script $1 \
	mklabel msdos \
	mkpart primary fat32 ${BootStart}MiB ${BootEnd}MiB \
	mkpart primary ext4 ${RootStart}MiB ${RootEnd}MiB \
	mkpart primary linux-swap ${SwapStart}MiB ${SwapEnd}MiB

echo "Formatting partitions..."
mkfs.vfat ${1}1
mkfs.ext4 ${1}2
mkswap ${1}3
