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

function copyQCRawdataToTmp() {

	local _rawdata="${1}"
	local _rawdata_job_controle_file_base="${2}"
	local _line_base="${3}"
	local _prm_rawdata_dir="${4}"
	
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Working on ${_rawdata}"

	if [[ -e "${_prm_rawdata_dir}/${_rawdata}/Info/SequenceRun.csv" ]]
	then
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Sequencerun ${_rawdata} is not yet copied to tmp, start rsyncing.."
		echo "${_line_base}.started" >> "${_rawdata_job_controle_file_base}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_rawdata} found on ${_prm_rawdata_dir}, start rsyncing.."
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_rawdata_dir}/${_rawdata}/Info/SequenceRun"* "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/rawdata/${_rawdata}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync ${_rawdata}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_rawdata_dir}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		
		echo "${_line_base}.failed" >> "${_rawdata_job_controle_file_base}.tmp"
		mv "${_rawdata_job_controle_file_base}.tmp" "${_rawdata_job_controle_file_base}"
			return
			}
		sed "/${_line_base}.failed/d" "${_rawdata_job_controle_file_base}" > "${_rawdata_job_controle_file_base}.tmp"
		sed "/${_line_base}.started/d" "${_rawdata_job_controle_file_base}" > "${_rawdata_job_controle_file_base}.tmp"
		echo "${_line_base}.finished" >> "${_rawdata_job_controle_file_base}.tmp"
		mv "${_rawdata_job_controle_file_base}.tmp" "${_rawdata_job_controle_file_base}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished copying rawdata: ${_rawdata}"

	else
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "For sequencerun ${_rawdata} there is no QC data, nothing to rsync.."
	fi
}

function copyQCProjectdataToTmp() {

	local _project="${1}"
	local _project_job_controle_file_base="${2}"
	local _line_base="${3}"
	local _prm_project_dir="${4}" #"/groups/${group}/${prm_dir}/projects/"
	
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Working on ${_prm_project_dir}/${_project}"
	echo "${_line_base}.started" >> "${_project_job_controle_file_base}"
	# The RNA projects will be copied to ${TMP_ROOT_DIR}/trendanalysis/RNAprojects/
	if [[ -e "${_prm_project_dir}/${_project}/run01/results/multiqc_data/${_project}.run_date_info.csv" && "${_project}" =~ "RNA" ]]
	then
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_project} found on ${_prm_project_dir}, start rsyncing.."
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/multiqc_data/"* "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/RNAprojects/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync QC data of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
			return
			}
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/${_project}.csv" "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/RNAprojects/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync samplesheet of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
			return
			}
		sed "/${_line_base}.failed/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		sed "/${_line_base}.started/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		echo "${_line_base}.finished" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished copying project: ${_project}"
	# The inhouse projects (Exoom, targeted) will be copied to ${TMP_ROOT_DIR}/trendanalysis/projects/
	elif [[ -e "${_prm_project_dir}/${_project}/run01/results/multiqc_data/${_project}.run_date_info.csv" ]]
	then
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_project} found on ${_prm_project_dir}, start rsyncing.."
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/multiqc_data/"* "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/projects/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync QC data of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}/"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
		return
		}
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/${_project}.csv" "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/projects/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync samplesheet of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}/"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
			return
			}
		sed "/${_line_base}.failed/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		sed "/${_line_base}.started/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		echo "${_line_base}.finished" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished copying project: ${_project}"
	# The Dragen project (Exoom, WGS, sWGS) wil be copied to ${TMP_ROOT_DIR}/trendanalysis/dragen/
	elif  [[ -e "${_prm_project_dir}/${_project}/run01/results/qc/statistics/${_project}.Dragen_runinfo.csv" ]]
	then
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Dragen project ${_project} is not yet copied to tmp, start rsyncing.."
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_project} found on ${_prm_project_dir}, start rsyncing.."
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/qc/statistics/"* "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/dragen/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync dragen QC data of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}/"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
			return
			}
		rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_prm_project_dir}/${_project}/run01/results/${_project}.csv" "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/dragen/${_project}/" \
		|| {
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync dragen samplesheet of ${_project}"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_prm_project_dir}/"
		log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
		echo "${_line_base}.failed" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
		return
		}
		sed "/${_line_base}.failed/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		sed "/${_line_base}.started/d" "${_project_job_controle_file_base}" > "${_project_job_controle_file_base}.tmp"
		echo "${_line_base}.finished" >> "${_project_job_controle_file_base}.tmp"
		mv "${_project_job_controle_file_base}.tmp" "${_project_job_controle_file_base}"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished copying project: ${_project}"
	else
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "For project ${_project} there is no QC data, nothing to rsync.."
	fi

}

