#!/usr/bin/env bash
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

nx=`cat ../input/input.nml | grep nx`
ny=`cat ../input/input.nml | grep ny`
export ncpu=36
export rep=10
sbatch --output="out/strong_scaling-${nx}-${ny}-ncpu=${ncpu}-rep=${rep}.out" strong_scaling.job
