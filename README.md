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

Run by the umcg-gd-ateambot on TMP, `trendAnalyse.sh` will process each datatype to make it fit for the SQLite database. `/groups/${GROUP}/${TMP}/trendanalysis/${dataType}`
Basically you need a runDateInfo file and a table file. 
The runDateInfo.csv file contains a table with the sample name, project and date, and is comma separated.
The table.csv file will contains the sample name and QC data separated by tabs.

Using ChronQC in the script trendAnalyse.sh, the database will be filled with all the different datatypes, or it will add new projects to an existing database.
When a project or other type of run is added to the database, a line is added to a log file containing the project or data type. 
These log files are in `/groups/${GROUP}/${TMP}/logs/trendanalysis/`.

Then, in the trendAnalyse.sh script, the file templates/reports.sh is sourced.
In this file the commands are noted so you can generate the report files you like for the data types you want.
In the command to generate the reports a json file is needed. These are also in the /templates/ folder in the Trendanalysis repo.
In these json files you can note which type of graphs you want to see in the report, which is in html file format.

## step 3: copyTrendAnalysisDataToPrm.sh

The `copyTrendAnalysisDataToPrm.sh` copies all the reports back to PRM, where the diagnostics can take a look at the QC data over time.


## Important
When creating a new database, a new inhouse NGS project (generated with NGS_DNA-4.2.2 or newer) must be added first, because the newer data contains different columns in comparison to data from older versions. 
When old data is added first the newer data cannot be added to the database.




