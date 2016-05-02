#!/bin/bash

### Alise Virbule, 1st May 2016 ###

####################################################
################  FILE PATHS  ######################
#the paths can't be relative to the home directory (i.e. no ~/work/)
#path where to create sp and opt caluclation folders
calc_path="/work/av2613/SmallMolecules"
#path to folder of inital geometry file
geom_path="/work/av2613/initial_geoms"

############### DEFAULT VALUES  ####################
calc="opt"
solvent="none"
funct="CAM-B3LYP"
bas="cc-pVDZ"
pop="MK"
ntd=10
mem=63000		##20 cpu nodes usually have 64GB or 128GB
nproc=20		##biggest nodes have 20 cpus as far as I know
nnodes=1
wallt="71:58:00"	##maximum allowed time on cx1
####################################################


function USAGE()
{
	cat << EOF

########################   USAGE   ############################

	~/bin/write_ginput.sh -option option_value molecule_name

	The input geometry has to be in the folder /geom_path/ under the name molecule_name.xyz
	and the file should have four columns - element symbol and x, y, z coordinates in Angstroms - and a row for each atom.
	The folders and files for the calculation will be created in /calc_path/ 
	##  geom_path and calc_path can be changed at the top of this file

#######################  EXAMPLES  ############################

	Geometry optimisation in chloroform using the wB97XD functional for dithiophene (geometry in file 2T_alt_D0.xyz)
		(from bin) ./write_ginput.sh -c opt -s chloroform -f wB97XD -w 00:30:00 2T_alt_D0
	The script will create a folder /calc_path/2T_alt_D0/ and write a Gaussian input file (.gjf) and a bash run file (.sh) to be submitted to a queue using qsub
	(same for an opt caluclation)

	Calculate 30 excited states (TDDFT) for thiophene 22-mer using default basis set and XC functional
		(from sp or opt folder) ~/bin/write_ginput.sh -c td -t 30 -w 05:00:00 22T_alt
	The script will create a folder /td30_CAM-B3LYP_cc-pVDZ/, copy the checkpoint file (.chk) from the sp or opt calculation into it (for geometry and wavefunction guess),
	and also write a Gaussian input file (.gjf) and a bash run file (.sh) to be submitted to the cx1 queues using qsub

	Perform a CHelpG population analysis on the first 20 excited states of benzene
		(from td folder) ~/bin/write_ginput.sh -c pop -e CHelpG -t 20 -m 7000 -p 8 -w 00:30:00 benzene
	The script will create a folder /pop20_CHelpG/ and copy over the "master" checkpoint file (_master.chk), which contains all the transition densities,
	pop20_CHelpG will also contain folders state_01 up to state_20, each of these folders contains a separate Gaussian input file (.gjf) and bash run script (.sh).
	The calculations on each excitet state can be submitted separately using qsub, or the script ~/bin/run_states.sh can be used.
	(similar for nto calculation)  
	
###################  Calculation MODES  #######################
		
Single point energy:			sp (run from bin) 
Geometry optimisation:			opt (run from bin)		- can add solvent
TDDFT:					td (run from opt or sp folder)	- can add solvent
Save Natural Transition Orbitals:	nto (run from td folder)
Population Analysis:			pop (run from td folder)

######################  OPTIONS  ###############################

	-c calculation mode (default opt)		## default values can be changed at the top of this file
	-s solvent (default none)
	-f functional (default CAM-B3LYP)
	-b basis set (default cc-pVDZ)
	-e ESP population analysis method (default MK)
	-t no. excited states (default 10)
	-m memory (default 63000)
	-p no. processors (default 20)
	-n no. nodes (default 1)
	-w walltime (default 71:58:00)

EOF
}


#read in options
while getopts ":c:s:f:b:e:t:m:p:n:w:h" Option; do
	case $Option in
		c) calc=$OPTARG;;
		s) solvent=$OPTARG;;
		f) funct=$OPTARG;;
		b) bas=$OPTARG;;
		e) pop=$OPTARG;;
		t) ntd=$OPTARG;;
		m) mem=$OPTARG;;
		p) nproc=$OPTARG;;
		n) nnodes=$OPTARG;;
		w) wallt=$OPTARG;;
		h) USAGE
		   exit 0;;
	esac
