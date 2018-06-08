# # plot
# settings['animated'] = False
# fig = plt.figure(figsize=(800 / dpi, 800 / dpi), dpi=dpi)
#
# master_data = np.log10(master_data)
# ax = plt.subplot(411)
# ax.set_title('density')
# settings['vmin'] = np.min(master_data[0, :, :])
# settings['vmax'] = np.max(master_data[0, :, :])
# plt.imshow(np.transpose(master_data[0, :, :]), **settings)
# plt.ylabel('x')
#
# ax = plt.subplot(412)
# ax.set_title('x-velocity')
# plt.imshow(np.transpose(master_data[1, :, :]), **settings)
# plt.ylabel('x')
#
# ax = plt.subplot(413)
# ax.set_title('y-velocity')
# plt.imshow(np.transpose(master_data[2, :, :]), **settings)
# plt.ylabel('x')
#
# ax = plt.subplot(414)
# ax.set_title('pressure')
# settings['vmin'] = -2
# settings['vmax'] = -0.9
# im = plt.imshow(np.transpose(master_data[3, :, :]), **settings)
# plt.xlabel('y')
# plt.ylabel('x')
#
# fig.subplots_adjust(right=0.8)
# cbar_ax = fig.add_axes([0.85, 0.15, 0.05, 0.7])
# _min = settings['vmin']
# _max = settings['vmax']
# cbar = fig.colorbar(im, cax=cbar_ax, ticks=[_min, (_min+_max)/2, _max])
# cbar.ax.set_yticklabels(['Low', 'Medium', 'High'])
# plt.show()
# plt.savefig(dir / 'fig.png', dpi=dpi, frameon=False)