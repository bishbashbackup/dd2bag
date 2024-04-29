#!/bin/bash

# Script created 18/04/2024 7:26

VERSION="0.3"
SCRIPTNAME="dd2bag"
SCRIPTDIR="$(dirname ${0})"
DATE="$(date +%m-%d-%Y-%T)"
count=1


_usage() { 
	echo "script usage: ${SCRIPTDIR}/${SCRIPTNAME}.sh [-h]" 
}

_help(){
	cat <<EOF
${SCRIPTNAME}

Usage: dd2bag [options] <AIP> <target> 

<AIP> = The identifier you are giving to the bag that will be created containing disk images. This string can only contain alphanumeric characters, periods, hyphens and underscores.

<target> = This is a folderpath where the bag will be created. This is optional. If a folderpath isn't given then it will default to the present working directory.

Examples: dd2bag 12345 '/home/bishbashbackup/Documents'
          dd2bag -m package23 '/home/bishbashbackup/Documents'
          dd2bag -mp -l disk1 package23 '/home/bishbashbackup/Documents'

Creates a disk image and then packages in a bagit format

The default disk drive is set to: "/dev/sr0". If yours is different, this can be changed in the config.txt file.

Options:
 -m, --multidisk		Enables prompt to image more than one disk
 -p, --premis			Generates a simple PREMIS XML file at top level of bagit directory
 -l, --label			Adds information to "originalName" element in PREMIS XML output.

EOF
}

# Transforms long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    '--help')			set -- "$@" '-h'   ;;
    '--multidisk')		set -- "$@" '-m'   ;;
    '--premis')			set -- "$@" '-p'   ;;
    '--label')			set -- "$@" '-l'   ;;
    *)				set -- "$@" "$arg" ;;
  esac
done

# Default behavior
multidisk=false
premis=false
labeller=false

# Parse short options
OPTIND=1
while getopts "hmpl" opt ; do
	case "$opt" in
		'h') _help ; exit 0 ;;
		'm') multidisk=true ;;
		'p') premis=true ;;
		'l') labeller=true ;;
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

# Function to check and handle disk imaging errors
_check_disk_error() {
    if [ $? -ne 0 ]; then
        echo "Error occurred during disk imaging of ${AIP}_${count}.dd. Continuing, but this may need further passes with ddrescue."
    fi
}

# Function to create disk images
_disk-image() {
	# Check if the disk is present using blkid
	while true; do
		if blkid /dev/sr0 &>/dev/null; then
			ddrescuelogs="$tempdir/$AIP/${AIP}_${count}_ddrescuelogs"
			mkdir -p "$ddrescuelogs"
			ddrescue -d -r3 --log-events="$ddrescuelogs"/eventlog.txt --log-rates="$ddrescuelogs"/ratelog.txt --log-reads="$ddrescuelogs"/readlog.txt $DRIVE "$tempdir"/"$AIP"/"$AIP"_"$count".dd "$ddrescuelogs"/mapfile.txt
			_check_disk_error
#			touch "$tempdir"/"$AIP"/"$AIP"_"$count".txt
#			echo "this is content" > "$tempdir"/"$AIP"/"$AIP"_"$count".txt
			echo "Created disk image $count"
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
#		eject
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

_update_tag() {
    local file_path="$1"
	local sha256=$(sha256sum "$file_path" | awk '{print $1}')
	local sha512=$(sha512sum "$file_path" | awk '{print $1}')
	local filename=$(basename "$file_path")
	echo "$sha256 $filename" >> $tempdir/"$AIP"/tagmanifest-sha256.txt
	_check_error "Updating sha256 tag"
	echo "$sha512 $filename" >> $tempdir/"$AIP"/tagmanifest-sha512.txt
	_check_error "Updating sha512 tag"
}

# Function to cleanup after script execution
_cleanup() {
    if [ -d "$tempdir" ]; then
        rm -r "$tempdir"
    fi
}

# Trap for cleanup on script exit
trap _cleanup EXIT


# Create temporary directory for creating the bag
tempdir=$(mktemp -d "$target/dd2bag_XXXX")
_check_error "making the temp directory"

# Placeholders if PREMIS XML is generated
tempxml="$(mktemp -p "${tempdir}" temp_XXXXX.xml)"
premisxml="$(mktemp -p "${tempdir}" premis_XXXXX.xml)"


echo '<?xml version="1.0" encoding="UTF-8"?>' >> "$tempxml"
echo "<data>" >> "$tempxml"

# Make subdirectory for disk image
mkdir "$tempdir"/"$AIP"

# Create disk image using ddrescue, with loop for imaging multiple disks
_disk-image
_check_error "disk imaging"
if [[ "$multidisk" == true ]]; then
	_multi-image
	_check_error "multidisk imaging"
fi

echo "Disk Imaging complete! You can remove the disk."

# Optional element for creating PREMIS XML

if [[ "$premis" == true ]]; then
	
	eventid=$(uuidgen)
	agentxml+="
		<agent>
			<agentname>ddrescue</agentname>
		</agent>"
	eventxml+="
		<event>
			<eventid>$eventid</eventid>
			<eventdate>$(date -Ins)</eventdate>
		</event>"
	
	for file in $(find "$tempdir"/"$AIP" -type f); do
		extension="${file##*.}"
		AIPbase=$(basename "$file")
		folderpath="${file%/*}"
		AIPdir=$(basename "$folderpath")	
		
		if [[ -f "$file"  ]] && [[ "$extension" == "dd" ]]; then
			if  [[ "$labeller" == true ]]; then
				read -p "Enter disk label for $file or leave blank: " label
			fi
				
			objectxml+="
			<file>
				<objectid>"$AIPbase"</objectid>
				<fixity>$(sha256sum "$file" | awk '{print $1}')</fixity>
				<size>$(stat -c %s "$file")</size>
				<format>linux dd raw disk image</format>
				<label>"$label"</label>
			</file>"
		elif [[ -f "$file"  ]] && [[ "$extension" == "txt" ]]; then
			IFS='_' read -r AIP counter ext <<< "$AIPdir"
			objectxml+="
			<file>
				<objectid>"$AIPdir"/"$AIPbase"</objectid>
				<fixity>$(sha256sum "$file" | awk '{print $1}')</fixity>
				<size>$(stat -c %s "$file")</size>
				<format>ddrescue log file</format>
				<reltype>reference</reltype>
				<relsubtype>documents</relsubtype>
				<linkedobjecttype>local</linkedobjecttype>
				<linkedobjectvalue>"${AIP}"_"${counter}".dd</linkedobjectvalue>
				<linkedeventtype>imaging</linkedeventtype>
				<linkedeventvalue>"$eventid"</linkedeventvalue>
				
			</file>"
			
		fi   
	done	

	echo -e "$objectxml" >> $tempxml 
	echo -e "$agentxml" >> $tempxml 
	echo -e "$eventxml" >> $tempxml 
	echo -e "</data>" >> "$tempxml"

	xsltproc "$SCRIPTDIR"/resources/dd2premis.xsl $tempxml > $premisxml

	_check_error "generating premis xml"

fi

echo "Tranferring to bagit structure..."
		
# Create Bagit folder structure
python3 -m bagit --quiet "$tempdir"/"$AIP"
_check_error "Creating Bagit Structure"

# Move Premis XML file to the top level of bagit structure and update tags
mv $premisxml "$tempdir"/"$AIP"/premis.xml
_update_tag "$tempdir"/"$AIP"/premis.xml

# Move Bagit out of temp directory
mv "$tempdir"/"$AIP" $target

echo "Bagging complete!"
