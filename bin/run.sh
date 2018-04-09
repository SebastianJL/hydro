#!/bin/bash
./compile.sh
mpirun -np 2 hydro
