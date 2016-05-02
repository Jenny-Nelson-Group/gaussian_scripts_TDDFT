#!/bin/bash

### Alise Virbule, 1st May 2016 ###

#Describe usage
display_usage() {
	cat << EOF

	############################	USAGE	############################

	This script will go into folders state_i, where i goes from start_i to end_i, and submit the bash run file (.sh) in that folder to the cx1 queues.

	Run from nto or pop folder (start_i and end_i need to be integers):
	./run_states.sh start_i end_i

EOF
}
##show usage when user types ./write_pairs -h OR --help
if [[ ($@ == "--help") || ($@ == "-h") ]]
then
	display_usage
	exit 0
fi

#read in user-specified start and end index of excited state
nstart=$1
nend=$2
#due to looping, need to add 1 to the index of the last state
n=$((nend+1))
#loop over states from $nstart to $nend
i=$nstart
while [ $i -lt $n ];
do
	#foldername (state_01 etc.)
	folder="state_$(echo ${i} | awk '{printf "%02d",$1}')"
	echo "folder $folder"	
	#go into folder and run the bash script
	cd $folder
	qsub *.sh
	#return to nto/pop folder and move onto next state calculation
	cd ..
	let i=i+1
done	#end distances list