function copyDarwinQCData() {

	local _runinfofile="${1}"
	local _tablefile="${2}"
	local _filetype="${3}"
	local _filedate="${4}"
	local _darwin_job_controle_file_base="${5}"
	local _line_base="${6}"

	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Copying ${_runinfofile} to tmp, start rsyncing.."
	echo "${_line_base}.started" >> "${_darwin_job_controle_file_base}"
	rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${IMPORT_DIR}/${_filetype}"*"${_filedate}.csv" "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/darwin/" \
	|| {
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync ${_filetype}"*"${_filedate}.csv"
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${IMPORT_DIR}/"
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
	echo "${_line_base}.failed" >> "${_darwin_job_controle_file_base}.tmp"
	mv "${_darwin_job_controle_file_base}.tmp" "${_darwin_job_controle_file_base}"
		return
		}
	sed "/${_line_base}.failed/d" "${_darwin_job_controle_file_base}" > "${_darwin_job_controle_file_base}.tmp"
	sed "/${_line_base}.started/d" "${_darwin_job_controle_file_base}" > "${_darwin_job_controle_file_base}.tmp"
	echo "${_line_base}.finished" >> "${_darwin_job_controle_file_base}.tmp"
	mv "${_darwin_job_controle_file_base}.tmp" "${_darwin_job_controle_file_base}"
	mv "${IMPORT_DIR}/${_filetype}"*"${_filedate}.csv" "${IMPORT_DIR}/archive/"
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished copying Darwin data: ${_filetype}_${_filedate}.csv"

}

function copyOpenarrayQCData() {
	local _qcfile="${1}"
	local _openarraydir="${2}"
	local _import_dir_openarray="${3}"
	local _openarray_job_controle_file_base="${4}"
	local _line_base="${5}"

	local _qcfiledir=$(basename "${_qcfile}" .txt)

	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Copying ${_qcfile} from dir: ${_qcfiledir} to tmp, start rsyncing.."
	echo "${_line_base}.started" >> "${_openarray_job_controle_file_base}"

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "sudo -u ${group}-ateambot rsync ${_qcfile} ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/openarray/${_qcfiledir}/"

	rsync -av --rsync-path="sudo -u ${group}-ateambot rsync" "${_qcfile}" "${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/trendanalysis/openarray/${_qcfiledir}/" \
	|| {
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "Failed to rsync ${_qcfile}."
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    from ${_import_dir_openarray}/${_openarraydir}/"
	log4Bash 'ERROR' "${LINENO}" "${FUNCNAME:-main}" '0' "    to ${DESTINATION_DIAGNOSTICS_CLUSTER}:${TMP_ROOT_DIR}/"
	echo "${_line_base}.failed" >> "${_openarray_job_controle_file_base}.tmp"
	mv "${_openarray_job_controle_file_base}.tmp" "${_openarray_job_controle_file_base}"
	return
	}
	sed "/${_line_base}.failed/d" "${_openarray_job_controle_file_base}" > "${_openarray_job_controle_file_base}.tmp"
	sed "/${_line_base}.started/d" "${_openarray_job_controle_file_base}" > "${_openarray_job_controle_file_base}.tmp"
	echo "${_line_base}.finished" >> "${_openarray_job_controle_file_base}.tmp"
	mv "${_openarray_job_controle_file_base}.tmp" "${_openarray_job_controle_file_base}"
	log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "${_qcfile} is copied to tmp."

}

function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to copy (rsync) QC data from prm to tmp.
NGS project MultiQC data, sequencerun information from rawdata and everything Adlas/Darwin can produce.

Usage:

	$(basename "${0}") OPTIONS

Options:

	-h	Show this help.
	-g	[group]
		Group for which to process data.
	-l	[level]
		Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Config and dependencies:

	This script needs 4 config files, which must be located in ${CFG_DIR}:
		1. <group>.cfg       for the group specified with -g
		2. <this_host>.cfg   for this server. E.g.: "${HOSTNAME_SHORT}.cfg"
		3. <source_host>.cfg for the source server. E.g.: "<hostname>.cfg" (Short name without domain)
		4. sharedConfig.cfg  for all groups and all servers.
	In addition the library sharedFunctions.bash is required and this one must be located in ${LIB_DIR}.
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
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Parsing commandline arguments ..."
declare group=''
while getopts ":g:l:h" opt
do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			group="${OPTARG}"
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

