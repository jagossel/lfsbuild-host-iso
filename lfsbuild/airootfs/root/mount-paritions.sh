#!/bin/bash

bail () {
	echo >&2 "$@"
	exit 1
}

[ "$#" -eq 1 ] || bail "Drive device path required."

if [ ! -d "/mnt/lfs" ]; then mkdir /mnt/lfs; fi
mount ${1}2 /mnt/lfs
mkdir /mnt/lfs/boot
mount ${1}1 /mnt/lfs/boot
swapon ${1}3

export LFS=/mnt/lfs
