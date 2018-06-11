import argparse
import itertools as it
import multiprocessing
import re
import time
from multiprocessing.pool import Pool
from pathlib import Path
from typing import Union

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

OUTPUT_DIR_PREFIX = 'output-'


def read_fortran_file(filename: Union[str, Path]) -> np.ndarray:
    with FortranFile(str(filename), 'r') as f:
        [t, gamma] = f.read_reals('f4')
        [nx, ny, nvar, nstep] = f.read_ints('i')
        dat = f.read_reals('f4')
    dat = np.array(dat)
    return dat.reshape(nvar, ny, nx)


def write_png_file(master_file: Path) -> None:
    master_data = read_fortran_file(master_file)
    for i in range(1, num_cpu):
        slave_file = master_file.parent / '{}.{:05}'.format(master_file.name.split(".")[0], i)
        if slave_file in data_files:
            slave_data = read_fortran_file(slave_file)
            master_data = np.hstack((master_data, slave_data))

    number = master_file.name.partition('_')[2].partition('.')[0]
    file = master_file.parent / 'frame_{}.png'.format(number)
    plt.imsave(str(file), np.log10(master_data[0, :, :]), **SETTINGS)


def parse_cli_arguments():
    parser = argparse.ArgumentParser(
        description='Animate output from the hydro fluid simulation.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('-d', '--directory', type=Path, default='./', dest='dir',
                        help='directory in which output to be processed is saved.')
    parser.add_argument('-o', '--outfile', type=str, default='animation.mp4',
                        help='filename for animation. must be compatible with ffmpeg. animation is saved in --directory.')
    parser.add_argument('-f', '--ffin', type=str, default=None, dest='ffmpeg_in',
                        help='set ffmpeg input options.')
    parser.add_argument('-F', '--ffout', type=str, default='-loglevel error -y -nostats -vf scale=400:-1', dest='ffmpeg_out',
                        help='set ffmpeg output options.')
    parser.add_argument('-n', '--nproc', type=int, default=1, help='number of processes for multiprocessing.')
    parser.add_argument('-l', '--latest', action='store_true',
                        help='attempt to use latest output directory based on lexicographical order. directory name has to \
                        start with "{}". overwrites --directory'.format(OUTPUT_DIR_PREFIX),
                        dest='use_latest')
    parser.add_argument('-a', '--all-cores', action='store_true', help='use all available cores. overwrites --nproc')
    parser.add_argument('--read', dest='read', action='store_true', help='read Fortran Files and save to png files.')
    parser.add_argument('--no-read', dest='read', action='store_false', help="don't read Fortran Files and save to png files.")
    parser.set_defaults(read=True)
    return parser.parse_args()


def find_latest_directory():
    output = Path('../output/')
    dirs = (dir for dir in output.iterdir() if dir.name.startswith(OUTPUT_DIR_PREFIX))
    try:
        dir_ = max(dirs)
    except ValueError as e:
        if e.args[0] == 'max() arg is an empty sequence':
            raise FileNotFoundError(
                'No directory with prefix "{}" found. Use --directory to specifiy location of directory with output files.'.format(
                    OUTPUT_DIR_PREFIX))
        else:
            raise
    return dir_


if __name__ == '__main__':

    args = parse_cli_arguments()

    wall_time = time.time()
    if args.use_latest:
        dir_ = find_latest_directory()
    else:
        dir_ = args.dir

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
        inputs={str(dir_ / 'frame_%5d.png'): args.ffmpeg_in},
        outputs={str(outfile): args.ffmpeg_out}
    )
    print(ff.cmd)
    ff.run()
    convert_time = time.time() - convert_time

    if args.read:
        print('time needed for read/write pngs: {:.2f}s'.format(read_write_time))
    print('time needed for converting: {:.2f}s'.format(convert_time))
    print('wall time: {:.2f}s'.format(time.time() - wall_time))
