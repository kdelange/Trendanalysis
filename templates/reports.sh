#
##get the date of today, so the reports are in a directory per date
#
TODAY=$(date '+%Y%m%d')

#
## ngs-pipeline reports
#
singularity exec --env DISPLAY=$DISPLAY --bind /tmp/.X11-unix "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p seqOverview -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" Exoom "${CHRONQC_TEMPLATE_DIRS}/chronqc.seqOverview.json"
singularity exec --env DISPLAY=$DISPLAY --bind /tmp/.X11-unix "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p seqOverview -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" Targeted "${CHRONQC_TEMPLATE_DIRS}/chronqc.seqOverview.json"

#
## Array and Lab  reports
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" NGSlab "${CHRONQC_TEMPLATE_DIRS}/chronqc.NGSlab.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p Concentratie -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" Nimbus "${CHRONQC_TEMPLATE_DIRS}/chronqc.Concentratie.json"

## GSA array is EOL 03-2025
#chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p ArrayInzetten -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" labpassed "${CHRONQC_TEMPLATE_DIRS}/chronqc.ArrayInzetten_labpassed.json"
#chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p ArrayInzetten -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" all "${CHRONQC_TEMPLATE_DIRS}/chronqc.ArrayInzetten_all.json"


#
## Sequence run report, when we have enhough data points to generate boxplots, the chronqc.SequenceRun.json can be used, until then chronqc.SequenceRunNoBoxplots.json will be used.  
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p SequenceRun -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" NB501043 "${CHRONQC_TEMPLATE_DIRS}/chronqc.SequenceRunNoBoxplots.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p SequenceRun -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" NB501043 "${CHRONQC_TEMPLATE_DIRS}/chronqc.SequenceRun.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p SequenceRun -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" NB501093 "${CHRONQC_TEMPLATE_DIRS}/chronqc.SequenceRun.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p SequenceRun -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" NB552735 "${CHRONQC_TEMPLATE_DIRS}/chronqc.SequenceRun.json"

#
## Dragen data reports
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" dragenExoom "${CHRONQC_TEMPLATE_DIRS}/chronqc.dragenExoom.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" dragenWGS "${CHRONQC_TEMPLATE_DIRS}/chronqc.dragenWGS.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" dragensWGS "${CHRONQC_TEMPLATE_DIRS}/chronqc.dragensWGS.json"
#
## RNA data reports
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" RNA "${CHRONQC_TEMPLATE_DIRS}/chronqc.RNAprojects.json"

#
## openarray report
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" openarray "${CHRONQC_TEMPLATE_DIRS}/chronqc.openarray.json"

#
## ogm report
#
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p ogm -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" bas1 "${CHRONQC_TEMPLATE_DIRS}/chronqc.ogm-bas1.json"
singularity exec "${CHRONQC_VERSION}" chronqc plot -o "${CHRONQC_REPORTS_DIRS}/${TODAY}/" -p ogm -f "${CHRONQC_DATABASE_NAME}/chronqc_db/chronqc.stats.sqlite" bas3 "${CHRONQC_TEMPLATE_DIRS}/chronqc.ogm-bas3.json"

