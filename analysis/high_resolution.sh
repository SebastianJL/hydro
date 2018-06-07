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
#echo removing old outputs...
#rm ../output/*

sbatch high_resolution.job
