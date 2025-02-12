#!/bin/bash

#
##
### Environment and Bash sanity.
##
#
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
		echo "Sorry, you need at least bash 4.x to use ${0}." >&2
		exit 1
fi

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
set -o pipefail # Fail when any command in series of piped commands failed as opposed to only when the last command failed.

umask 0027

# Env vars.
export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if $TMPDIR was not defined.
SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"
INSTALLATION_DIR="$(cd -P "$(dirname "${0}")/.." && pwd)"
LIB_DIR="${INSTALLATION_DIR}/lib"
CFG_DIR="${INSTALLATION_DIR}/etc"
HOSTNAME_SHORT="$(hostname -s)"
ROLE_USER="$(whoami)"
REAL_USER="$(logname 2>/dev/null || echo 'no login name')"

#
##
### Functions.
##
#
if [[ -f "${LIB_DIR}/sharedFunctions.bash" && -r "${LIB_DIR}/sharedFunctions.bash" ]]
then
		# shellcheck source=lib/sharedFunctions.bash
		source "${LIB_DIR}/sharedFunctions.bash"
else
		printf '%s\n' "FATAL: cannot find or cannot access sharedFunctions.bash"
		trap - EXIT
		exit 1
fi

function showHelp() {
		#
		# Display commandline help on STDOUT.
		#
		cat <<EOH
===============================================================================================================
Script to collect QC data from multiple sources and stores it in a ChronQC datatbase. This database is used to generate ChronQC reports.

Usage:

		$(basename "${0}") OPTIONS

Options:

		-h   Show this help.
		-g   Group.
		-d InputDataType dragen|projects|RNAprojects|ogm|darwin|openarray|rawdata|all
		Providing InputDataType to run only a specific data type or "all" to run all types.
		-l   Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Config and dependencies:

		This script needs 3 config files, which must be located in ${CFG_DIR}:
		1. <group>.cfg		for the group specified with -g
		2. <host>.cfg		for this server. E.g.:"${HOSTNAME_SHORT}.cfg"
		3. sharedConfig.cfg	for all groups and all servers.
		In addition the library sharedFunctions.bash is required and this one must be located in ${LIB_DIR}.
===============================================================================================================

EOH
		trap - EXIT
		exit 0
}

function updateOrCreateDatabase() {

	local _db_table="${1}" #SequenceRun
	local _tableFile="${2}" #"${chronqc_tmp}/${_rawdata}.SequenceRun.csv"
	local _runDateInfo="${3}" #"${chronqc_tmp}/${_rawdata}.SequenceRun_run_date_info.csv"
	local _dataLabel="${4}" #"${_sequencer}" 
	local _job_controle_line_base="${5}" #"${_rawdata_job_controle_line_base}"
	local _logtype="${6}"

	if [[ "${_logtype}" == 'ogm' ]] || [[ "${_logtype}" == 'darwin' ]]
	then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Create database for project ${_tableFile}, _logtype= ${_logtype}."
		chronqc database --create -f \
			-o "${CHRONQC_DATABASE_NAME}" \
			"${_tableFile}" \
			--run-date-info "${_runDateInfo}" \
			--db-table "${_db_table}" \
			"${_dataLabel}" -f || {
				log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to create database and import ${_tableFile} with ${_dataLabel} stored to Chronqc database." 
				sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
				echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.failed"
				return
			}
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${FUNCNAME[0]} ${_tableFile} with ${_dataLabel} was stored in Chronqc database."
		sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.failed"
		sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
		echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.finished"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The line ${_job_controle_line_base} added to process.dataToTrendanalysis.finished file."
	else 
		if [[ -e "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" ]]
		then
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "found ${_runDateInfo}. Updating ChronQC database with ${_tableFile}."
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Importing ${_tableFile}"
	
			chronqc database --update --db "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" \
				"${_tableFile}" \
				--db-table "${_db_table}" \
				--run-date-info "${_runDateInfo}" \
				"${_dataLabel}" || {
					log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to import ${_tableFile} with ${_dataLabel} stored to Chronqc database." 
					sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
					echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.failed"
					return
				}
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${FUNCNAME[0]} ${_tableFile} with ${_dataLabel} stored to Chronqc database." 
			sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.failed"
			sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
			echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.finished"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Added ${_job_controle_line_base} to process.${_logtype}_trendanalysis.finished file."
		else
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Create database for project ${_tableFile}."
			chronqc database --create \
				-o "${CHRONQC_DATABASE_NAME}" \
				"${_tableFile}" \
				--run-date-info "${_runDateInfo}" \
				--db-table "${_db_table}" \
				"${_dataLabel}" -f || {
					log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to create database and import ${_tableFile} with ${_dataLabel} stored to Chronqc database." 
					sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
					echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.failed"
					return
				}
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${FUNCNAME[0]} ${_tableFile} with ${_dataLabel} was stored in Chronqc database."
			sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.failed"
			sed -i "/${_job_controle_line_base}/d" "${logs_dir}/process.${_logtype}_trendanalysis.started"
			echo "${_job_controle_line_base}" >> "${logs_dir}/process.${_logtype}_trendanalysis.finished"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The line ${_job_controle_line_base} added to process.dataToTrendanalysis.finished file."
		fi
	fi

}

