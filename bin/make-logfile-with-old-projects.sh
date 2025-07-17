#!/bin/bash

set -e
set -u


function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to make "log" files, for instance prm05.copyQCDataToTmp.projects, containing all old projects. 
So copyQCDataToTmp.sh won't copy these "old" projects to tmp. Make sure to put the lof files in the correct location: /groups/umcg-gd/dat0{5/6/7}/trendanalyse/logs/.
This script is not part of the Trendanalysis pipeline, but is convienent when a new database has to be made.

Usage:
	$(basename "${0}") OPTIONS
Options:
	-h	Show this help.
	-g	group.		Which group to process, umcg-gd
	-p	prm			Which prm tp process, prm05/prm06/prm07
	-m	months		Number of months, data older than {x} months will be in the log file 
	-d	datatype	project or rawdata
	-f	datafolder	/projects/ or /rawdata/ngs/

===============================================================================================================
EOH
	trap - EXIT
	exit 0
}

#
##
### Main.
##
#

#
# Get commandline arguments.
#
echo "Parsing commandline arguments..."

declare group=''
declare prm=''
declare months=''
declare datatype=''
declare datafolder=''

while getopts ":g:p:m:d:f:h" opt; do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			group="${OPTARG}"
			;;
		p)
			prm="${OPTARG}"
			;;
		m)
			months="${OPTARG}"
			;;
		d)
			datatype="${OPTARG}"
			;;
		f)
			datafolder="${OPTARG}"
			;;
		*)
			echo "Unhandled option. Try $(basename "${0}") -h for help."
			;;
	esac
done


#
# Check commandline options.
#
if [[ -z "${group:-}" ]]; then
	echo 'Must specify a group with -g.'
	exit 1
fi

if [[ -z "${prm:-}" ]]; then
	echo 'Must specify a prm with -p.'
	exit 1
fi

if [[ -z "${months:-}" ]]; then
	echo 'Must specify a numer of months with -m.'
	exit 1
fi

if [[ -z "${datatype:-}" ]]; then
	echo 'Must specify a datatype with -d.'
	exit 1
fi

if [[ -z "${datafolder:-}" ]]; then
	echo 'Must specify a datafolder with -f.'
	exit 1
fi


# 86400 = 1 day in seconds.
# 2592000 = 30 days ~ 1 month
# 31449600 = 1 year in seconds

folder=$(ls /groups/"${group}/${prm}/${datafolder}/")

for i in "${folder}"
do
	echo "i:${i}"
	dateInSecAnalysisData=$(date -r "${folder}/${i}" +%s)
	echo "dateInSecAnalysisData: ${dateInSecAnalysisData}"
	dateInSecNow=$(date +%s)
	echo "dateInSecNow: ${dateInSecNow}"


	if [[ $(((dateInSecNow - dateInSecAnalysisData) / 2592000)) -gt "${months}" ]]
	then
		echo "de som: $(((dateInSecNow - dateInSecAnalysisData) / 2592000)) -gt ${months}"
		echo "data is ouder dan 2 jaar"
		echo "datum van input:$(date -r "${folder}/${i}")"
		printf "${i}.copyQCDataToTmp.finished\n" >> "${prm}.copyQCDataToTmp.${datatype}"
	else
		echo "data is jonger dan ${months} maanden"
	fi
done

exit 0

