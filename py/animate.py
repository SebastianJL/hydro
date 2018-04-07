import argparse
import os
import time

import matplotlib.animation as animation
import matplotlib.pyplot as plt
import numpy as np
from scipy.io import FortranFile


def directory(arg, parser=None):
    """Check if argument is a directory and format such that it ends with "/" """
    if not os.path.isdir(arg):
        msg = 'The directory "{}" does not exist'.format(arg)
        try:
            parser.error(msg)
        except AttributeError:
            raise FileNotFoundError(msg)
    else:
        if not arg[-1] == '/':
            arg += '/'
        return str(arg)


# parse cli arguments
parser = argparse.ArgumentParser()
parser.add_argument('-d', '--directory', type=lambda arg: directory(arg, parser), default='./',
                    help='directory in which output to be processed is saved', dest='dir')
parser.add_argument('-o', '--outfile', type=str, default='animation.mp4',
                    help='filename for animation. also determines filetype through ending',
                    dest='outfile')
parser.add_argument('-f', '--format', type=str, default='output_{:05}.00000', help='file format for output files',
                    dest='format')
parser.add_argument('-l', '--latest', action='store_true', help='attempt to use latest output directory', dest='use_latest')
args = parser.parse_args()

# determine path to files
if args.use_latest:
    output = '../output/'
    dirs = (os.path.join(output, dir) for dir in os.listdir(output) if os.path.isdir(os.path.join(output, dir)))
    path = directory(max(dirs)) + args.format
else:
    path = args.dir + args.format

map_files = []
j = 0
print('loading files from {}'.format(path))
while True:
    if not os.path.exists(path.format(j)):
        break
    map_files.append(path.format(j))
    j += 1
if j == 0:
    print("no files found, exiting...")
    exit()

dpi = 96
fig = plt.figure(figsize=(800 / dpi, 800 / dpi), dpi=dpi)

print("reading image data from files...")
frames = []
for map_file in map_files:
    f = FortranFile(map_file, 'r')
    [t, gamma] = f.read_reals('f4')
    [nx, ny, nvar, nstep] = f.read_ints('i')
    dat = f.read_reals('f4')
    f.close()

    dat = np.array(dat)
    dat = dat.reshape(nvar, ny, nx)

    # plot the map
    img = plt.imshow(
        np.log10(dat[0, :, :]),
        interpolation='nearest',
        origin='lower',
        animated=True,
        cmap='jet',
        vmin=-3.308183,
        vmax=1.5684958
    )
    frames.append([img])

# animate
ani = animation.ArtistAnimation(fig, frames, interval=100, repeat_delay=100)

# save animation
print('saving animation...')
start_time = time.time()
ani.save(args.outfile, writer=animation.FFMpegWriter(fps=60))
print(time.time() - start_time, 's', sep='')
plt.show()
