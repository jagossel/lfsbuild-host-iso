#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 1 ] || bail "Drive device path required."

# Define the minimum disk size
MinimumSizeMB=10240

# Calculate Drive Space Usages
DiskSize=$(lsblk $1 --bytes --json|jq .blockdevices[0].size)
DiskSizeMB=$(( ($DiskSize / 1024 / 1024) - 2 ))

# Let the user know about the sizes that was calcualted out
echo "  Total Disk Size = ${DiskSizeMB}MB"
echo "Minimum Disk Size = ${MinimumSizeMB}MB"

# The drive is too small; exit.
if [ $DiskSizeMB -le $MinimumSizeMB ]; then bail "$1 is too small."; fi

# Partition the drive
echo "Partitioning $1..."
parted --script $1 \
	mklabel msdos \
	mkpart primary fat32 1MiB ${DiskSizeMB}MiB

# Format the drive
echo "Formatting partition..."
mkfs.vfat -v ${1}1

# Prepare the mounting directories
if [ ! -d "/mnt/lfs_src" ]; then mkdir -v /mnt/lfs_src; fi
mount -v ${1}1 /mnt/lfs_src
