import argparse
import itertools as it
from pathlib import Path
from enum import Enum

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from scipy.optimize import curve_fit


class OP_MODE(Enum):
    strong = 'strong'
    weak = 'weak'


def get_model(opmode):
    if opmode is OP_MODE.strong:
        model = lambda n, alpha: 1 / (alpha + (1 - alpha) / n)
    elif opmode is OP_MODE.weak:
        model = lambda n, alpha: 1 / (n*alpha + (1 - alpha))
    else:
        raise ValueError(f'opmode must be either "{OP_MODE.strong.value}" or "{OP_MODE.weak.value}".')
    return model


if __name__ == '__main__':
    # Parse args
    parser = argparse.ArgumentParser()
    parser.add_argument('infile', type=str, help='specify file to read data from.')
    parser.add_argument('--opmode',
                        type=str,
                        choices=(OP_MODE.strong.value, OP_MODE.weak.value),
                        help='specify if analyzing strong or weak scaling.')
    args = parser.parse_args()
    infile = Path(args.infile)
    if args.opmode is None:
        strong_prefix = 'strong_scaling-'
        weak_prefix = 'weak_scaling-'
        if infile.name.startswith(strong_prefix):
            opmode = OP_MODE.strong
        elif infile.name.startswith(weak_prefix):
            opmode = OP_MODE.weak
        else:
            raise RuntimeError(f'infile not recognized. use "{strong_prefix}" or "{weak_prefix}" as prefix or specify opmode.')
    else:
        opmode = OP_MODE(args.opmode)

    # Parse Data
    with open(infile, 'r') as sf:
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

    walltimes = np.mean(times, axis=1)
    walltimes_err = np.std(times, axis=1) / np.sqrt(rep)

    wall_speedup = walltimes[0] / walltimes
    wall_speedup_err = wall_speedup * np.sqrt((walltimes_err[0] / walltimes[0]) ** 2 + (walltimes_err / walltimes) ** 2)

    # Fitting
    model = get_model(opmode)
    popt, pcov = curve_fit(model, ncpus, wall_speedup, sigma=wall_speedup_err, absolute_sigma=True)

    # Plot runtime
    plt.figure(figsize=(12, 6))
    matplotlib.rcParams['font.size'] = 12
    plt.subplot(121)
    plt.errorbar(ncpus, walltimes, walltimes_err, label='walltime')
    plt.legend()
    plt.xlabel('ncpu')
    plt.ylabel('runtime')
    plt.xticks(range(1, ncpus[-1] + 1, 5))

    # Plot speedup / efficiency
    name = {OP_MODE.strong: 'speedup', OP_MODE.weak: 'efficiency'}[opmode]
    plt.subplot(122)
    plt.errorbar(ncpus, wall_speedup, wall_speedup_err, label=f'wall {name}')
    plt.plot(ncpus, model(ncpus, *popt),
             label=r'lstsqr fit $\alpha=({:.5f} \pm {:.5f})\%$'.format(popt[0] * 100, pcov[0, 0] * 100))

    plt.plot(ncpus, model(ncpus, alpha=0), label=f'ideal {name}')
    plt.legend()
    plt.xlabel('ncpu')
    plt.ylabel(f'{name}')
    plt.xticks(range(1, ncpus[-1] + 1, 5))
    if opmode is OP_MODE.strong:
        plt.yticks(range(1, ncpus[-1] + 1, 5))
    plt.suptitle(f'{opmode.value.capitalize()} Scaling: nx={nx}, ny={ny}, max_ncpu={max_ncpu}, repetitions={rep}',
                 fontsize=17)
    plt.tight_layout(rect=[0, 0.03, 1, 0.95])
    plt.savefig(f'out/{infile.stem}.png')
    plt.show()
