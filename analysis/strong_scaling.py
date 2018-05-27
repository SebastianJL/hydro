from pathlib import Path

import numpy as np
from scipy.io import FortranFile
import matplotlib.pyplot as plt

def to_array(*args):
    return (np.array(x) for x in args)

# Retrieve Data
output = Path('../output')
directories = [x for x in output.iterdir() if x.is_dir() and x.name.startswith('output-')]
times = {}
for directory in directories:
    try:
        with FortranFile(str(directory / 'run_data'), 'r') as f:
            cputime, walltime = f.read_reals('f4')
            ncpu, nx, ny = f.read_ints('i')
            times.setdefault(ncpu, []).append([cputime, walltime])
    except FileNotFoundError:
        pass

# Calculate
ncpus = []
cputimes = []
cputimes_err = []
walltimes = []
walltimes_err = []
for ncpu, time in times.items():
    time = np.array(time)
    cputime = time[:, 0]
    walltime = time[:, 1]
    cputime_mean = np.mean(cputime)
    walltime_mean = np.mean(walltime)
    cputime_err = np.std(cputime) / np.sqrt(len(cputime))
    walltime_err = np.std(walltime) / np.sqrt(len(walltime))
    ncpus.append(ncpu)
    cputimes.append(cputime_mean)
    walltimes.append(walltime_mean)
    cputimes_err.append(cputime_err)
    walltimes_err.append(walltime_err)

ncpus, cputimes, cputimes_err, walltimes, walltimes_err = to_array(ncpus, cputimes, cputimes_err, walltimes, walltimes_err)
cpu_speedup = cputimes[0]/cputimes
wall_speedup = walltimes[0]/walltimes
cpu_speedup_err = cpu_speedup * np.sqrt((cputimes_err[0]/cputimes[0])**2 + (cputimes_err/cputimes)**2)
wall_speedup_err = wall_speedup * np.sqrt((walltimes_err[0]/walltimes[0])**2 + (walltimes_err/walltimes)**2)

# Plot runtime
plt.subplot(122)
plt.errorbar(ncpus, cputimes, cputimes_err, label='cputime')
plt.errorbar(ncpus, walltimes, walltimes_err, label='walltime')
plt.legend()
plt.xlabel('ncpu')
plt.ylabel('runtime')

# Plot speedup
plt.subplot(121)
plt.errorbar(ncpus, cpu_speedup, cpu_speedup_err, label='cpu speedup')
plt.errorbar(ncpus, wall_speedup, wall_speedup_err, label='wall speedup')
plt.plot(ncpus, ncpus, label='ideal speedup')
plt.legend()
plt.xlabel('ncpu')
plt.ylabel('speedup')
plt.suptitle('strong scaling speedup, sample size: {}'.format(len(min(times.values(), key=len))))
plt.show()