function processProjectToDB() {
	local _project="${1}"
	local _processprojecttodb_controle_line_base="${2}"
	local _chronqc_projects_dir
	_chronqc_projects_dir="${tmp_trendanalyse_dir}/projects/${_project}/"

	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Removing files from ${chronqc_tmp} ..."
	rm -rf "${chronqc_tmp:-missing}"/*

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "__________processing ${_project}.run_date_info.csv_____________"
	if [[ -e "${_chronqc_projects_dir}/${_project}.run_date_info.csv" ]]
	then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "found ${_chronqc_projects_dir}/${_project}.run_date_info.csv. Updating ChronQC database with ${_project}."
		cp "${_chronqc_projects_dir}/${_project}.run_date_info.csv" "${chronqc_tmp}/${_project}.run_date_info.csv"
		cp "${_chronqc_projects_dir}/multiqc_sources.txt" "${chronqc_tmp}/${_project}.multiqc_sources.txt"
		for multiQC in "${MULTIQC_METRICS_TO_PLOT[@]}"
		do
			local _metrics="${multiQC%:*}"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "using _metrics: ${_metrics}"
			if [[ "${_metrics}" == multiqc_picard_insertSize.txt ]]
			then
				cp "${_chronqc_projects_dir}/${_metrics}" "${chronqc_tmp}/${_project}.${_metrics}"
				awk '{$1=""}1' "${chronqc_tmp}/${_project}.${_metrics}" | awk '{$1=$1}{OFS="\t"}1' > "${chronqc_tmp}/${_project}.1.${_metrics}"
				perl -pe 's|SAMPLE_NAME\t|Sample\t|' "${chronqc_tmp}/${_project}.1.${_metrics}" > "${chronqc_tmp}/${_project}.3.${_metrics}"
				perl -pe 's|SAMPLE\t|SAMPLE_NAME2\t|' "${chronqc_tmp}/${_project}.3.${_metrics}" > "${chronqc_tmp}/${_project}.2.${_metrics}"
			elif [[ "${_metrics}" == multiqc_fastqc.txt ]]
			then
				cp "${_chronqc_projects_dir}/${_metrics}" "${chronqc_tmp}/${_project}.${_metrics}"
				# This part will make a run_date_info.csv for only the lane information
				echo -e 'Sample,Run,Date' >> "${chronqc_tmp}/${_project}.lane.run_date_info.csv"
				IFS=$'\t' read -ra perLaneSample <<< "$(awk '$1 ~ /.recoded/ {print $1}' "${chronqc_tmp}/${_project}.${_metrics}" | tr '\n' '\t')"

				for laneSample in "${perLaneSample[@]}"
				do
					runDate=$(echo "${laneSample}" | cut -d "_" -f 1)
					echo -e "${laneSample},${_project},${runDate}" >> "${chronqc_tmp}/${_project}.lane.run_date_info.csv"
				done
				#cp "${chronqc_tmp}/${_project}.${_metrics}" "${chronqc_tmp}/${_project}.2.${_metrics}"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "using _metrics: ${_metrics} to create ${_project}.lane.run_date_info.csv"
				echo -e 'Sample\t%GC\ttotal_deduplicated_percentage' >> "${chronqc_tmp}/${_project}.2.${_metrics}"
				awk -v FS="\t" -v OFS='\t' -v header="Sample,%GC,total_deduplicated_percentage" 'FNR==1{split(header,h,/,/);for(i=1; i in h; i++){for(j=1; j<=NF; j++){if(tolower(h[i])==tolower($j)){ d[i]=j; break }}}next}{for(i=1; i in h; i++)printf("%s%s",i>1 ? OFS:"",  i in d ?$(d[i]):"");print "";}' "${chronqc_tmp}/${_project}.${_metrics}" >> "${chronqc_tmp}/${_project}.2.${_metrics}"
			else
				cp "${_chronqc_projects_dir}/${_metrics}" "${chronqc_tmp}/${_project}.${_metrics}"
				perl -pe 's|SAMPLE\t|SAMPLE_NAME2\t|' "${chronqc_tmp}/${_project}.${_metrics}" > "${chronqc_tmp}/${_project}.2.${_metrics}"
			fi
		done
		#
		# Rename one of the duplicated SAMPLE column names to make it work.
		#
		cp "${chronqc_tmp}/${_project}.run_date_info.csv" "${chronqc_tmp}/${_project}.2.run_date_info.csv"

		#
		# Get all the samples processed with FastQC form the MultiQC multi_source file,
		# because samplenames differ from regular samplesheet at that stage in th epipeline.
		# The Output is converted into standard ChronQC run_date_info.csv format.
		#
		#grep fastqc "${chronqc_tmp}/${_project}.multiqc_sources.txt" | awk -v p="${_project}" '{print $3","p","substr($3,1,6)}' >>"${chronqc_tmp}/${_project}.2.run_date_info.csv"
		awk 'BEGIN{FS=OFS=","} NR>1{cmd = "date -d \"" $3 "\" \"+%d/%m/%Y\"";cmd | getline out; $3=out; close("uuidgen")} 1' "${chronqc_tmp}/${_project}.2.run_date_info.csv" > "${chronqc_tmp}/${_project}.2.run_date_info.csv.tmp"
		awk 'BEGIN{FS=OFS=","} NR>1{cmd = "date -d \"" $3 "\" \"+%d/%m/%Y\"";cmd | getline out; $3=out; close("uuidgen")} 1' "${chronqc_tmp}/${_project}.lane.run_date_info.csv" > "${chronqc_tmp}/${_project}.lane.run_date_info.csv.tmp"

		#
		# Check if the date in the run_date_info.csv file is in correct format, dd/mm/yyyy
		#
		_checkdate=$(awk 'BEGIN{FS=OFS=","} NR==2 {print $3}' "${chronqc_tmp}/${_project}.2.run_date_info.csv.tmp")
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "_checkdate:${_checkdate}"
		mv "${chronqc_tmp}/${_project}.2.run_date_info.csv.tmp" "${chronqc_tmp}/${_project}.2.run_date_info.csv"
		_checkdate=$(awk 'BEGIN{FS=OFS=","} NR==2 {print $3}' "${chronqc_tmp}/${_project}.lane.run_date_info.csv.tmp")
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "_checkdate:${_checkdate}"
		mv "${chronqc_tmp}/${_project}.lane.run_date_info.csv.tmp" "${chronqc_tmp}/${_project}.lane.run_date_info.csv"

		#
		# Get panel information from $_project} based on column 'capturingKit'.
		#
		_panel=$(awk -F "${SAMPLESHEET_SEP}" 'NR==1 { for (i=1; i<=NF; i++) { f[$i] = i}}{if(NR > 1) print $(f["capturingKit"]) }' "${_chronqc_projects_dir}/${_project}.csv" | sort -u | cut -d'/' -f2)
		IFS='_' read -r -a array <<< "${_panel}"
		if [[ "${array[0]}" == *"Exoom"* ]]
		then
			_panel='Exoom'
		else
			_panel="${array[0]}"
		fi
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "PANEL= ${_panel}"
		if [[ "${_checkdate}"  =~ [0-9] ]]
		then
			for i in "${MULTIQC_METRICS_TO_PLOT[@]}"
			do
				local _metrics="${i%:*}"
				local _table="${i#*:}"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Importing ${_project}.${_metrics}, and using table ${_table}"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "________________${_metrics}________${_table}_____________"
				if [[ "${_metrics}" == multiqc_fastqc.txt ]]
				then
					updateOrCreateDatabase "${_table}" "${chronqc_tmp}/${_project}.2.${_metrics}" "${chronqc_tmp}/${_project}.lane.run_date_info.csv" "${_panel}" "${_processprojecttodb_controle_line_base}" project
				elif [[ -f "${chronqc_tmp}/${_project}.2.${_metrics}" ]]
				then
					updateOrCreateDatabase "${_table}" "${chronqc_tmp}/${_project}.2.${_metrics}" "${chronqc_tmp}/${_project}.2.run_date_info.csv" "${_panel}" "${_processprojecttodb_controle_line_base}" project
				else
					log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The file ${chronqc_tmp}/${_project}.2.${_metrics} does not exist, so can't be added to the database"
					continue
				fi
			done
		else
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_project}: panel: ${_panel} has date ${_checkdate} this is not fit for chronQC." 
			echo "${_processprojecttodb_controle_line_base}.incorrectDate" >> "${logs_dir}/process.project_trendanalysis.failed"
			return
		fi
	else
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "For project ${_project} no run date info file is present, ${_project} cant be added to the database."
	fi

}

function processRNAProjectToDB {
	local _rnaproject="${1}"
	local _processrnaprojecttodb_controle_line_base="${2}"
	local _chronqc_rnaprojects_dir
	_chronqc_rnaprojects_dir="${tmp_trendanalyse_dir}/RNAprojects/${_rnaproject}/"

	CHRONQC_DATABASE_NAME="${tmp_trendanalyse_dir}/database/"

	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Removing files from ${chronqc_tmp} ..."
	rm -rf "${chronqc_tmp:-missing}"/*

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "__________processing ${_rnaproject}.run_date_info.csv_____________"
	if [[ -e "${_chronqc_rnaprojects_dir}/${_rnaproject}.run_date_info.csv" ]]
	then
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "found ${_chronqc_rnaprojects_dir}/${_rnaproject}.run_date_info.csv. Updating ChronQC database with ${_rnaproject}."
		cp "${_chronqc_rnaprojects_dir}/${_rnaproject}.run_date_info.csv" "${chronqc_tmp}/${_rnaproject}.run_date_info.csv"
		for RNAmultiQC in "${MULTIQC_RNA_METRICS_TO_PLOT[@]}"
		do
	#'multiqc_general_stats.txt:general_stats'
	#'multiqc_star.txt:star'
	#'multiqc_picard_RnaSeqMetrics.txt:RnaSeqMetrics'

			local _rnametrics="${RNAmultiQC%:*}"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "using _rnametrics: ${_rnametrics}"
			if [[ "${_rnametrics}" == multiqc_picard_RnaSeqMetrics.txt ]]
			then
				cp "${_chronqc_rnaprojects_dir}/${_rnametrics}" "${chronqc_tmp}/${_rnaproject}.${_rnametrics}"
				perl -pe 's|SAMPLE\t|SAMPLE_NAME2\t|' "${chronqc_tmp}/${_rnaproject}.${_rnametrics}" > "${chronqc_tmp}/${_rnaproject}.1.${_rnametrics}"
			else
				cp "${_chronqc_rnaprojects_dir}/${_rnametrics}" "${chronqc_tmp}/${_rnaproject}.${_rnametrics}"
			fi
		done
		#
		# Rename one of the duplicated SAMPLE column names to make it work.
		#
		#cp "${chronqc_tmp}/${_rnaproject}.run_date_info.csv" "${chronqc_tmp}/${_project}.2.run_date_info.csv"

		#
		# Get all the samples processed with FastQC form the MultiQC multi_source file,
		# because samplenames differ from regular samplesheet at that stage in th epipeline.
		# The Output is converted into standard ChronQC run_date_info.csv format.
		#
		awk 'BEGIN{FS=OFS=","} NR>1{cmd = "date -d \"" $3 "\" \"+%d/%m/%Y\"";cmd | getline out; $3=out; close("uuidgen")} 1' "${chronqc_tmp}/${_rnaproject}.run_date_info.csv" > "${chronqc_tmp}/${_rnaproject}.2.run_date_info.csv"

		#
		# Check if the date in the run_date_info.csv file is in correct format, dd/mm/yyyy
		#
		_checkdate=$(awk 'BEGIN{FS=OFS=","} NR==2 {print $3}' "${chronqc_tmp}/${_rnaproject}.run_date_info.csv")
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "_checkdate:${_checkdate}"
#		mv "${chronqc_tmp}/${_project}.2.run_date_info.csv.tmp" "${chronqc_tmp}/${_project}.2.run_date_info.csv"

		if [[ "${_checkdate}"  =~ [0-9] ]]
		then
			for i in "${MULTIQC_RNA_METRICS_TO_PLOT[@]}"
			do
				local _rnametrics="${i%:*}"
				local _rnatable="${i#*:}"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Importing ${_rnaproject}.${_rnametrics}, and using table ${_rnatable}"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "________________${_rnametrics}________${_rnatable}_____________"
				if [[ "${_rnametrics}" == multiqc_picard_RnaSeqMetrics.txt ]]
				then
					updateOrCreateDatabase "${_rnatable}" "${chronqc_tmp}/${_rnaproject}.1.${_rnametrics}" "${chronqc_tmp}/${_rnaproject}.2.run_date_info.csv" RNA "${_processrnaprojecttodb_controle_line_base}" RNAproject
				else
					updateOrCreateDatabase "${_rnatable}" "${chronqc_tmp}/${_rnaproject}.${_rnametrics}" "${chronqc_tmp}/${_rnaproject}.2.run_date_info.csv" RNA "${_processrnaprojecttodb_controle_line_base}" RNAproject
				fi
			done
		else
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_rnaproject}: has date ${_checkdate} this is not fit for chronQC." 
			echo "${_processrnaprojecttodb_controle_line_base}.incorrectDate" >> "${logs_dir}/process.RNAproject_trendanalysis.failed"
			return
		fi
	else
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "For project ${_rnaproject} no run date info file is present, ${_rnaproject} cant be added to the database."
	fi

}

function processDarwinToDB() {
	local _runinfo="${1}"
	local _tablefile="${2}"
	local _filetype="${3}"
	local _fileDate="${4}"
	local _darwin_job_controle_line_base="${5}"

	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Removing files from ${chronqc_tmp} ..."
	rm -rf "${chronqc_tmp:-missing}"/*
	
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "local variables generateChronQCOutput:_runinfo=${_runinfo},_tablefile=${_tablefile}, _filetype=${_filetype}, _fileDate=${_fileDate}"
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "starting to fille the trendanalysis database with :${_runinfo} and ${_tablefile}}"

	if [[ "${_filetype}"  == 'ArrayInzetten' ]]
	then
		head -1 "${_runinfo}" > "${chronqc_tmp}/ArrayInzettenLabpassed_runinfo_${_fileDate}.csv"
		head -1 "${_tablefile}" > "${chronqc_tmp}/ArrayInzettenLabpassed_${_fileDate}.csv"
		grep labpassed "${_runinfo}" >> "${chronqc_tmp}/ArrayInzettenLabpassed_runinfo_${_fileDate}.csv"
		grep labpassed "${_tablefile}" >> "${chronqc_tmp}/ArrayInzettenLabpassed_${_fileDate}.csv"

		updateOrCreateDatabase "${_filetype}All" "${_tablefile}" "${_runinfo}" all "${_darwin_job_controle_line_base}" darwin
		updateOrCreateDatabase "${_filetype}Labpassed" "${chronqc_tmp}/ArrayInzettenLabpassed_${_fileDate}.csv" "${chronqc_tmp}/ArrayInzettenLabpassed_runinfo_${_fileDate}.csv" labpassed "${_darwin_job_controle_line_base}" darwin

	elif [[ "${_filetype}" == 'Concentratie' ]]
	then
		# for now the database will be filled with only the concentration information from the Nimbus2000	
		head -1 "${_runinfo}" > "${chronqc_tmp}/ConcentratieNimbus_runinfo_${_fileDate}.csv"
		head -1 "${_tablefile}" > "${chronqc_tmp}/ConcentratieNimbus_${_fileDate}.csv"

		grep Nimbus "${_runinfo}" >> "${chronqc_tmp}/ConcentratieNimbus_runinfo_${_fileDate}.csv"
		grep Nimbus "${_tablefile}" >> "${chronqc_tmp}/ConcentratieNimbus_${_fileDate}.csv"
		
		updateOrCreateDatabase "${_filetype}" "${chronqc_tmp}/ConcentratieNimbus_${_fileDate}.csv" "${chronqc_tmp}/ConcentratieNimbus_runinfo_${_fileDate}.csv" Nimbus "${_darwin_job_controle_line_base}" darwin

		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "database filled with ConcentratieNimbus_${_fileDate}.csv"
	else
		updateOrCreateDatabase "${_filetype}" "${_tablefile}" "${_runinfo}" NGSlab "${_darwin_job_controle_line_base}" darwin
	fi

}

function processOpenArray() {

	local _openarrayproject="${1}"
	local _openarrayprojectdir
	local _openarrayfile="${_openarrayproject}.txt"
	local _chronqc_openarray_dir
	_chronqc_openarray_dir="${tmp_trendanalyse_dir}/openarray/"
	_openarrayprojectdir="${_chronqc_openarray_dir}/${_openarrayproject}/"
	
	rm -rf "${chronqc_tmp:-missing}"/*

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "_openarrayprojectdir is: ${_openarrayprojectdir}."
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "_openarrayproject is: ${_openarrayproject}."
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "_openarrayfile is: ${_openarrayfile}."
	
	if [[ -e "${_openarrayprojectdir}/${_openarrayproject}.txt" ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "processing ${_openarrayfile}"
		dos2unix "${_chronqc_openarray_dir}/${_openarrayproject}/${_openarrayproject}.txt"
	
		project=$(grep '# Study Name : ' "${_openarrayprojectdir}/${_openarrayproject}.txt" | awk 'BEGIN{FS=" "}{print $5}')
		year=$(grep  '# Export Date : ' "${_openarrayprojectdir}/${_openarrayproject}.txt" | awk 'BEGIN{FS=" "}{print $5}' | awk 'BEGIN{FS="/"}{print $3}')
		month=$(grep  '# Export Date : ' "${_openarrayprojectdir}/${_openarrayproject}.txt" | awk 'BEGIN{FS=" "}{print $5}' | awk 'BEGIN{FS="/"}{print $1}')
		day=$(grep  '# Export Date : ' "${_openarrayprojectdir}/${_openarrayproject}.txt" | awk 'BEGIN{FS=" "}{print $5}' | awk 'BEGIN{FS="/"}{print $2}')
	
		date="${day}/${month}/${year}"
	
		#select snps, and flag snps with SD > 80% as PASS.
		awk '/Assay Name/,/Experiment Name/ {
			sub("%$","",$3); {
			if ($3+0 > 75.0 ) {
				print $1"\t"$2"\t"$3"\tPASS"}
			else {
				print $1"\t"$2"\t"$3"\tFAIL" }
				}
			}' "${_openarrayprojectdir}/${_openarrayproject}.txt" > "${_openarrayprojectdir}/${_openarrayproject}.snps.csv"
	
		# remove last two rows, and replace header.
		head -n -2 "${_openarrayprojectdir}/${_openarrayproject}.snps.csv" > "${chronqc_tmp}/${_openarrayproject}.snps.csv.temp" 
		sed '1 s/.*/Sample\tAssay ID\tAssay Call Rate\tQC_PASS/' "${chronqc_tmp}/${_openarrayproject}.snps.csv.temp" > "${_openarrayprojectdir}/${_openarrayproject}.snps.csv"
	
		#create ChronQC snp samplesheet
		echo -e "Sample,Run,Date" > "${_openarrayprojectdir}/${_openarrayproject}.snps.run_date_info.csv"
		tail -n +2 "${_openarrayprojectdir}/${_openarrayproject}.snps.csv" | awk -v project="${project}"  -v date="${date}" '{ print $1","project","date }' >> "${_openarrayprojectdir}/${_openarrayproject}.snps.run_date_info.csv"
	
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "generated ${_openarrayprojectdir}/${_openarrayproject}.snps.run_date_info.csv"
	
		#create project.run.csv
		awk '/Experiment Name/,/Sample ID/' "${_openarrayprojectdir}/${_openarrayproject}.txt" > "${chronqc_tmp}/${_openarrayproject}.run.csv.temp"
		head -n -2 "${chronqc_tmp}/${_openarrayproject}.run.csv.temp" > "${_openarrayprojectdir}/${_openarrayproject}.run.csv"
		perl -pi -e 's|Experiment Name|Sample|' "${_openarrayprojectdir}/${_openarrayproject}.run.csv"
		perl -pi -e 's|\%||g' "${_openarrayprojectdir}/${_openarrayproject}.run.csv"
		sed "2s/\.*[^ \t]*/${project}/" "${_openarrayprojectdir}/${_openarrayproject}.run.csv" > "${chronqc_tmp}/${_openarrayproject}.run.csv.temp"
		mv "${chronqc_tmp}/${_openarrayproject}.run.csv.temp" "${_openarrayprojectdir}/${_openarrayproject}.run.csv"
	
		#create ChronQC runSD samplesheet
		echo -e "Sample,Run,Date" > "${_openarrayprojectdir}/${_openarrayproject}.run.run_date_info.csv"
		echo -e "${project},${project},${date}" >> "${_openarrayprojectdir}/${_openarrayproject}.run.run_date_info.csv"
	
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "generated ${_openarrayprojectdir}/${_openarrayproject}.run.run_date_info.csv"
	
		#create project.sample.csv file, and flag samples with SD > 80% as PASS.
		#awk '/Sample ID/,/^$/; sub("%$","",$2) ' "${_filename}" > ${_filename%.*}.samples.csv
		awk '/Sample ID/,/^$/ {
			sub("%$","",$2); {
			if ($2+0 > 75 ) {
				print $1"\t"$2"\tPASS"}
			else {
				print $1"\t"$2"\tFAIL" }
				}
			}' "${_openarrayprojectdir}/${_openarrayproject}.txt" > "${_openarrayprojectdir}/${_openarrayproject}.samples.csv"
	
		# remove last line, and replace header.
		head -n -1 "${_openarrayprojectdir}/${_openarrayproject}.samples.csv" > "${chronqc_tmp}/${_openarrayproject}.samples.csv.temp" 
		sed '1 s/.*/Sample\tSample Call Rate\tQC_PASS/' "${chronqc_tmp}/${_openarrayproject}.samples.csv.temp" > "${_openarrayprojectdir}/${_openarrayproject}.samples.csv"
	
		#create ChronQC sample samplesheet.
		echo -e "Sample,Run,Date" > "${_openarrayprojectdir}/${_openarrayproject}.samples.run_date_info.csv"
		tail -n +2 "${_openarrayprojectdir}/${_openarrayproject}.samples.csv" | awk -v project="${project}"  -v date="${date}" '{ print $1","project","date }' >> "${_openarrayprojectdir}/${_openarrayproject}.samples.run_date_info.csv"
	
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "generated ${_openarrayprojectdir}/${_openarrayproject}.samples.run_date_info.csv"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "__________________function processOpenArray is done___________________"
	else
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Project: ${_openarrayprojectdir}/${_openarrayproject} is not accrording to standard formatting, skipping"
		
	fi
}

