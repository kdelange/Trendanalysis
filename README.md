# Trendanalysis
Generates Trendanalysis plots using ChronQC for standard diagnostic techniques. 
See https://chronqc.readthedocs.io/en/latest/ for more information on ChronQC.
For Debugging tips: see the end of this document, the first parts explains how the trendanalysis works.

## step 1: copyQCDataToTmp.sh 
Run by the umcg-gd-ateambot on a chaperone machine, not the dm user. The ateambot user can access also the umcg-gap group

### Data locations
On PRM/DAT the different kind of QC data are stored.

umcg-gd
- NGS projects /groups/umcg-gd/${PRM}/projects/
	- Exoom
	- Targeted
- sequence runs (inhouse rawdata) /groups/umcg-gd/${PRM}/rawdata/ngs/
- DRAGEN (NGS projects sequenced by genomescan) /groups/umcg-gd/prm0*/projects/
	- Exoom
	- WGS
	- sWGS
- RNA projects (sequenced by genomescan, project data generated inhouse) /groups/umcg-gd/${PRM}/projects/
- DARWIN (Lab related QC values) /groups/umcg-gd/dat06/trendanalysis/
	- Array* (this will be changed into the open array early 2025)
	- DNA concentrations
	- NGS lab values

umcg-gap
- openarray /groups/umcg-gap/${DAT}/openarray/

 *The Array data we receive from Darwin, together with other lab results. Thats why it is all together in 1 folder in the umcg-gd group.

The `copyQCDataToTmp.sh` checks every PRM (PRM05, PRM06 and PRM07), and copies the QC data to TMP. 
If the script runs on PRM06, the data will be copied to TMP06. Each data type will end-up on TMP in their own data folder.
`/groups/${GROUP}/${TMP}/trendanalysis/${dataType}`

### Logging
On the DAT0(5,6,7) in the logs/trendanalysis folder, for each data type a file will be touched, for instance for rawdata: `groups/${group}/${DAT}/logs/trendanalysis/${PRM}.copyQCDataToTmp.rawdata`.

If `copyQCDataToTmp.sh` is ran on cf-porch, all the log files will be in DAT06. For each PRM there will be a file, you will have 3 files for ${PRM}.copyQCDataToTmp.rawdata.

In this file, there is a line with `${rawdata}_copyQCDataToTmp_finished`, so the QC data will only be copied to TMP once. 
If you would like to copy the QC data again to TMP, just remove whole file: ${PRM}.copyQCDataToTmp.rawdata, or just the line with your dataset of intrest.

## step 2: trendAnalyse.sh

Run by the umcg-gd-ateambot on TMP, `trendAnalyse.sh` will process each datatype to make it fit for the SQLite database. `/groups/${GROUP}/${TMP}/trendanalysis/${dataType}`
Basically you need a runDateInfo file and a table file. 
The runDateInfo.csv file contains a table with the sample name, project and date, and is comma separated.
The table.csv file will contain also the sample name, and the QC data, and it tab separated.
Using ChronQC in the script trendAnalyse.sh, the database will be filled with all the different datatypes, or it will add new projects to an existing database.
The database is in `/groups/${GROUP}/${TMP}/trendanalysis/database/chronqc_db/chronqc.stats.sqlite`. 
There is 1 database for all data types. Each datatype has it's own table.

You can check the database using SQLite

```bash
ml SQLite 
sqlite3 /groups/${GROUP}/${TMP}/trendanalysis/database/chronqc_db/chronqc.stats.sqlite
.table (see which tables are in the database)
select * from ${table}; (see what kind of data is in the table)
.exit (to exit sqlite)
```

When a project or other type of run is added to the database, a line is added to a log file containing the project or data type. 
These log files are in `/groups/umcg-gd/${TMP}/logs/trendanalysis/`.

If you want to generate the database again, remove the database and the log files.
Run trendAnalyse.sh again, all datatypes are added which are on ${TMP}.
If you want to test with 1 datatype, see https://chronqc.readthedocs.io/en/latest/run_chronqc.html.
You can run chronQC with the runDateInfo file and the table file.
You can play with the different table types. Adjust the .json file you use to generate the plots. The *.json files are in the /template/ folder in the Trendanalysis repo.

Then, in the trendAnalyse.sh script, the file templates/reports.sh is sourced.
In this file the commands are noted so you can generate the report files you like for the data types you want.
In the command to generate the reports a json file is needed. These are also in the /templates/ folder in the Trendanalysis repo.
In these json files you can note which type of graphs you want to see in the report, which is in html file format.

Side note: for instance the inhouse rawdata sequence runs: The data of all sequencers are in 1 table in the database, but a selection is made based on the number of the sequencer. 
Each sequencer has it's own end report. 

## step 3: copyTrendAnalysisDataToPrm.sh

The `copyTrendAnalysisDataToPrm.sh` copies all the reports back to PRM, where the diagnostics can take a look at the QC data over time.

TMP location: `/groups/${GROUP}/${TMP}/trendanalysis/reports/${date}/chronqc_output/`

PRM location: `/groups/${GROUP}/${PRM}/trendanalysis/reports/${date}/chronqc_output/`

## Important
When creating a new database for production, it is important to know that a new inhouse NGS project (generated with NGS_DNA-4.2.2 or newer) is added first, 
this is due to different columns in comparison with an older version. 
When old data is added first the newer data cannot be added to the database.

## Debugging
If the output (trendanalysis reports) is not what you expect, check the input <- the qc files generated by other pipelines of the same data type (e.g. the multiQC files generated by the NGS_DNA).

If these are okay, check the runDateInfo and the tableFile <- input for the database.

If the runDateInfoFile and tableFile are also okay, check the database and the .json files (git/Trendanalysis/templates/).

You can check the database using SQLite
```bash
ml SQLite 
sqlite3 /groups/${GROUP}/${TMP}/trendanalysis/database/chronqc_db/chronqc.stats.sqlite
.table (see which tables are in the database)
select * from ${table}; (see what kind of data is in the table)
.exit (to exit sqlite)
```
