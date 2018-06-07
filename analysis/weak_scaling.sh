#!/usr/bin/env bash
function replace {
    sed -i "${1}s/.*/${2}/" ${3}
}
export -f replace

cd ../bin
echo compiling...
if make -f Makefile.daint; then
    :
else
    echo compile error. Exiting..
    exit
fi
cd ../analysis
echo removing old outputs...

now=`date +%Y-%m-%d.%H:%M:%S`
export infile="../input/input_weak_${now}.nml"
cp ../input/input.nml ${infile}
export nx=100
export ny=100
replace 9 nx=${nx} ${infile}

export rep=10
export ncpu=36
sbatch --output="out/weak_scaling-nx=${nx}-ny=${ny}-ncpu=${ncpu}-rep=${rep}.out" weak_scaling.job
