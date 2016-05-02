#!/bin/bash

### Alise Virbule, 2nd May 2016 ###

#Describe usage
display_usage() {
	cat << EOF

	############################	USAGE	############################

	This script will grab the final energy (in Ha) of the SCF calculation from filename.log and save it to filename_SCF_Ha.dat

	Run from folder where the log file is in
	./grab_SCF_energy.sh filename

EOF
}
##show usage when user types ./write_pairs -h OR --help
if [[ ($@ == "--help") || ($@ == "-h") ]]
then
	display_usage
	exit 0
fi

#read in filename (without extension)
filename=$1

#write all the lines with SCF Done into the file temp
grep "SCF Done" $filename.log > temp
#grab the last line to get the final energy
tail -1 temp > temp2
#grab the column which has the energy of the system in Ha
awk '{printf "%20.10f\n", (($5))}' temp2 > ${filename}_SCF_Ha.dat
#clean up
rm temp temp2
