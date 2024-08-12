#!/bin/bash

#
#	GMOD Legacy Filesystem Addon FastDL Parser
#	(or LegacyParser as a short name)
#
#	Is a script thats meant to help generate a fastdl script for servers that still use legacy addons
#	Legacy filesystem addons are NOT meant to be a replacement for workshop, however some servers
#	have private addons or just modified addons that use this feature as they prefer to not post
#	their content on the workshop, this script allows an easy way to create the lua file required
#	to query the assets needed from those addons.
#

#The script was originally based off of a piece of code that allowed directory recursion in StackOverflow

#
#	CONFIGUATION
#

readonly LuaFilename="FastDL.lua"

#
#	VARIABLES
#

# Colourise the output
readonly RED='\033[0;31m'        # Red
readonly GRE='\033[0;32m'        # Green
readonly YEL='\033[1;33m'        # Yellow
readonly NCL='\033[0m'           # No Color

FileCount=0 # INT
OrgDirDepth=0 # INT
SanitizedPath="" # STRING

#PARAM VARIABLES
bQuiet=0 # BOOL

#TEMP VARIABLES
CurAddonDir="" # STRING
bNeedsCommentHeader=0 # BOOL

#CONSTANTS
readonly MaxEntryCount=8192
LUALOC="$PWD/$LuaFilename"
ORGPWD="$PWD"

#
#	SIGNAL TRAPS
#

#A signal trap to tell the user that the lua file generated IS incomplete
TRAP_sigint()
{
	echo
	echo -e "${RED}The process has been interrupted! The .lua file will be incomplete!${NCL}"
	exit 1
}

#
#	FUNCTIONS
#

#A function to tell the user what they can do with the script
printhelp()
{
	echo "Usage: ${0} <Addon Directory> [Options...]"
	echo "Options:"
	echo "	-q : Quiet mode, silences the message that show when new entries are added"
	echo "	-s : Stale run, runs the script but doesnt save to the configured file"
	echo "	-h : Help, prints this menu"
}

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
	local filename="" # STRING
	local curcol="" # STRING

	#Filetype check
	isvalidfile "$entry"
	if [ $? -eq 1 ]; then
		filename=$(basename "$entry")

		#Actual GMOD Implementation Here
		FileCount=$(($FileCount+1))

		if [ $FileCount -ge $MaxEntryCount ]; then
			curcol="$YEL"
		fi

		if [ $bNeedsCommentHeader -eq 1 ]; then
			bNeedsCommentHeader=0

			#Write the current addon header IF NEEDED
			echo >> ${LUALOC}
			echo "		-- $CurAddonDir" >> ${LUALOC}
		fi

		[[ $bQuiet -eq 0 ]] && echo -e " >> Listing Entry $curcol#${FileCount}$NCL '$SanitizedPath/$filename'..."
		printf "	resource.AddSingleFile(\"%s\")\n" "${SanitizedPath:1}/$filename" >> ${LUALOC}
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
			fi

			walk "$entry"
		fi
	done

	SanitizedPath="${SanitizedPath%/*}"
}

# ================
#	MAIN
# ================

#If there is no param passed to the script then report that to the user and exit
if [[ -z "${1}" ]] && [[ -d "${1}" ]]; then
	printhelp
	exit 1
fi

#PARSE PARAMS
for i in $@; do
	if [ $i == "-q" ]; then
		bQuiet=1
	fi

	if [ $i == "-h" ]; then
		printhelp
		exit 0
	fi
done

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

#Timestamp generation
STAMPDATE=$(date +'%m-%d-%Y')
UNIXSTAMP=$(date +'%s')

#Setup the trap functions
trap TRAP_sigint SIGINT


#Capture the current folder depth to attempt discovering folders with
OrgDirDepth=$(echo "${ABS_PATH}" | grep -o "/" | wc -l)

#
#	LUA WRITER ....
#

#Write some comments highlighting the last parse
echo "-- THIS LUA FILE IS AUTOGENERATED BY LegacyParser.sh! ITS NOT RECOMMENDED TO EDIT THIS FILE!" > ${LUALOC}
echo "-- IF YOU WANT TO MAKE CHANGES TO THIS FILE, PLEASE MAKE CHANGES TO THE ADDONS RESPECTIVE" >> ${LUALOC}
echo "-- DIRECTORIES AND ITS ACCOMPANIED FILES RATHER THAN DIRECTLY EDITING THIS FILE!" >> ${LUALOC}
echo "" >> ${LUALOC}
echo "-- Last Parse: $STAMPDATE $UNIXSTAMP" >> ${LUALOC}
echo "" >> ${LUALOC}

#Write the inital block of text for the lua script
echo "if (SERVER) then" >> ${LUALOC}

#Perform the process
walk "${ABS_PATH}"

#End the script by writing the good ol End
echo "end" >> ${LUALOC}

#
#	LUA WRITER END ....
#

echo -e "${GRE}Successfully written ${LuaFilename}${NCL}"

#According to the docs https://wiki.facepunch.com/gmod/resource.AddFile theres a limit of 8192 files before workshop MUST be utilized
echo "Total Entry Count... $FileCount\8192"

if [ $FileCount -ge $MaxEntryCount ]; then
	echo -e "$YEL ... The entry count goes over the 8192 limit! Not everything will be downloadable!${NCL}"
fi
