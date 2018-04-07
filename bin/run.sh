#!/bin/bash
./compile.sh
mpirun -np 4 hydro
