Scripts for Gaussian (mainly TDDFT)
-----------------------------------

Here are a few scripts I have been using to write input files for Gaussian DFT and TDDFT calculations and some post-processing. For instructions on how to use the scripts and how to change parameters type `-h` or `--help` after the script name.

### Writing input files


- To generate input files for a single point energy calculation, a geometry optimisation, an excited state calculation or post-processing (saving Natural Transition Orbitals or performing a population analysis), `write_ginput.sh` can be used. The only other input file needed is a geomtry file for the system. NB: the file `run_gauss.txt` has to be in the same directory.

- To generate a geometry files for pairs of molecules at different distances and generate input files for single point energy calculations (and optionally automatically submit the calculation to cx1) `write_pairs.sh` can be used. The only other input files needed are the geomtry files for the two molecules.



### Extracting results from log files

I have a few more of these, but they're a bit of a mess.

- Very simple script - `grab_SCF_energy.sh` just extracts the final energy after a converged SCF calculation.

- Extract lots of data about the excited states from a certain TDDFT calculation using `write_data_td.sh`.

- A script to extract summed partial charges for two molecules to identify CT states coming up...

### Other

- `run_states.sh` is useful for post-processing calculations for submitting many Gaussian calculations at once.


