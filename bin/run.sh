#!/bin/bash
./compile.sh
#./hydro
mpirun -np 8 hydro
