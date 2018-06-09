#!/bin/bash
make
output='../output/'
rm ${output}output_*
nproc=4

command="mpirun -np ${nproc} hydro ../input/input.nml ${output}"
echo ${command}
eval ${command}

cd ../analysis
command="python animate.py -n=${nproc} -d=${output}"
echo ${command}
eval ${command}

command="gwenview ${output}animation.gif"
echo ${command}
eval ${command}