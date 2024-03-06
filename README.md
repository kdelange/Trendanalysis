# Trendanalysis
Generates Trendanalysis plots using ChronQC for standard diagnostic techniques. 
See https://chronqc.readthedocs.io/en/latest/ for more information on ChronQC.

## step 1: copyQCDataToTmp.sh

On PRM the different kind of QC data are stored.
- inhouse
	- NGS projects
		- Exoom
		- Targeted
	- sequence runs
- dragen (NGS projects sequenced by genomescan)
	- Exoom
	- WGS
	- sWGS
- darwin (Lab related QC values)
	- Array (this will be changed of the open array)
	- DNA concentrations
	- NGS lab values
	
The `copyQCDataToTmp.sh` checks every PRM (PRM05, PRM06 and PRM07), and copies the QC data to TMP. 
If the script runs on PRM06, the data will be copied to TMP06. Each data type will endup on TMP in their own data folder.
`/groups/${GROUP}/${TMP}/trendanalysis/${dataType}`

On the PRM in the logs folder, for each project or data type a file will be touched, for instance for rawdata: `rawdata.${rawdata}.copyQCDataToTmp.`
So the QC data will only be copied to TMP once.

## step 2: trendAnalyse.sh

On TMP `trendAnalyse.sh` will process each datatype to make it fit for the SQLite database.
Basically you need a runDateInfo file and a table file.
The runDateInfo.csv file contains a table with the sample name, project and data, and is comma seperated.
the table.csv file wil contain also the sample name, and the QC data, and it tab seperated.
Using ChronQC in the script trendAnalyse.sh, the database will be filled with all the different datatypes, or it will add new projects to an existing database.
When a project or other type of run is added to the database, a line is added to a log file containing the project or data type. 
These log files are in `/groups/${GROUP}/${TMP}/logs/trendanalysis/`.

Then, in the trendAnalyse.sh script, the file templates/reports.sh is sourced.
In this file the commands are noted so you can generate the reports files you like, for the data types you want.
In the command to generate the reports a json file is needed. These are also in the /templated/ folder.
In these json files you can note which type of graphs you want to see in the report, which is in html file format.

## step 3: copyTrendAnalysisDataToPrm.sh

The `copyTrendAnalysisDataToPrm.sh` copies all the reports back to PRM, where the diagnostics can take a look at the QC data over time.


## important
When the database is created new again. It is important to know for the inhouse NGS projects to first add a new project, generated with the NGS_DNA 4.2.2, or newer.
And then add all the older projects. The multiQC version in the NGS_DNS-4.2.2 is updated. The QC data generated has different columns, compared to an older version.
If old date was first added to the database, the newer data can't be added because columns are missing. ChronQC can't handle this.