function processOGM() {
	
	local _mainfile="${1}"
	local _ogm_job_controle_line_base="${2}"
	local _basmachine="${3}"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "using mainfile: ${_mainfile}"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "ogm log line: ${_ogm_job_controle_line_base}"
	
	declare -a statsFileColumnNames=()
	declare -A statsFileColumnOffsets=()

	IFS=$',' read -r -a statsFileColumnNames <<< "$(head -1 ${_mainfile})"
	
	for (( offset = 0 ; offset < ${#statsFileColumnNames[@]} ; offset++ ))
	do
		columnName="${statsFileColumnNames[${offset}]}"
		statsFileColumnOffsets["${columnName}"]="${offset}"
	done

	chipRunUIDFieldIndex=$((${statsFileColumnOffsets['Chip run uid']} + 1))
	FlowCellFielIndex=$((${statsFileColumnOffsets['Flow cell']} + 1))
	TotalDNAFieldIndex=$((${statsFileColumnOffsets['Total DNA (>= 150Kbp)']} + 1))
	N50FieldIndex=$((${statsFileColumnOffsets['N50 (>= 150Kbp)']} + 1))
	AverageLabelDensityFieldIndex=$((${statsFileColumnOffsets['Average label density (>= 150Kbp)']} + 1))
	MapRateFieldIndex=$((${statsFileColumnOffsets['Map rate (%)']} + 1))
	DNAPerScanFieldIndex=$((${statsFileColumnOffsets['DNA per scan (Gbp)']} + 1))
	LongestMolecuulFieldIndex=$((${statsFileColumnOffsets['Longest molecule (Kbp)']} + 1))
	TimeStampFieldIndex=$((${statsFileColumnOffsets['Timestamp']} + 1))
	
	
	
	echo -e 'Sample,Run,Date' > "OGM-${_basmachine}_runDateInfo_${today}.csv"

	while read line
	do
		dateField=$(echo "${line}" | cut -d ',' -f"${TimeStampFieldIndex}")
			sampleField=$(echo "${line}" | cut -d ',' -f"${chipRunUIDFieldIndex}")
			runField=$(echo "${line}" | cut -d ',' -f"${FlowCellFielIndex}")
			correctDate=$(date -d "${dateField}" '+%d/%m/%Y')
			echo -e "${sampleField},${runField},${correctDate}" >> "OGM-${_basmachine}_runDateInfo_${today}.csv"
	done < <(tail -n +2 "${_mainfile}")

	echo -e 'Sample\tFlow_cell\tTotal_DNA(>=150Kbp)\tN50(>=150Kbp)\tAverage_label_density(>=150Kbp)\tMap_rate(%)\tDNA_per_scan(Gbp)\tLongest_molecule(Kbp)' > "OGM-${_basmachine}_${today}.csv"
	awk -v s="${chipRunUIDFieldIndex}" \
			-v s1="${FlowCellFielIndex}" \
			-v s2="${TotalDNAFieldIndex}" \
			-v s3="${N50FieldIndex}" \
			-v s4="${AverageLabelDensityFieldIndex}" \
			-v s5="${MapRateFieldIndex}" \
			-v s6="${DNAPerScanFieldIndex}" \
			-v s7="${LongestMolecuulFieldIndex}" \
			'BEGIN {FS=","}{OFS="\t"}{if (NR>1){print $s,$s1,$s2,$s3,$s4,$s5,$s6,$s7}}' "${_mainfile}" >> "OGM-${_basmachine}_${today}.csv"

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "starting to update or create database using OGM-${_basmachine}_${today}.csv and OGM-${_basmachine}_runDateInfo_${today}.csv"
	updateOrCreateDatabase bionano "OGM-${_basmachine}_${today}.csv" "OGM-${_basmachine}_runDateInfo_${today}.csv" "${_basmachine}" "${_ogm_job_controle_line_base}" ogm
	mv "OGM-${_basmachine}_${today}.csv" "${tmp_trendanalyse_dir}/ogm/metricsFinished/"
	mv "OGM-${_basmachine}_runDateInfo_${today}.csv" "${tmp_trendanalyse_dir}/ogm/metricsFinished/"
}

function generateReports() {

	local _job_controle_file_base="${1}"
	# shellcheck disable=SC1091
	source "${CHRONQC_TEMPLATE_DIRS}/reports.sh" || { 
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Failed to create all reports from the Chronqc database." \
			2>&1 | tee -a "${_job_controle_file_base}.started"
		mv "${_job_controle_file_base}."{started,failed}
		return
	}

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "ChronQC reports finished."
	mv "${_job_controle_file_base}."{started,finished}
}

#
##
### Main.
##
#

#
# Get commandline arguments.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Parsing commandline arguments ..."
declare group=''
declare InputDataType='all'

while getopts ":g:l:d:h" opt
do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			group="${OPTARG}"
			;;
		d)
			InputDataType="${OPTARG}"
			;;
		l)
			l4b_log_level="${OPTARG^^}"
			l4b_log_level_prio="${l4b_log_levels["${l4b_log_level}"]}"
			;;
		\?)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try $(basename "${0}") -h for help."
			;;
		:)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename "${0}") -h for help."
			;;
		*)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Unhandled option. Try $(basename "${0}") -h for help."
			;;
	esac
