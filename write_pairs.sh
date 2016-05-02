#!/bin/bash

### Alise Virbule, 1st May 2016 ###

##############################
#####	PARAMETERS START #####

### SPECIFY MOLECULES ###
#name (has to be the same as geometry file in geom_path) and number of atoms for molecule 1
mol1='1T' 		
nat1=9
#name (has to be the same as geometry file in geom_path) and number of atoms for molecule 2
mol2="1T_flip"
nat2=9
#name of pair
pairname="test_1T_pair"

### SPECIFY DISTANCES ###
#specify centre-to-centre distances in x,y,z directions
dxlist=( 0.0 0.0 0.0 ) 
dylist=( 7.0 8.0 9.0 )
dzlist=( 0.0 0.0 0.0 )
#values in distlist will be used for folder and file names
distlist=( 7p0 8p0 9p0 )
#N is the number of distances specified, for easier looping
N=3	

### DFT PARAMETERS ###
funct="CAM-B3LYP"	# exchange-correlation funcitonal
bas="cc-pVDZ"		# basis set

### CALCULATION PARAMETERS ###
mem="12000"		# memory in MB
nproc="12"		# number of cpus
wtime="00:30:00"	# walltime

### SPECIFY FILEPATHS  ###
## these need to match with the paths in write_ginput.sh and can't be relative to home (i.e. no ~/work/)
geom_path="/work/av2613/initial_geoms"	#where to find initial geometry files
calc_path="/work/av2613/SmallMolecules"	#where to put calculation folder and files

######	PARAMETERS END	######
##############################

#Describe usage
display_usage() {
	cat << EOF

	############################	USAGE	############################

	This script will create a new geometry file for a pair of molecules and also create input files for a single point energy DFT calculation.
	To automatically submit the calculations to the cx1 queues, uncomment the appropriate lines near the end of the file.

	Run from bin without any options:
	./write_pairs.sh

	All parameters have to be set at the top of this file.

EOF
}
##show usage when user types ./write_pairs -h
if [[ ($@ == "--help") || ($@ == "-h") ]]
then
	display_usage
	exit 0
fi


##start script
#loop over N distances, first index is i=0
i=0
while [ $i -lt $N ];
do
	#choose i-th distance for name and dx,dy,dz from list
	dist=${distlist[$i]}
	dx=${dxlist[$i]}
	dy=${dylist[$i]}
	dz=${dzlist[$i]}
	
	#write pairname with correct distance
	filename="${pairname}_${dist}"
	echo "filename for pair is $filename"

	#get coordinates of original molecules (use tail in case the xyz file has some header rows)
	tail -$nat1 ${geom_path}/${mol1}.xyz > coords1
	tail -$nat2 ${geom_path}/${mol2}.xyz > coords2

	#write shifted coordinatess of mol2 into newcoords
	awk -v x=$dx -v y=$dy -v z=$dz '{printf "%s \t %8.6f \t %8.6f \t %8.6f \n", $1, (($2+x)), (($3+y)), (($4+z)) }' coords2 > new_coords
	
	#combine both into new file filename.xyz
	#reformat original coordinates of mol1 with tab sapcings
	awk '{printf "%s \t %8.6f \t %8.6f \t %8.6f \n", $1, $2, $3, $4}' coords1 > ${filename}.xyz
	#add shifted coordinates of mol2 in the same file
	cat new_coords >> ${filename}.xyz
	
	#move new geometry file into initial_geoms directory
	mv ${filename}.xyz ${geom_path}
	#clean up temporary files
	rm *coords

	#write input file for single energy calculation, 
	./write_ginput.sh -c sp -f $funct -b $bas -m $mem -p $nproc -w $wtime $filename

### UNCOMMENT NEXT TWO LINES TO GO INTO DIRECTORY AND RUN JOB ###
#	cd ${calc_path}/${pairname}/sp_${funct}_${bas}/
#	qsub *.sh

	#return to /bin and move onto next calculation (i loops over all N distances)
	cd ~/bin
	let i=i+1
done	#end looping over distances list

