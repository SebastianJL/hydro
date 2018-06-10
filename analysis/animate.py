import argparse
import itertools as it
import multiprocessing
import os
import re
import time
from multiprocessing.pool import Pool
from pathlib import Path
from typing import Any, Union

import matplotlib.pyplot as plt
import numpy as np
from ffmpy3 import FFmpeg
from scipy.io import FortranFile


SETTINGS = {
    'origin': 'lower',
    'cmap': 'jet',
    'vmin': -3.308183,
    'vmax': 1.5684958,
    'dpi' : 96
}


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


def read(filename: Union[str, Path]) -> np.ndarray:
    with FortranFile(str(filename), 'r') as f:
        [t, gamma] = f.read_reals('f4')
        [nx, ny, nvar, nstep] = f.read_ints('i')
        dat = f.read_reals('f4')
    dat = np.array(dat)
    return dat.reshape(nvar, ny, nx)


def write_png_file(master_file: Path) -> None:
    master_data = read(master_file)
    for i in range(1, num_cpu):
        slave_file = master_file.parent / '{}.{:05}'.format(master_file.name.split(".")[0], i)
        if slave_file in data_files:
            slave_data = read(slave_file)
            master_data = np.hstack((master_data, slave_data))

    number = master_file.name.partition('_')[2].partition('.')[0]
    file = master_file.parent / 'frame_{}.png'.format(number)
    plt.imsave(str(file), np.log10(master_data[0, :, :]), **SETTINGS)


if __name__ == '__main__':
    output_dir_prefix = 'output-'

    # parse cli arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('-d', '--directory', type=lambda arg: directory(arg, parser), default='./',
                        help='directory in which output to be processed is saved.', dest='dir')
    parser.add_argument('-o', '--outfile', type=str, default='animation.gif',
                        help='filename for animation. (must be compatible with ffmpeg.)')
    parser.add_argument('-l', '--latest', action='store_true',
                        help='attempt to use latest output directory based on lexicographical order. directory name has to \
                        start with "{}". animation is saved in said output directory.'.format(output_dir_prefix),
                        dest='use_latest')
    parser.add_argument('-n', '--nproc', type=int, default=1, help='number of processes for multiprocessing.')
    parser.add_argument('--all-cores', action='store_true', help='use all available cores. overwrites --nproc')
    parser.add_argument('--read', dest='read', action='store_true', help='read Fortran Files and save to png files.')
    parser.add_argument('--no-read', dest='read', action='store_false', help="don't read Fortran Files and save to png files.")
    parser.set_defaults(read=True)
    args = parser.parse_args()

    # determine path to files
    wall_time = time.time()
    if args.use_latest:
        output = Path('../output/')
        dirs = (dir for dir in output.iterdir() if dir.name.startswith(output_dir_prefix))
        try:
            dir_ = max(dirs)
        except ValueError as e:
            if e.args[0] == 'max() arg is an empty sequence':
                raise FileNotFoundError(
                    'No directory with prefix "{}" found. Use --directory to specifiy location of directory with output files.'.format(
                        output_dir_prefix))
            else:
                raise
    else:
        dir_ = Path(args.dir)

    if args.read:
        # find files
        data_files = [f for f in dir_.iterdir() if re.match(r'output_[0-9]{5}.[0-9]{5}', f.name)]
        data_files.sort()
        master_files = [f for f in data_files if re.match(r'output_[0-9]{5}.[0]{5}', f.name)]
        master_files.sort()
        num_cpu = len(list(it.takewhile(lambda f: re.match(r'output_[0]{5}.[0-9]{5}', f.name), data_files)))
        if not data_files:
            print("no files found, exiting...")
            exit()

        # delete old pngs
        for file in dir_.glob('*.png'):
            file.unlink()

        # read output files and save as png files
        read_write_time = time.time()
        if not args.all_cores:
            print('{} cpus set'.format(args.nproc))
        print('{} cpus found'.format(multiprocessing.cpu_count()))
        print('reading image data from {} and saving to png...'.format(dir_))
        settings = {}
        if not args.all_cores:
            settings['processes'] = args.nproc
        with Pool(**settings) as pool:
            data = pool.map(write_png_file, master_files)
        read_write_time = time.time() - read_write_time

    # convert png files to animation
    outfile = dir_ / args.outfile
    print('converting to animation in {}'.format(outfile))
    convert_time = time.time()

    ff = FFmpeg(
        inputs={str(dir_ / 'frame_%5d.png'): None},
        outputs={str(outfile): '-loglevel error -y -nostats -vf scale=200:-1'}
    )
    print(ff.cmd)
    ff.run()
    convert_time = time.time() - convert_time

    if args.read:
        print('time needed for read/write pngs: {:.2f}s'.format(read_write_time))
    print('time needed for converting: {:.2f}s'.format(convert_time))
    print('wall time: {:.2f}s'.format(time.time() - wall_time))
