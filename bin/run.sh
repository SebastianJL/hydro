#!/bin/bash
./compile.sh
mpirun -np 60 hydro
