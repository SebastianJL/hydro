import argparse
import os
import time
from typing import Any

import matplotlib.animation as animation
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import FortranFile


def directory(arg: Any, parser: argparse.ArgumentParser = None):
    """Check if argument is a directory and format such that it ends with '/'"""
    if not os.path.isdir(arg):
        msg = 'The directory "{}" does not exist'.format(arg)
        if parser is not None:
            parser.error(msg)
        else:
            raise FileNotFoundError(msg)
    else:
        if not arg[-1] == '/':
            arg += '/'
        return str(arg)


def read(filename: str) -> np.ndarray:
    with FortranFile(filename, 'r') as f:
        [t, gamma] = f.read_reals('f4')
        [nx, ny, nvar, nstep] = f.read_ints('i')
        dat = f.read_reals('f4')
    dat = np.array(dat)
    return dat.reshape(nvar, ny, nx)


output_dir_prefix = 'output-'

# parse cli arguments
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--directory', type=lambda arg: directory(arg, parser), default='./',
                    help='directory in which output to be processed is saved', dest='dir')
parser.add_argument('-o', '--outfile', type=str, default='animation.mp4',
                    help='filename for animation. also determines filetype through file extension (only mp4 fully \
                    supported')
parser.add_argument('-f', '--format', type=str, default='output_{:05}.{:05}', help='file format for output files')
parser.add_argument('-l', '--latest', action='store_true',
                    help='attempt to use latest output directory based on lexicographical order. directory name has to \
                    start with "{}". animation is saved in said output directory'.format(output_dir_prefix),
                    dest='use_latest')
parser.add_argument('-s', '--show', action='store_true',
                    help='show animation after saving. default when using option --no-save  ')
parser.add_argument('-n', '--no-save', action='store_false', help="don't save animation, show instead", dest='save')
args = parser.parse_args()

# determine path to files
if args.use_latest:
    output = '../output/'
    dirs = (os.path.join(output, dir) for dir in os.listdir(output)
            if os.path.isdir(os.path.join(output, dir)) and dir.startswith(output_dir_prefix))
    try:
        dir = max(dirs)
    except ValueError as e:
        if e.args[0] == 'max() arg is an empty sequence':
            raise FileNotFoundError(
                'No directory with prefix "{}" found. Use --directory to specifiy location of directory with output files.'.format(
                    output_dir_prefix))
        else:
            raise
    path = directory(dir) + args.format
    args.outfile = directory(dir) + 'animation.mp4'
else:
    path = args.dir + args.format
print('file format pattern: {}'.format(path))

# determine num_cpu
num_cpu = 0
while True:
    if not os.path.exists(path.format(0, num_cpu)):
        break
    num_cpu += 1
print('found files from {} cpus'.format(num_cpu))

# define figure
dpi = 96
fig = plt.figure(figsize=(800 / dpi, 800 / dpi), dpi=dpi)
# fig = plt.figure()

# read files
print("reading image data from files...")
frames = []
j = 0
while os.path.exists(path.format(j, 0)):
    master_file = path.format(j, 0)
    master_data = read(master_file)
    for i in range(1, num_cpu):
        slave_file = path.format(j, i)
        slave_data = read(slave_file)
        master_data = np.hstack((master_data, slave_data))

    # plot the map
    img = plt.imshow(
        np.log10(master_data[0, :, :]),
        interpolation='nearest',
        origin='lower',
        animated=True,
        cmap='jet',
        vmin=-3.308183,
        vmax=1.5684958
    )
    frames.append([img])
    j += 1

if j == 0:
    print("no files found, exiting...")
    exit()

# animate
ani = animation.ArtistAnimation(fig, frames, interval=100, repeat_delay=100)

# save animation
if args.save:
    print('saving animation in {}'.format(args.outfile))
    start_time = time.time()
    ani.save(args.outfile, writer=animation.FFMpegWriter(fps=30, codec='libx264'))
    print('time needed for saving: {:.2f}s'.format(time.time() - start_time))

# display
if args.show or not args.save:
    plt.show()