done

#
# Check commandline options.
#
if [[ -z "${group:-}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' 'Must specify a group with -g.'
fi
case "${InputDataType}" in 
		dragen|projects|RNAprojects|darwin|openarray|rawdata|ogm|all)
			;;
		*)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Unhandled option. Try $(basename "${0}") -h for help."
			;;
esac
#
# Source config files.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config files ..."
declare -a configFiles=(
	"${CFG_DIR}/${group}.cfg"
	"${CFG_DIR}/${HOSTNAME_SHORT}.cfg"
	"${CFG_DIR}/sharedConfig.cfg"
	"${HOME}/molgenis.cfg"
)
for configFile in "${configFiles[@]}"
do
	if [[ -f "${configFile}" && -r "${configFile}" ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Sourcing config file ${configFile} ..."
		#
		# In some Bash versions the source command does not work properly with process substitution.
		# Therefore we source a first time with process substitution for proper error handling
		# and a second time without just to make sure we can use the content from the sourced files.
		#
		# Disable shellcheck code syntax checking for config files.
		# shellcheck source=/dev/null
		mixed_stdouterr=$(source "${configFile}" 2>&1) || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Cannot source ${configFile}."
		# shellcheck source=/dev/null
		source "${configFile}"  # May seem redundant, but is a mandatory workaround for some Bash versions.
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Config file ${configFile} missing or not accessible."
	fi
done

#
# Write access to prm storage requires data manager account.
#
if [[ "${ROLE_USER}" != "${ATEAMBOTUSER}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "This script must be executed by user ${ATEAMBOTUSER}, but you are ${ROLE_USER} (${REAL_USER})."
fi

#
# Make sure only one copy of this script runs simultaneously
# per data collection we want to copy to prm -> one copy per group.
# Therefore locking must be done after
# * sourcing the file containing the lock function,
# * sourcing config files,
# * and parsing commandline arguments,
# but before doing the actual data trnasfers.
#

lockFile="${TMP_ROOT_DIR}/logs/${SCRIPT_NAME}.lock"
thereShallBeOnlyOne "${lockFile}"
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Successfully got exclusive access to lock file ${lockFile} ..."
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Log files will be written to ${TMP_ROOT_DIR}/logs ..."

# shellcheck disable=SC2029
module load "chronqc/${CHRONQC_VERSION}"

#
## Loops over all rawdata folders and checks if it is already in chronQC database. If not than call function 'processRawdataToDB "${rawdata}" to process this project.'
#

tmp_trendanalyse_dir="${TMP_ROOT_DIR}/trendanalysis/"
logs_dir="${TMP_ROOT_DIR}/logs/trendanalysis/"
mkdir -p "${TMP_ROOT_DIR}/logs/trendanalysis/"
chronqc_tmp="${tmp_trendanalyse_dir}/tmp/"
CHRONQC_DATABASE_NAME="${tmp_trendanalyse_dir}/database/"
today=$(date '+%Y%m%d')

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "rawdata" ]]; then
	readarray -t rawdataArray < <(find "${tmp_trendanalyse_dir}/rawdata/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${tmp_trendanalyse_dir}/rawdata/||")
	if [[ "${#rawdataArray[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/rawdata/."
	else
		for rawdata in "${rawdataArray[@]}"
		do
			tmp_rawdata_dir="${tmp_trendanalyse_dir}/rawdata/${rawdata}/"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Removing files from ${chronqc_tmp} ..."
			rm -rf "${chronqc_tmp:-missing}"/*
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing rawdata ${rawdata} ..."
			echo "Working on ${rawdata}" > "${lockFile}"
			rawdata_job_controle_line_base="${rawdata}.${SCRIPT_NAME}_processRawdatatoDB"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Creating logs line: ${rawdata_job_controle_line_base}"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing run ${rawdata} ..."
			touch "${logs_dir}/process.rawdata_trendanalysis."{finished,failed,started}
			sequencer=$(echo "${rawdata}" | cut -d '_' -f2)
			if grep -Fxq "${rawdata_job_controle_line_base}" "${logs_dir}/process.rawdata_trendanalysis.finished" 
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed batch ${rawdata}."
			elif grep -Fxq "${rawdata_job_controle_line_base}" "${logs_dir}/process.rawdata_trendanalysis.failed"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Batch ${rawdata} is not in the correct format, skipping."
			else
				echo "${rawdata_job_controle_line_base}" >> "${logs_dir}/process.rawdata_trendanalysis.started"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "New batch ${rawdata} will be processed."
				if [[ -e "${tmp_rawdata_dir}/SequenceRun_run_date_info.csv" ]]
				then
					cp "${tmp_rawdata_dir}/SequenceRun_run_date_info.csv" "${chronqc_tmp}/${rawdata}.SequenceRun_run_date_info.csv"
					cp "${tmp_rawdata_dir}/SequenceRun.csv" "${chronqc_tmp}/${rawdata}.SequenceRun.csv"
					updateOrCreateDatabase SequenceRun "${chronqc_tmp}/${rawdata}.SequenceRun.csv" "${chronqc_tmp}/${rawdata}.SequenceRun_run_date_info.csv" "${sequencer}" "${rawdata_job_controle_line_base}" rawdata
				else
					log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${FUNCNAME[0]} for sequence run ${rawdata}, no sequencer statistics were stored "
				fi
			fi
		done
	fi
fi

# Loops over all runs and projects and checks if it is already in chronQC database. If not then call function 'processProjectToDB "${project}" "${run}" to process this project.'

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "projects" ]]; then
	readarray -t projects < <(find "${tmp_trendanalyse_dir}/projects/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${tmp_trendanalyse_dir}/projects/||")
	if [[ "${#projects[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/projects/."
	else
		for project in "${projects[@]}"
		do
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing project ${project} ..."
			echo "Working on ${project}" > "${lockFile}"
			processprojecttodb_controle_line_base="${project}.${SCRIPT_NAME}_processProjectToDB"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Creating logs line: ${processprojecttodb_controle_line_base}"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing run ${project}/ ..."
			touch "${logs_dir}/process.project_trendanalysis."{finished,failed,started}
			if grep -Fxq "${processprojecttodb_controle_line_base}" "${logs_dir}/process.project_trendanalysis.finished"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed project ${project}."
			elif grep -Fxq "${processprojecttodb_controle_line_base}" "${logs_dir}/process.project_trendanalysis.failed"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping project ${project} is not in the right format."
			else
				echo "${processprojecttodb_controle_line_base}" >> "${logs_dir}/process.project_trendanalysis.started"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "New project ${project} will be processed."
				processProjectToDB "${project}" "${processprojecttodb_controle_line_base}"
			fi
		done
	fi
fi

# Loops over all runs and projects and checks if it is already in chronQC database. If not than call function 'processRNAprojectsToDB "${project}" "${run}" to process this project.'

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "RNAprojects" ]]; then
	readarray -t RNAprojects < <(find "${tmp_trendanalyse_dir}/RNAprojects/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${tmp_trendanalyse_dir}/RNAprojects/||")
	if [[ "${#RNAprojects[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/RNAprojects/."
	else
		for RNAproject in "${RNAprojects[@]}"
		do
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing RNAproject ${RNAproject} ..."
			echo "Working on ${RNAproject}" > "${lockFile}"
			processrnaprojecttodb_controle_line_base="${RNAproject}.${SCRIPT_NAME}_processRNAProjectToDB"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Creating logs line: ${processrnaprojecttodb_controle_line_base}"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing run ${RNAproject}/ ..."
			touch "${logs_dir}/process.RNAproject_trendanalysis."{finished,failed,started}
			if grep -Fxq "${processrnaprojecttodb_controle_line_base}" "${logs_dir}/process.RNAproject_trendanalysis.finished"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed RNAproject ${RNAproject}."
			elif grep -Fxq "${processrnaprojecttodb_controle_line_base}" "${logs_dir}/process.RNAproject_trendanalysis.failed"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "RNAproject ${RNAproject} is not in the correct format, skipping."
			else
				echo "${processrnaprojecttodb_controle_line_base}" >> "${logs_dir}/process.RNAproject_trendanalysis.started"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "New project ${RNAproject} will be processed."
				processRNAProjectToDB "${RNAproject}" "${processrnaprojecttodb_controle_line_base}"
			fi
		done
	fi
fi

# Checks for new Darwin import files. Than calls function 'processDarwinToDB'
# to add the new files to the database

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "darwin" ]]; then
	readarray -t darwindata < <(find "${tmp_trendanalyse_dir}/darwin/" -maxdepth 1 -mindepth 1 -type f -name "*runinfo*" | sed -e "s|^${tmp_trendanalyse_dir}/darwin/||")
	if [[ "${#darwindata[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/darwin/."
	else
		for darwinfile in "${darwindata[@]}"
		do
			runinfoFile=$(basename "${darwinfile}" .csv)
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "files to be processed:${runinfoFile}"
			fileType=$(cut -d '_' -f1 <<< "${runinfoFile}")
			fileDate=$(cut -d '_' -f3 <<< "${runinfoFile}")
			tableFile="${fileType}_${fileDate}.csv"
			darwin_job_controle_line_base="${fileType}_${fileDate}.${SCRIPT_NAME}_processDarwinToDB"
			touch "${logs_dir}/process.darwin_trendanalysis."{finished,failed,started}
			if grep -Fxq "${darwin_job_controle_line_base}" "${logs_dir}/process.darwin_trendanalysis.finished"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed darwin data from ${fileDate}."
			elif grep -Fxq "${darwin_job_controle_line_base}" "${logs_dir}/process.darwin_trendanalysis.failed"
			then 
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${fileDate} is not in the correct format, skipping."
			else
				echo "${darwin_job_controle_line_base}" >> "${logs_dir}/process.darwin_trendanalysis.started"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "New darwin data from ${fileDate} will be processed."
				processDarwinToDB "${tmp_trendanalyse_dir}/darwin/${darwinfile}" "${tmp_trendanalyse_dir}/darwin/${tableFile}" "${fileType}" "${fileDate}" "${darwin_job_controle_line_base}"
			fi
		done
	fi
fi

#
## Checks dragen data, and adds the new files to the database
#

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "dragen" ]]; then
	readarray -t dragendata < <(find "${tmp_trendanalyse_dir}/dragen/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${tmp_trendanalyse_dir}/dragen/||")
	if [[ "${#dragendata[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/dragen/."
	else
		for dragenProject in "${dragendata[@]}"
		do
			runinfoFile="${dragenProject}".Dragen_runinfo.csv
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "files to be processed:${runinfoFile}"
			tableFile="${dragenProject}".Dragen.csv
			dataType=$(echo "${dragenProject}" | cut -d '_' -f2 | cut -d '-' -f2)
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "dataType is ${dataType} for the dragen data."
			dragen_job_controle_line_base="${dragenProject}.${SCRIPT_NAME}_processDragenToDB"
			touch "${logs_dir}/process.dragen_trendanalysis."{finished,failed,started}
			if grep -Fxq "${dragen_job_controle_line_base}" "${logs_dir}/process.dragen_trendanalysis.finished"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed dragen project ${dragenProject}."
			elif grep -Fxq "${dragen_job_controle_line_base}" "${logs_dir}/process.dragen_trendanalysis.failed"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "dragen project ${dragenProject}, is not in the correct format, skipping."
			else
				echo "${dragen_job_controle_line_base}" >> "${logs_dir}/process.dragen_trendanalysis.started"
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "New dragen project ${dragenProject} will be processed."
				if [[ "${dataType}" == 'Exoom' ]]
				then
					updateOrCreateDatabase dragenExoom "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${tableFile}" "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${runinfoFile}" dragenExoom "${dragen_job_controle_line_base}" dragen
				elif [[ "${dataType}" == 'WGS' ]]
				then
					updateOrCreateDatabase dragenWGS "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${tableFile}" "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${runinfoFile}" dragenWGS "${dragen_job_controle_line_base}" dragen
				elif [[ "${dataType}" == 'sWGS' ]]
				then
					updateOrCreateDatabase dragenSWGS "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${tableFile}" "${tmp_trendanalyse_dir}/dragen/${dragenProject}/${runinfoFile}" dragenSWGS "${dragen_job_controle_line_base}" dragen
				else
					log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Exoom, WGS and sWGS datatypes are processed, there is room for more types."
				fi
			fi
		done
	fi
fi

#
## Checks openarray data, and adds the new files to the database
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Starting on ${tmp_trendanalyse_dir}/openarray/"
if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "openarray" ]]; then
	readarray -t openarraydata < <(find "${tmp_trendanalyse_dir}/openarray/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${tmp_trendanalyse_dir}/openarray/||")
	if [[ "${#openarraydata[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/openarraydata/."
	else
		for openarrayProject in "${openarraydata[@]}"
		do
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Checking project ${openarrayProject}/."
			openarray_job_controle_line_base="${openarrayProject}.${SCRIPT_NAME}_processOpenarrayToDB"
			touch "${logs_dir}/process.openarray_trendanalysis."{finished,failed,started}
			if grep -Fxq "${openarray_job_controle_line_base}" "${logs_dir}/process.openarray_trendanalysis.finished"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed openarray project ${openarrayProject}."
			elif grep -Fxq "${openarray_job_controle_line_base}" "${logs_dir}/process.openarray_trendanalysis.failed"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping project ${openarrayProject} does not match standard formatting"
			else
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "starting with project ${openarrayProject} found @ ${tmp_trendanalyse_dir}/openarraydata/."
				processOpenArray "${openarrayProject}"
				updateOrCreateDatabase run "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.run.csv" "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.run.run_date_info.csv" openarray "${openarray_job_controle_line_base}" openarray
				updateOrCreateDatabase samples "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.samples.csv" "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.samples.run_date_info.csv" openarray "${openarray_job_controle_line_base}" openarray
				updateOrCreateDatabase snps "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.snps.csv" "${tmp_trendanalyse_dir}/openarray/${openarrayProject}/${openarrayProject}.snps.run_date_info.csv" openarray "${openarray_job_controle_line_base}" openarray
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "done updating the database with ${openarrayProject}"
			fi
		done
	fi
fi

if [[ "${InputDataType}" == "all" ]] || [[ "${InputDataType}" == "ogm" ]]; then
	readarray -t ogmdata < <(find "${tmp_trendanalyse_dir}/ogm/metricsInput/" -maxdepth 1 -mindepth 1 -type f -name "bas*" | sed -e "s|^${tmp_trendanalyse_dir}/ogm/metricsInput/||")
	if [[ "${#ogmdata[@]:-0}" -eq '0' ]]
	then
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME:-main}" '0' "No projects found @ ${tmp_trendanalyse_dir}/ogm/metricsInput/."
	else
		for ogmcsvfile in "${ogmdata[@]}"
		do
			ogmfilename=$(basename "${ogmcsvfile}" .csv)
			ogmfile="${tmp_trendanalyse_dir}/ogm/metricsInput/${ogmcsvfile}"
			basmachine=$(echo "${ogmfilename}" | cut -d '.' -f1)
			mainfile="${tmp_trendanalyse_dir}/ogm/mainMetrics-${basmachine}.csv"
			touch "${mainfile}"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "starting on ogmcsvfile ${ogmcsvfile}."
			
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "basmachine: ${basmachine}"
			ogm_job_controle_line_base="${ogmfilename}.${SCRIPT_NAME}_processOgmMainFile"
			touch "${logs_dir}/process.ogm_trendanalysis."{finished,failed,started}
			if grep -Fxq "${ogm_job_controle_line_base}" "${logs_dir}/process.ogm_trendanalysis.finished"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed ogm file ${ogmfilename}."
			else
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "adding ${ogmfilename} to ${mainfile}."
				tail -n +2 "${mainfile}" > "${mainfile}.tmp"
				tail -n +2 "${ogmfile}" > "${ogmfile}.tmp"
				metricsfiletoday="${tmp_trendanalyse_dir}/ogm/metricsFile_${today}.csv"
				mainHeader=$(head -1 "${ogmfile}")
				echo -e "${mainHeader}" > "${metricsfiletoday}"
				sort -u "${mainfile}.tmp" "${ogmfile}.tmp" >> "${metricsfiletoday}"
				rm "${mainfile}"
				rm "${mainfile}.tmp"
				rm "${ogmfile}.tmp"
				cp "${metricsfiletoday}" "${mainfile}"
				mv "${metricsfiletoday}" "${tmp_trendanalyse_dir}/ogm/metricsFinished/"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "done creating new ${mainfile} added ${ogmfile}"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "added log line: ${ogm_job_controle_line_base} to ${logs_dir}/process.ogm_trendanalysis.finished"
				sed -i "/${ogm_job_controle_line_base}/d" "${logs_dir}/process.ogm_trendanalysis.failed"
				sed -i "/${ogm_job_controle_line_base}/d" "${logs_dir}/process.ogm_trendanalysis.started"
				echo "${ogm_job_controle_line_base}" >> "${logs_dir}/process.ogm_trendanalysis.finished"
			fi
		done
		update_db_ogm_controle_line_base="${today}.${SCRIPT_NAME}_processOgmToDB"
		
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "looping trough ${mainfile}."

		for mainbasfile in "${mainfile}"
		do
			baslabel=$(basename "${mainfile}" .csv | cut -d '-' -f2)
			if grep -Fxq "${update_db_ogm_controle_line_base}" "${logs_dir}/process.ogm_trendanalysis.finished"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already updated the database with the ogm data from ${baslabel} on ${today}."
			else
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Starting on ogm file ${mainbasfile}, adding it to the database."
				processOGM "${mainbasfile}" "${update_db_ogm_controle_line_base}" "${baslabel}" 
			fi
		done
	fi
fi

chronqc_tmp="${tmp_trendanalyse_dir}/tmp/"
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "cleanup ${chronqc_tmp}* ..."
rm -rf "${chronqc_tmp:-missing}"/*

#
## Function for generating a list of ChronQC plots.
#

job_controle_file_base="${logs_dir}/generate_plots.${today}_${SCRIPT_NAME}"

if [[ -e "${job_controle_file_base}.finished" ]]
then
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already generated plots on ${today}."
else
	touch "${job_controle_file_base}.started"
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "New trendanalysis plots will be generated on ${today}."
	generateReports "${job_controle_file_base}"
fi

trap - EXIT
exit 0
