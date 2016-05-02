#!/bin/bash

### Alise Virbule, 2nd May 2016 ###

### FILEPATHS ###
#has to be absolute (i.e. no ~/work/)
dat_path="/work/av2613/spectra"
#################

#Describe usage
display_usage() {
	cat << EOF

	############################	USAGE	############################

	Run from the td folder containing the log file of the TDDFT calculation:
	(datafile should be without the .dat extension, ntd has to be an integer)

	./write_dat.sh datafile ntd

	This script will write the excited state data for the first ntd excited states into datafile.dat
	and move it to the folder dat_path (dat_path can be changed at the top of this file)

	Data includes: 	excited state index, symmetry, transition energy (in eV) and wavelength (in nm), oscillator strength, 
			electric transition dipole moment x,y,z components and its magnitude squared

EOF
}
##show usage when user types ./write_pairs -h OR --help
if [[ ($@ == "--help") || ($@ == "-h") ]]
then
	display_usage
	exit 0
fi

#specify data file name and no. excited states to write
#read in user supplied datafile name and number of excited states
datafile=$1
ntd=$2
#need this for some grep command later
ntd2=$((ntd+1))
#bash is weird, need this as separate variable
logfile="*.log"

#get electric dipole moment data and separate into columns
grep -A $ntd2 'electric dipole moment' $logfile > temp
tail -$ntd temp > temp2
#separate into columns and store in temporary file dipoles
awk '{printf "%6.3f \t %6.3f \t %6.3f \t %6.3f \n", $2, $3, $4, $5}' temp2 > dipoles

#get data for first ntd excited states and store in temp
grep 'Excited State' $logfile > temp
head -$ntd temp > temp2
#get symmetry of excited state and store in symm
awk '{printf "%s \n", $4}' temp2 > symm
#get energy and wavelength and store in Eandl
awk '{printf "%5.3f \t %7.3f \n", $5, $7}' temp2 > Eandl
#get oscillator strength and store in osc
awk '{printf "%s \n", $9}' temp2 > osc

##symm has values in the format 'Singlet-A1', separate string so that sep_symm only has A1
for item in `cat symm`
do
	echo ${item##*-} >> sep_symm
done
#same for oscilator strength (separate string from f=0.0096 to 0.0096)
for item in `cat osc`
do
	echo ${item##*=} >> sep_osc
done

#write column for excited state number
for i in `seq 1 $ntd`;
do
echo $i >> state
done

#write header row for datafile.dat
echo 'State	Symm	E(eV)	lamda(nm)	OscStr	mu_x	mu_y	mu_z	mu^2' > $datafile.dat
#paste all the columns with the data together
paste -d"\t" state sep_symm > temp
paste -d"\t" temp Eandl > temp2
paste -d"\t" temp2 sep_osc > temp
paste -d"\t" temp dipoles > temp2
#add data under the header row in datafile.dat
cat temp2 >> $datafile.dat

#clean up
rm temp temp2 state sep_* symm osc Eandl dipoles

#move datafile.dat to directory specified at the top of the file
mv $datafile.dat $dat_path
