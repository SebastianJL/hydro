#!/usr/bin/env bash
cd ../bin
echo compiling...
#make cleanall
if make -f Makefile.daint; then
#    make clean
    :
else
    echo compile error. Exiting..
    exit
fi
cd ../analysis
sbatch strong_scaling.job
