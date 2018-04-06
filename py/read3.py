import fortranfile
#from scipy.io import FortranFile
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys
import os

# path the the file
map_files = []
j = 0
print("loading files...")
while True:
    if not os.path.exists('./output_{:05}.00000'.format(j)):
        break
    map_files.append('./output_{:05}.00000'.format(j))
    j += 1
if j == 0:
    print("no files found, exiting...")
    exit()

my_dpi = 96
fig = plt.figure(figsize=(800/my_dpi, 200/my_dpi), dpi=my_dpi)


print("reading image data from files...")
# read image data
ims = []
for map_file in map_files:
    f = fortranfile.FortranFile(map_file)
    [t, gamma] = f.readReals()
    [nx,ny,nvar,nstep] = f.readInts()
    dat = f.readReals()
    f.close()
    # f = FortranFile(map_file, 'r')
    # [t, gamma] = f.read_reals('f4')
    # [nx,ny,nvar,nstep] = f.read_ints('i')
    # dat = f.read_reals('f4')
    # f.close()

    dat = np.array(dat)
    dat = dat.reshape(nvar,ny,nx)

    # plot the map
    im = plt.imshow(dat[0,:,:].T,interpolation='nearest',origin='lower',animated=True) #cmap='hot')
    ims.append([im])

# animate
ani = animation.ArtistAnimation(fig, ims, interval=100, blit=False, repeat_delay=1000)


# needs ffmpeg to be installed
mywriter = animation.FFMpegWriter(fps=60)
#save animation
ani.save('dynamic_images.gif',writer='imagemagick')

plt.show()
