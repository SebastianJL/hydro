import argparse
import itertools as it
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy.optimize import curve_fit


def model(n, alpha):
    return 1 / (alpha + (1 - alpha) / n)


if __name__ == '__main__':
    # Parse args
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-file', help='Specify file to read data.')
    args = parser.parse_args()

    # Parse Data
    if args.input_file is None:
        infile = max(file for file in (Path.cwd() / 'out').iterdir()
                     if file.name.startswith('strong_scaling-')
                     and file.name.endswith('.out'))
    else:
        infile = Path(args.input_file)

    with open(str(infile), 'r') as sf:
        lines = sf.readlines()

    _, nx, ny, max_ncpu, *__ = str(infile).split('-')
    nx = int(nx.partition('=')[2])
    ny = int(ny.partition('=')[2])
    max_ncpu = int(max_ncpu.partition('=')[2])

    data = zip(it.islice(lines, None, None, 3), it.islice(lines, 1, None, 3))
    data = it.takewhile(lambda line: line[0].startswith('srun') and line[1].startswith('Walltime'), data)
    times_by_ncpus = dict()
    for line in data:
        ncpu = int(line[0].partition('=')[2].partition(' ..')[0])
        walltime = float(line[1].partition(':')[2])
        times_by_ncpus.setdefault(ncpu, []).append(walltime)

    # Calculate
    rep = len(min(times_by_ncpus.values(), key=len))
    times_by_ncpus = sorted(times_by_ncpus.items())
    ncpus = np.array([x[0] for x in times_by_ncpus])
    times = np.array([x[1][:rep] for x in times_by_ncpus])

    maxi = np.max(times, axis=1)
    mini = np.min(times, axis=1)

    walltimes = np.mean(times, axis=1)
    walltimes_err = np.std(times, axis=1) / np.sqrt(rep)

    wall_speedup = walltimes[0] / walltimes
    wall_speedup_err = wall_speedup * np.sqrt((walltimes_err[0] / walltimes[0]) ** 2 + (walltimes_err / walltimes) ** 2)

    # Fitting
    popt, pcov = curve_fit(model, ncpus, wall_speedup, sigma=wall_speedup_err, absolute_sigma=True)

    # Plot runtime
    plt.figure(figsize=(12, 6))
    # plt.figure()
    plt.subplot(121)
    plt.errorbar(ncpus, walltimes, walltimes_err, label='walltime')
    plt.legend()
    plt.xlabel('ncpu')
    plt.ylabel('runtime')

    # Plot speedup
    plt.subplot(122)
    plt.errorbar(ncpus, wall_speedup, wall_speedup_err, label='wall speedup')
    plt.plot(ncpus, model(ncpus, *popt),
             label=r'lstsqr fit $\alpha=({:.5f} \pm {:.5f})\%$'.format(popt[0] * 100, pcov[0, 0] * 100))
    plt.plot(ncpus, ncpus, label='ideal speedup')
    plt.legend()
    plt.xlabel('ncpu')
    plt.ylabel('speedup')
    plt.xticks(range(1, ncpus[-1] + 1, 5))
    plt.yticks(range(1, ncpus[-1] + 1, 5))
    plt.suptitle(f'Strong Scaling: nx={nx}, ny={ny}, max_ncpu={max_ncpu}, repetitions={rep}')
    plt.savefig(f'out/{infile.stem}.png')
    plt.show()
