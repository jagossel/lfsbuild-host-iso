#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 1 ] || bail "Drive device path required."

export LFS_SRC=/mnt/lfs_src

ScriptRootPath=$( dirname "$( readlink -f $0 )" )

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

SourcePartitionPath="${1}1"
SourcePartitionName=$(basename $SourcePartitionPath)

echo "Verifying partition on $1..."
(! lsblk $SourcePartitionPath|grep -wq $SourcePartitionName)&& bail "Failed to create the source partition."

# Format the drive
echo "Formatting source partition..."
mkfs.vfat -v ${1}1

# Prepare the mounting directories
if [ ! -d "$LFS_SRC" ]; then mkdir -v $LFS_SRC; fi
mount -v ${1}1 $LFS_SRC

PackageSourcePath="$ScriptRootPath/package-source.csv"
if [ ! -f "$PackageSourcePath" ]; then
	bail "Cannot find the packages source data, $PackageSourcePath."
fi

tail -n +2 $PackageSourcePath | while IFS="," read -r PackageName PackageVersion PackageSourceUrl PackageSourceMd5Hash
do
	PackageFileName=$(basename $PackageSourceUrl)
	PackagePath="$LFS_SRC/$PackageFileName"
	echo "Downloading $PackageName ($PackageVersion) from $PackageSourceUrl to $PackagePath..."
	wget --output-document=$PackagePath $PackageSourceUrl
	echo "Verifying $PackageName with $PackageSourceMd5Hash..."
	HashCheck=$(md5sum $PackagePath | grep -Po [0-9a-f]{32} )
	if [ "$PackageSourceMd5Hash" != "$HashCheck" ]; then
		bail "$PackageName is not valid, expected $PackageSourceMd5Hash), but got $HashCheck."
	fi
done
