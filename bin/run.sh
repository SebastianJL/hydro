#!/bin/bash
./compile.sh
#./hydro
mpirun -np 4 hydro


#mpifort ../src/array_test.f90 -o array_test
#mpirun -np 2 array_test
#rm array_test