if [[ "${ROLE_USER}" != "${ATEAMBOTUSER}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "This script must be executed by user ${ATEAMBOTUSER}, but you are ${ROLE_USER} (${REAL_USER})."
fi

infoServerLocation="${HOSTNAME_PRM}"
infoLocation="/groups/${group}/${PRM_LFS}/trendanalysis/"
hashedSource="$(printf '%s:%s' "${infoServerLocation}" "${infoLocation}" | md5sum | awk '{print $1}')"
lockFile="/groups/${GROUP}/${DAT_LFS}/trendanalysis/logs/${SCRIPT_NAME}_${hashedSource}.lock"
thereShallBeOnlyOne "${lockFile}"
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Successfully got exclusive access to lock file ${lockFile} ..."
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Log files will be written to ${PRM_ROOT_DIR}/trendanalysis/logs/ ..."


#
## Loops through all rawdata folders and checks if the QC data  is already copied to tmp. If not than call function copyQCRawdataToTmp
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "starting checking the prm's for raw QC data"
mkdir -p "${DAT_ROOT_DIR}/logs/trendanalysis/"

for prm_dir in "${ALL_PRM[@]}"
do
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "looping through ${prm_dir}"


	readarray -t rawdataArray < <(find "/groups/${group}/${prm_dir}/rawdata/ngs/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^/groups/${group}/${prm_dir}/rawdata/ngs/||")

	if [[ "${#rawdataArray[@]}" -eq '0' ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "No rawdata found @ /groups/${group}/${prm_dir}/rawdata/ngs/."
	else
		for rawdata in "${rawdataArray[@]}"
		do
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing rawdata ${rawdata} ..."
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Creating logs folder: /groups/${group}/${prm_dir}/logs/trendanalysis/${rawdata}"
			controlFileBase="${DAT_ROOT_DIR}/logs/trendanalysis/"
			RAWDATA_JOB_CONTROLE_FILE_BASE="${controlFileBase}/${prm_dir}.${SCRIPT_NAME}.rawdata"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing run ${rawdata} ..."
			RAWDATA_JOB_CONTROLE_LINE_BASE="${rawdata}.${SCRIPT_NAME}"
			touch "${RAWDATA_JOB_CONTROLE_FILE_BASE}"
			if grep -Fxq "${RAWDATA_JOB_CONTROLE_LINE_BASE}.finished" "${RAWDATA_JOB_CONTROLE_FILE_BASE}"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed batch ${rawdata}."
				continue
			else
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "starting function copyQCRawdataToTmp for rawdata ${rawdata}."
#				copyQCRawdataToTmp "${rawdata}" "${RAWDATA_JOB_CONTROLE_FILE_BASE}" "${RAWDATA_JOB_CONTROLE_LINE_BASE}" "/groups/${group}/${prm_dir}/rawdata/ngs/"
			fi
		done
	fi
done



# Loops through all project data folders and checks if the QC data  is already copied to tmp. If not than call function copyQCProjectdataToTmp

log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "starting checking the prm's for project QC data"

for prm_dir in "${ALL_PRM[@]}"
do
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "looping through ${prm_dir}"
	readarray -t projectdata < <(find "/groups/${group}/${prm_dir}/projects/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^/groups/${group}/${prm_dir}/projects/||")

	if [[ "${#projectdata[@]}" -eq '0' ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "No projectdata found @ ${PRM_ROOT_DIR}/projects/."
	else
		for project in "${projectdata[@]}"
		do
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing project ${project} ..."
			controlFileBase="${DAT_ROOT_DIR}/logs/trendanalysis/"
			PROJECT_JOB_CONTROLE_FILE_BASE="${controlFileBase}/${prm_dir}.${SCRIPT_NAME}.projects"
			PROJECT_JOB_CONTROLE_LINE_BASE="${project}.${SCRIPT_NAME}"
			touch "${PROJECT_JOB_CONTROLE_FILE_BASE}"
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing run ${project} ..."
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "PROJECT_JOB_CONTROLE_FILE_BASE= ${PROJECT_JOB_CONTROLE_FILE_BASE}"
			log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "PROJECT_JOB_CONTROLE_LINE_BASE= ${PROJECT_JOB_CONTROLE_LINE_BASE}"
			if grep -Fxq "${PROJECT_JOB_CONTROLE_LINE_BASE}.finished" "${PROJECT_JOB_CONTROLE_FILE_BASE}"
			then
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Skipping already processed batch ${project}."
				continue
			else
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "no ${PROJECT_JOB_CONTROLE_LINE_BASE}.finished present, in file ${PROJECT_JOB_CONTROLE_FILE_BASE}, starting rsync QC data for project ${project}."
				copyQCProjectdataToTmp "${project}" "${PROJECT_JOB_CONTROLE_FILE_BASE}" "${PROJECT_JOB_CONTROLE_LINE_BASE}" "/groups/${group}/${prm_dir}/projects/"
			fi
		done
	fi
done


#
## check if darwin left any new files for us on dat05 to copy to tmp05
#

for dat_dir in "${ALL_DAT[@]}"
do
	IMPORT_DIR="/groups/${group}/${dat_dir}/trendanalysis/"

	readarray -t darwindata < <(find "${IMPORT_DIR}/" -maxdepth 1 -mindepth 1 -type f -name "*runinfo*" | sed -e "s|^${IMPORT_DIR}/||")
	
	if [[ "${#darwindata[@]}" -eq '0' ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "no new darwin files present in ${IMPORT_DIR}"
	else
		for darwinfile in "${darwindata[@]}"
		do
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Start proseccing ${darwinfile}"
			runinfoFile=$(basename "${darwinfile}" .csv)
			fileType=$(cut -d '_' -f1 <<< "${runinfoFile}")
			fileDate=$(cut -d '_' -f3 <<< "${runinfoFile}")
			tableFile="${fileType}_${fileDate}.csv"
			runinfoCSV="${runinfoFile}.csv"
			controlFileBase="${DAT_ROOT_DIR}/logs/trendanalysis/"
			DARWIN_JOB_CONTROLE_FILE_BASE="${controlFileBase}/${dat_dir}.${SCRIPT_NAME}.darwin"
			DARWIN_JOB_CONTROLE_LINE_BASE="${fileType}-${fileDate}.${SCRIPT_NAME}"
			if grep -Fxq "${DARWIN_JOB_CONTROLE_LINE_BASE}.finished" "${DARWIN_JOB_CONTROLE_FILE_BASE}"
			then
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${DARWIN_JOB_CONTROLE_LINE_BASE}.finished present"
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${runinfoFile} data is already processed, but there is new data on dat05, check if previous rsync went okay"
			else
				log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "no ${DARWIN_JOB_CONTROLE_LINE_BASE}.finished present, starting rsyncing ${tableFile} and ${runinfoCSV}"
#				copyDarwinQCData "${runinfoCSV}" "${tableFile}" "${fileType}" "${fileDate}" "${DARWIN_JOB_CONTROLE_FILE_BASE}" "${DARWIN_JOB_CONTROLE_LINE_BASE}"
				
			fi
		done
	fi
done

#
## check the openarray folder for new data, /groups/umcg-gap/dat06/openarray/
#

for dat_dir in "${ALL_DAT[@]}"
do
	IMPORT_DIR_OPENARRAY="/groups/${OPARGROUP}/${dat_dir}/openarray/"
	DAT_OPENARRAY_LOGS_DIR="/groups/${group}/${dat_dir}/logs/trendanalysis/"
	
	readarray -t openarraydata < <(find "${IMPORT_DIR_OPENARRAY}/" -maxdepth 1 -mindepth 1 -type d -name "[!.]*" | sed -e "s|^${IMPORT_DIR_OPENARRAY}/||")
	
	if [[ "${#openarraydata[@]}" -eq '0' ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "no new openarray files present in ${IMPORT_DIR_OPENARRAY}"
	else
		for openarraydir in "${openarraydata[@]}"
		do
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "Start processing ${openarraydir}"
			
			QCFile=$(find "${IMPORT_DIR_OPENARRAY}/${openarraydir}/" -maxdepth 1 -mindepth 1 -type f -name "*_QC_Summary.txt")
			if [[ -e "${QCFile}" ]]
			then 
				controlFileBase="${DAT_OPENARRAY_LOGS_DIR}"
				baseQCFile=$(basename "${QCFile}" .txt)
				OPENARRAY_JOB_CONTROLE_FILE_BASE="${controlFileBase}/${dat_dir}.${SCRIPT_NAME}.openarray"
				OPENARRAY_JOB_CONTROLE_LINE_BASE="${baseQCFile}_${SCRIPT_NAME}"
				if grep -Fxq "${OPENARRAY_JOB_CONTROLE_LINE_BASE}.finished" "${OPENARRAY_JOB_CONTROLE_FILE_BASE}"
				then
					log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "${OPENARRAY_JOB_CONTROLE_LINE_BASE}.finished present"
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${QCFile} data is already processed"
				else
					log4Bash 'TRACE' "${LINENO}" "${FUNCNAME:-main}" '0' "no ${OPENARRAY_JOB_CONTROLE_LINE_BASE}.finished present, starting rsyncing ${QCFile}."
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "IMPORT_DIR_OPENARRAY=${IMPORT_DIR_OPENARRAY}"
					log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "openarraydir=${openarraydir}"
#					copyOpenarrayQCData "${QCFile}" "${openarraydir}" "${IMPORT_DIR_OPENARRAY}" "${OPENARRAY_JOB_CONTROLE_FILE_BASE}" "${OPENARRAY_JOB_CONTROLE_LINE_BASE}"
				fi
			else
				log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "QC file for project ${openarraydir} is not available"
			fi
		done
	fi
done

log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' 'Finished!'

trap - EXIT
exit 0

