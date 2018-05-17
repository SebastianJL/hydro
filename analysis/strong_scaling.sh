#!/usr/bin/env bash
cd ../bin
make cleanall
if make -f makefile.daint; then
    make clean
else
    echo compile error. Exiting..
    exit
fi
cd ../scripts
sbatch ./base.job
