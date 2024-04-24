#!/bin/bash

# Script created 18/04/2024 7:26

VERSION="0.2"
SCRIPTNAME="ddbag"
SCRIPTDIR="$(dirname ${0})"
DATE="$(date +%m-%d-%Y-%T)"
count=1


_usage() { 
	echo "script usage: ${SCRIPTDIR}/${SCRIPTNAME}_${VERSION}.sh [-h]" 
}

_help(){
	cat <<EOF
${SCRIPTNAME}

Usage: ddbag [options] <AIP> <target> 

<AIP> = The identifier you are giving to the bag that will be created containing disk images. This string can only contain alphanumeric characters, periods, hyphens and underscores.

<target> = This is a folderpath where the bag will be created. This is optional. If a folderpath isn't given then it will default to the present working directory.

Examples: ddbag 12345 '/home/bishbashbackup/Documents'
          ddbag -m package23 '/home/bishbashbackup/Documents'

Creates a disk image and then packages in a bagit format

The default disk drive is set to: "/dev/sr0". If yours is different, this can be changed in the config.txt file.

Options:
 -m, --multidisk		enables prompt to image more than one disk
 

EOF
}

# Transforms long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    '--help')			set -- "$@" '-h'   ;;
    '--multidisk')		set -- "$@" '-m'   ;;
    *)					set -- "$@" "$arg" ;;
  esac
done

# Default behavior
multidisk=false 

# Parse short options
OPTIND=1
while getopts "hm" opt ; do
	case "$opt" in
		'h') _help ; exit 0 ;;
		'm') multidisk=true ;;
		'?') _usage >&2; exit 1 ;;
	esac
done
shift "$((OPTIND-1))"



# Load in variable(s) from config.txt
source "$SCRIPTDIR/config.txt"

# Load in variable from first positional parameter
if [[ -n "$1" && "$1" =~ ^[[:alnum:]._-]+$ ]]; then
	AIP="$1"
else
	echo "Invalid Input - AIP identifier can only contain alphanumeric characters, periods, underscores and hyphens"
	exit 1
fi

# Load in variable from second positional parameter (optional)
if [ -n "$2" ]; then
	if [ -d "$2" ]; then
		target="$2"
	else
		echo "Invalid target folder"
		exit 1
	fi
else
	target="$(pwd)"
fi

# Initial checks to see if folder already exists with AIP name in target directory. 
if [ -d "$target/$AIP" ]; then
	echo "Folder named $AIP already exists in target directory."
	exit 1
fi

# Function to check and handle errors
_check_error() {
    if [ $? -ne 0 ]; then
        echo "Error occurred during $1. Exiting."
        exit 1
    fi
}

# Function to create disk images
_disk-image() {
	# Check if the disk is present using blkid
	while true; do
		if blkid /dev/sr0 &>/dev/null; then
			ddrescue -d -r3 $DRIVE $tempdir/"$AIP"/"$AIP"_"$count".dd $tempdir/"$AIP"/"$AIP"_"$count"_ddrescue.log
#			echo "Created disk image $count"
			break
		else
			read -p "Error: Disk not found. Try again? (Answer yes or no): " choice
			if [[ "$choice" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
				echo "Trying again..."
				sleep 3			
			elif [[ "$choice" =~ ^(n|N|no|No|NO)$ ]]; then
				if [ -z "$(ls -A $tempdir/$AIP)" ]; then
					echo "Exiting script"
					exit 0
				else
					break
				fi
			else
				echo "Invalid input. Please enter 'yes' or 'no'."
			fi
		fi
	done
}

# Function to check for multidisk imaging
_multi-image() {
	while true; do
		eject
		echo "Do you want to create another disk image? (Answer yes or no - if yes insert new disk before answering): "
			read choice

		if [[ "$choice" =~ ^(y|Y|yes|Yes|YES)$ ]]; then
			((count++))
			_disk-image
			continue
			
		elif [[ "$choice" =~ ^(n|N|no|No|NO)$ ]]; then
			break
		
		else
			echo "Invalid input. Please enter 'yes' or 'no'."
		fi
	done		
}


# Function to cleanup after script execution
_cleanup() {
    if [ -d $tempdir ]; then
        rm -r $tempdir
    fi
}

# Trap for cleanup on script exit
trap _cleanup EXIT


# Create temporary directory for creating the bag
tempdir=$(mktemp -d "$target/ddbag_XXXX")
_check_error "making the temp directory"

#Make subdirectory for disk image
mkdir $tempdir/"$AIP"

# Create disk image using ddrescue, with loop for imaging multiple disks
_disk-image
_check_error "disk imaging"
if [[ "$multidisk" == true ]]; then
	_multi-image
	_check_error "multidisk imaging"
fi

echo "Disk Imaging complete! You can remove the disk. Tranferring to bag..."
		
# Create BagIt folder structure
python3 -m bagit --quiet $tempdir/"$AIP"
_check_error "Creating Bagit Structure"

# Move Bagity out of temp directory
mv $tempdir/"$AIP" $target

echo "Bagging complete!"