done
#necessary for reading in options, don't really understand how it works
shift $((OPTIND-1))

#read in name of molecule (for initial geometry for sp or opt calculation)
name="$@"

#mem from options is used in gaussian input file, add 800MB for run script as buffer
memsh=$((mem+800))
#tell Gaussian to calculate 2 more excited states than required
ncalc=$((ntd+2))

#these are just for file naming purposes (as $ntd is included in the name)
if [ "$calc" == "sp" ];then
	ntd=""
fi
if [ "$calc" == "opt" ];then
	ntd=""
fi

#Name of input file
if [ "$solvent" == "none" ];then
	gjfname="${name}_${calc}${ntd}_${funct}_${bas}_$(date +"%Y_%m_%d")"
else
	gjfname="${name}_${solvent}_${calc}${ntd}_${funct}_${bas}_$(date +"%Y_%m_%d")"
fi

#shorter filename (without date), used for post-processing steps (nto and pop)
ppname="${name}_td${ntd}_${funct}_${bas}"

	###############################################
	####### Single point energy (no solvent) ######
	###############################################

if [ "$calc" == "sp" ] && [ "$solvent" == "none" ];then
#create folder for this molecule/system
	cd $calc_path
	mkdir $name
	cd $name
#create folder for this sp calculation
	mkdir ${calc}_${funct}_${bas}
	cd ${calc}_${funct}_${bas}
#write top of Gaussian input file with calculation parameters
	cat > $gjfname.gjf << EOF
%chk=$gjfname
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} sp

ground state energy calculation

0 1
EOF
#copy coordinates into the gjf file and add two empty lines (Gaussian is a bit weird about these things sometimes)
	cat ~/work/initial_geoms/$name.xyz >> $gjfname.gjf
	echo " " >> $gjfname.gjf 
	echo " " >> $gjfname.gjf 
#write top of bash run file with parameters for this calculation
	cat > $gjfname.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#copy in instructions to run gaussian from the template file run_gauss.txt
	cat ~/bin/run_gauss.txt >> $gjfname.sh


	#################################################
	####### Geometry optimisation (no solvent) ######
	#################################################

elif [ "$calc" == "opt" ] && [ "$solvent" == "none" ];then
#create folder for this molecule/pair/system
	cd $calc_path
	mkdir $name
	cd $name
#create folder for this opt calculation
	mkdir ${calc}_${funct}_${bas}
	cd ${calc}_${funct}_${bas}
#write top of Gaussian input file with calculation parameters
	cat > $gjfname.gjf << EOF
%chk=$gjfname
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} opt=modredundant

Geometry optimisation, ground state energy calculation

0 1
EOF
#copy in coordinates of initial geometry and add two empty lines
	cat ~/work/initial_geoms/$name.xyz >> $gjfname.gjf
	echo " " >> $gjfname.gjf 
	echo " " >> $gjfname.gjf 
#write top of bash run file
	cat > $gjfname.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#copy commands to run gaussian from template file
	cat ~/bin/run_gauss.txt >> $gjfname.sh


	###############################################
	##### Geometry optimisation with solvent ######
	###############################################

elif [ "$calc" == "opt" ] && [ "$solvent" != "none" ];then
#create folder for this molecule/system
	cd $calc_path
	mkdir ${name}_${solvent}
	cd ${name}_${solvent}
#create folder for this calculatin
	mkdir ${calc}_${funct}_${bas}
	cd ${calc}_${funct}_${bas}
#write Gaussian input file
	cat > $gjfname.gjf << EOF
%chk=01_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} opt freq SCRF=(Solvent=${solvent})

${name} ground state in ${solvent}

0 1
EOF
#copy in coordinates
	cat ~/work/initial_geoms/$name.xyz >> $gjfname.gjf
	echo " " >> $gjfname.gjf 
	echo " " >> $gjfname.gjf 
