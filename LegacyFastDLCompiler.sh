#!/bin/bash

# (This is mostly a copy of LegacyParser.sh but fine tuned towards compiling a folder of assets instead of scripts)
# This script compiles a specified folder with the required assets generated from the Lua generator

# NOTE: This script does NOT move folders around by itself that setup is different between every
#	    server operator...

# WARNING: This script is even more lackluster than the generator as this is tailored towards my
#		   use more specifically, however it gets the job done. BUT BE CAREFUL WITH THIS SCRIPT STILL!

# TODO: Make this script more user-friendly so server ops shouldn't need to open the script to operate it correctly

#
#	CONFIGURATION
#

#
#	VARIABLES
#

# Colourise the output
readonly RED='\033[0;31m'        # Red
readonly GRE='\033[0;32m'        # Green
readonly YEL='\033[1;33m'        # Yellow
readonly NCL='\033[0m'           # No Color

OrgDirDepth=0 # INT

#TEMP VARIABLES
CurAddonDir="" # STRING
SanitizedPath="" # STRING

#CONSTANTS
ORGPWD="$PWD"

#
#	FUNCTIONS
#

#Checks if the specified string is a valid filetype
#Params: isvalidfile (PATH STRING)
isvalidfile()
{
	if [[ $1 =~ (\.mdl|\.vvd|\.phy|\.vtf|\.vtx|\.vmt|\.wav|\.ttf|\.png|\.bsp|\.ain)$ ]]; then
		return 1
	fi
	return 0
}

file_specification() {
	local filename=$(basename "$entry")

	#Filetype check
	isvalidfile "$entry"
	if [ $? -eq 1 ]; then
		echo "Copying file... ${SanitizedPath}/${foldername}${filename}"
		cp "$entry" "${FASTDL_PATH}/${SanitizedPath}/${foldername}${filename}"

		#If the copy failed then something went wrong
		if [ $? -ne 0 ]; then
			echo -e "${RED}Something went wrong copying the file!"
			exit 1
		fi
	fi
}

walk() {
	local foldername="" # STRING
	local ExpectedValidDepth=$(($OrgDirDepth+1)) # INT

        # If the entry is a file do some operations
        for entry in "$1"/*; do
		[[ -f "$entry" ]] && file_specification
	done

	# If the entry is a directory call walk() == create recursion
        for entry in "$1"/*; do
		if [ -d "$entry" ]; then
			CurDepth=$(echo "$entry" | grep -o "/" | wc -l)

			#Report the current addon directory we are discovering
			if [[ $OrgDirDepth -lt $CurDepth ]] && [[ $ExpectedValidDepth -ge $CurDepth ]]; then
				CurAddonDir=$(basename "$entry")
				echo "Discovering $CurAddonDir"
				bNeedsCommentHeader=1
			fi

			#We can skip the lua folder as thats handled by the server
			if [[ $(basename "$entry") == "lua" ]] && [[ $ExpectedValidDepth -lt $CurDepth ]]; then
				continue
			fi


			bShouldSanitize=0
			if [ $ExpectedValidDepth -lt $CurDepth ]; then
				bShouldSanitize=1
			else
				SanitizedPath=""
			fi

			#If the entry is in a valid directory depth then begin to sanitize the dir name to a relative path
			if [[ $bShouldSanitize -eq 1 ]]; then
				foldername=$(basename "$entry")
				SanitizedPath="$SanitizedPath/$foldername"

				if [ ! -d "${FASTDL_PATH}${SanitizedPath}" ]; then
					echo "Created Directory ${FASTDL_PATH}${SanitizedPath}/"
					mkdir "${FASTDL_PATH}${SanitizedPath}"

					#If something went wrong making the directory that means the last fastdl data is still lingering or other reasons
					if [ $? -ne 0 ]; then
						echo -e "${RED}Something went wrong creating the directory!"
						exit 1
					fi
				fi
			fi

			#RECURSE!!!!!
			walk "$entry"
		fi
	done

	SanitizedPath="${SanitizedPath%/*}"
}

# ================
#	MAIN
# ================

if [ -z $1 ]; then
	echo "Missing addon folders parameter!"
	exit 1
fi

if [ -z $2 ]; then
	echo "Missing destination folder parameter!"
	exit 1
fi

# If the path is empty use the current, otherwise convert relative to absolute; Exec walk()
cd "${1}" && ABS_PATH="${PWD}"

if [ ! $? -eq 0 ]; then
	echo -e "${RED}Failed to set ABS_PATH! Check the directory you're inputting?${NCL}"
	exit 1
fi

#Verify if the current directory IS the addons folder
if [ ! $(basename "$ABS_PATH") == "addons" ]; then
	echo -e "${RED}The selected directory isn't the addons directory!${NCL}"
	exit 1
fi

#Reset the current directory position to where the script executed at as we need to test for one more dir
cd "${ORGPWD}"

#Check the fastdl param and make sure that the directory does exist first
if [ -d "${2}" ]; then
	#Check for a _FASTDL.mark file to determine if this is a folder we SHOULD wipe
	if [ ! -f "${2}/_FASTDL.mark" ]; then
		#If the marker doesnt exist in this context then that folder wont be tampered with for the sake of safety and to prevent accidental rm's
		echo -e "${RED}${2} doesn't have a _FASTDL.mark, either add the marker or change directories to a valid one that contains the marker!"
		exit 1
	fi

	#If the file contains the marker then delete the folder as we are gonna make a brand new directory
	rm -r "${2}"
fi

#Remake the directory as we've checked the state of it prior to this
mkdir "${2}"
touch "${2}/_FASTDL.mark"

#Get the FastDL directory next
cd "${2}" && FASTDL_PATH="${PWD}"

if [ ! $? -eq 0 ]; then
	echo -e "${RED}Failed to set FASTDL_PATH! Check the directory you're inputting?${NCL}"
	exit 1
fi

echo ${ABS_PATH} ${FASTDL_PATH}
#sleep 3s

#Go back to the addons directory to prepare the copy
cd "${ABS_PATH}"

#Capture the current folder depth to attempt discovering folders with
OrgDirDepth=$(echo "${ABS_PATH}" | grep -o "/" | wc -l)

#
#	COPIER ....
#

#Perform the process
walk "${ABS_PATH}"

#
#	COPIER END ....
#

echo -e "${GRE}Done${NCL}"
