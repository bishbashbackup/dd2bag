#!/bin/bash

# Script created 18/04/2024 7:26


# Sets up aip variable based on stdin
aip="$1"

# Checks if /mnt/dd2bag exists and is empty
if [ -d "/mnt/dd2bag" ]; then
    if [ "$(ls -A /mnt/dd2bag)" ]; then
        echo "Error: The mountpoint /mnt/dd2bag is not empty. Exiting."
        exit 1
    else
        echo "/mnt/dd2bag exists but is empty. Proceeding."
    fi
else
    read -p "/mnt/dd2bag does not exist. Would you like to create and use it? (y/n): " choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        mkdir -p /mnt/dd2bag
    else
        echo "Exiting."
        exit 1
    fi
fi

# Function to check and handle errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error occurred during $1. Exiting."
        exit 1
    fi
}

# Function to cleanup after script execution
cleanup() {
    if [ -d $mountpoint ]; then
        sudo umount $mountpoint &> /dev/null
        rmdir $mountpoint
		rm -r $tempdir
    fi
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Create temporary directory for creating the bag
mountpoint="/mnt/dd2bag"
tempdir="$(mktemp -d $(pwd)/temp-XXXXX)"
check_error "making the temp directory"

# Mount CD drive as read-only
sudo mount -o ro /dev/sr0 $mountpoint
check_error "mounting CD drive"

# Create disk image using ddrescue
sudo ddrescue $mountpoint $tempdir/"$aip".dd
check_error "creating disk image"

# Eject the disk
eject /dev/sr0
check_error "ejecting disk"

# Create BagIt folder structure
python3 -m bagit --contact-name $tempdir/"$aip"

# Move disk image into BagIt folder structure
mv /path/to/disk_image.iso /path/to/bagit/data/disk_image.iso
check_error "moving disk image to BagIt folder"

# Mount disk image as read-only
sudo mount -o ro,loop /path/to/bagit/data/disk_image.iso /mnt/disk_image
check_error "mounting disk image"

# Check disk image for viruses using clamscan
clamscan -r /mnt/disk_image
check_error "scanning disk image with clamscan"

# Use DROID to create a list of all files on the disk
droid -R /mnt/disk_image > /path/to/bagit/metadata/file_list.txt
check_error "creating file list with DROID"

# Move final reports to top level of BagIt structure
mv /path/to/bagit/metadata/file_list.txt /path/to/bagit/
mv /var/log/clamav/clamscan.log /path/to/bagit/

# Unmount disk image and CD drive
sudo umount /mnt/disk_image
sudo umount /mnt/dd2bag
check_error "unmounting disk image and CD drive"

echo "Process completed successfully."