#write top of bash run file with calculation parameters
	cat > $gjfname.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#copy commands to run Gaussian from template file
	cat ~/bin/run_gauss.txt >> $gjfname.sh


	####################################################
	###### Excited state calculation (no solvent) ######
	####################################################

elif [ "$calc" == "td" ] && [ "$solvent" == "none" ];then
#create folder for calculation
	mkdir ${calc}${ntd}_${funct}_${bas}
	cd ${calc}${ntd}_${funct}_${bas}
#copy chk file from optimised structure into TD folder
	cp ../*.chk $gjfname.chk
#write Gaussian input file (don't need geometry file, as this will be read from the chk file)
	cat > $gjfname.gjf << EOF
%oldchk=$gjfname
%chk=${gjfname}_master
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} geom=checkpoint guess=read td(singlets,nstates=$ncalc)

Calculate $ncalc excited states and save to master chk file

0 1

EOF
#write top of bash run file
	cat > $gjfname.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#copy in commands to run Gaussian from template
	cat ~/bin/run_gauss.txt >> $gjfname.sh


	#############################################################################
	####### Excited state calculation in solvent (absorption and emission) ######
	#############################################################################

elif [ "$calc" == "td" ] && [ "$solvent" != "none" ];then
#create folder for calculation
	mkdir ${calc}${ntd}_${solvent}_${funct}_${bas}
	cd ${calc}${ntd}_${solvent}_${funct}_${bas}
#copy chk file from optimised structure into TD folder
#don't need to rename file as it was created in the optimisation calculation as a first step for this calculation
	cp ../*.chk .
#write Gaussian input file to calculate a first guess for all excited states
	cat > $gjfname.gjf << EOF
%oldchk=01_SCRF_${name}_${solvent}
%chk=02_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} TD=NStates=${ncalc} SCRF=(Solvent=${solvent}) Geom=Check Guess=Read

${name} in ${solvent} linear response vertical excited states

0 1

EOF
#write top of bash run file
	cat > $gjfname.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#copy in commands to run Gaussian from template
	cat ~/bin/run_gauss.txt >> $gjfname.sh


#State specific solvation for all excited states
#loop over all $ntd excited states
	for (( i=1; i<=$ntd; i++ ))
	do
#create and enter folder for state i calculation (state_01 etc.)
	mkdir state_$(echo ${i} | awk '{printf "%02d",$1}')
	cd state_$(echo ${i} | awk '{printf "%02d",$1}')
#add state number to gjf name
		gjfname="${name}_${solvent}_${calc}${ntd}_${funct}_${bas}_$(date +"%Y_%m_%d")_state_$(echo ${i} | awk '{printf "%02d",$1}')"
#write Gaussian input file for the i-th excited state, will calculate absorption and emission (including excited state geom optimisation), and can get Stokes shift
		cat > ${gjfname}.gjf << EOF
%oldchk=01_SCRF_${name}_${solvent}
%chk=03_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} SCRF=(Solvent=${solvent},Read) Geom=Check Guess=Read

${name}: prepare for state-specific non-eq solvation by saving the solvent reaction field from the ground state

0 1

NonEq=write

--link1--
%chk=03_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} TD(Nstates=${ncalc},Root=${i}) SCRF=(Solvent=${solvent},externalIteration,Read) Geom=Check Guess=Read

$name: read non-eq solvation from ground state and compute energy of the ${i}th excited state with the state-specific method

0 1

NonEq=read

--link1--
%oldchk=02_SCRF_${name}_${solvent}
%chk=04_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} TD=(Read,NStates=${ncalc},Root=${i}) SCRF=(Solvent=${solvent}) Geom=Check Guess=Read Opt=ReadFC

$name: excited state opt

0 1

--link1--
%oldchk=04_SCRF_${name}_${solvent}
%chk=05_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} TD=(Read,NStates=${ncalc},Root=${i}) Freq SCRF=(Solvent=${solvent}) Geom=Check Guess=Read

$name excited state frequencies to check if found minimum

0 1

--link1--
%oldchk=05_SCRF_${name}_${solvent}
%chk=06_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} TD=(Read,NStates=${ncalc},Root=${i}) SCRF=(Solvent=${solvent},ExternalIteration,Read) Geom=Check Guess=Read

$name in $solvent emission state specific solvation at ${i}th excited state optimised geometry

0 1

NonEq=write

--link1--
%oldchk=06_SCRF_${name}_${solvent}
%chk=07_SCRF_${name}_${solvent}
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} SCRF=(Solvent=${solvent},Read) Geom=Check Guess=Read

$name ground state non-eq at excited state geometry

0 1

NonEq=read

EOF
#write bash run file with the correct gjfname specific to the excited state
		cat > ${gjfname}.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
		cat >> ${gjfname}.sh << EOF

echo "Execution started:"
date

module load gaussian

EOF
		echo "cp $""PBS_O_WORKDIR/${gjfname}.gjf ./" >> ${gjfname}.sh 
		echo "cp $""PBS_O_WORKDIR/../*.chk ./" >> ${gjfname}.sh
		cat >> ${gjfname}.sh <<EOF

pbsexec g09 ${gjfname}.gjf

echo "Gaussian job finished:"
date

rm Gau*
EOF
		echo "cp * $""PBS_O_WORKDIR" >> ${gjfname}.sh
		cd ..
	done
#this done is to end the for loop over all considered excited states

	###########################################################
	######## Generate and save NTOs (post-processing) #########
	###########################################################

elif [ "$calc" == "nto" ];then
#create folder for calculation
	mkdir ${calc}${ntd}
	cd ${calc}${ntd}
#create folder for all nto chk files
	mkdir final_NTO_chks
#copy master chk file over (with all transition densities from TDDFT calculation)
	cp ../*master.chk ${ppname}_master.chk
#write input file for all excited states i=1-ntd
	for (( i=1; i<=$ntd; i++ ))
	do
#create and enter folder for state i calculation (state_01 etc.)
		mkdir state_$(echo ${i} | awk '{printf "%02d",$1}')
		cd state_$(echo ${i} | awk '{printf "%02d",$1}')
#add state number to gjf name
		gjfname="${name}_${calc}${ntd}_${funct}_${bas}_$(date +"%Y_%m_%d")_state_$(echo ${i} | awk '{printf "%02d",$1}')"
#write Gaussian input file for i-th excited state
		cat > ${gjfname}.gjf << EOF
%oldchk=${ppname}_master
%chk=${ppname}_density_$(echo ${i} | awk '{printf "%02d",$1}')
%mem=${mem}MB
%nprocshared=$nproc
#p ${funct}/${bas} td(read,nstates=$ncalc,root=$i) density=current geom=check guess=read pop=ESP

read results from TD job from hk file and compute density of excited state $i and perform analysis on it

0 1

--link1--
%oldchk=${ppname}_density_$(echo ${i} | awk '{printf "%02d",$1}')
%chk=${ppname}_NTO_$(echo ${i} | awk '{printf "%02d",$1}')
%mem=${mem}MB
%nprocshared=$nproc
#p chkbasis geom=check guess=only density=(check,transition=$i) pop=(Minimal,SaveNTO) iop(6/22=-14)

save NTO from ground state to excited state $i transition density

0 1


EOF
#writetop of  bash run file for i-th excited state
		cat > ${gjfname}.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
#write the rest of the bash run file for i-th excited state
		cat >> ${gjfname}.sh << EOF

echo "Execution started:"
date

module load gaussian

EOF
		echo "cp $""PBS_O_WORKDIR/${gjfname}.gjf ./" >> ${gjfname}.sh 
		echo "cp $""PBS_O_WORKDIR/../*master.chk ./" >> ${gjfname}.sh
		cat >> ${gjfname}.sh <<EOF

pbsexec g09 ${gjfname}.gjf

echo "Gaussian job finished:"
date

EOF
#some more lines to the bash run file
		echo "cp *.log $""PBS_O_WORKDIR" >> ${gjfname}.sh
		echo "cp *NTO* $""PBS_O_WORKDIR" >> ${gjfname}.sh
		echo "mv $""PBS_O_WORKDIR/${ppname}_NTO_$(echo ${i} | awk '{printf "%02d",$1}').chk $""PBS_O_WORKDIR/../final_NTO_chks" >> ${gjfname}.sh
		cd ..
	done
#this done finishes the for loop over all $ntd excited states

#write run file to generate cubes from all the NTO chks
	cd final_NTO_chks
#write top of bash run file
	cat > gen_cubes.sh << EOF
#!/bin/sh
#PBS -l walltime=01:00:00
#PBS -l select=1:ncpus=8:mem=11800MB
#PBS -m e

echo "Execution started:"
date

module load gaussian

cp ~/bin/gen_HL_cubes.sh ./
chmod +x gen_HL_cubes.sh
mkdir cubes
EOF
echo "cp $""PBS_O_WORKDIR/*.chk ./" >> gen_cubes.sh 
#write a line for each excited state (to generate a cube file from the chk file for each)
for (( i=1; i<=$ntd; i++ ))
do
	echo "./gen_HL_cubes.sh *$(echo ${i} | awk '{printf "%02d",$1}')*" >> gen_cubes.sh
done
#add final lines to the bash run file
cat >> gen_cubes.sh <<EOF
echo "Generating cubes done:"
date

EOF
	echo "cp -r cubes $""PBS_O_WORKDIR/cubes_${ppname}" >> gen_cubes.sh

	###########################################################
	########## Population Analysis (post-processing) #########
	###########################################################

elif [ "$calc" == "pop" ];then
#create folder for calculation
	mkdir ${calc}${ntd}_${pop}
	cd ${calc}${ntd}_${pop}
#copy master chk file over
	cp ../*master.chk ${ppname}_master.chk
#write input file for i=1-ntd
#loop over all ntd excited states
	for (( i=1; i<=$ntd; i++ ))
	do
#create and enter folder for state i calculation
		mkdir state_$(echo ${i} | awk '{printf "%02d",$1}')
		cd state_$(echo ${i} | awk '{printf "%02d",$1}')
#add state number to gjf name
		gjfname="${name}_${calc}${ntd}_${pop}_${funct}_${bas}_$(date +"%Y_%m_%d")_state_$(echo ${i} | awk '{printf "%02d",$1}')"
#write Gaussian input file for i-th excited state
		cat > ${gjfname}.gjf << EOF
%oldchk=${ppname}_master
%chk=${ppname}_density_$(echo ${i} | awk '{printf "%02d",$1}')
%mem=${mem}MB
%nprocshared=$nproc
#p Geom=AllCheck ChkBas Guess=(Read,Only) Density=(Check,CIS=$(echo ${i} | awk '{printf "%02d",$1}')) Pop=${pop}

read results from TD job from hk file for density of excited state $i and perform population analysis on it

0 1


EOF
#write bash run file for i-th excited state
		cat > ${gjfname}.sh << EOF
#!/bin/sh
#PBS -l walltime=$wallt
#PBS -l select=$nnodes:ncpus=$nproc:mem=${memsh}MB
#PBS -m e
EOF
		cat >> ${gjfname}.sh << EOF

echo "Execution started:"
date

module load gaussian

EOF
		echo "cp $""PBS_O_WORKDIR/${gjfname}.gjf ./" >> ${gjfname}.sh 
		echo "cp $""PBS_O_WORKDIR/../*master.chk ./" >> ${gjfname}.sh
		cat >> ${gjfname}.sh <<EOF

pbsexec g09 ${gjfname}.gjf

echo "Gaussian job finished:"
date

EOF
		echo "cp *.log $""PBS_O_WORKDIR" >> ${gjfname}.sh
		cd ..
	done
#this done finishes for loop over all ntd excited states

fi
#this fi finishes the if statement for all the calculation modes (and solvent presence)

