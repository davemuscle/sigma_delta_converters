#!/usr/bin/python3
import os
import glob
from matplotlib.pyplot import *
path = "./tb_dumps";
files = sorted(glob.glob('./tb_dumps/*.txt'))
num_files = len(files)
x_arr = []
y_arr = []
file = 0
cnt = 0
fig, axs = subplots(num_files,1)
for x in files:
    x_arr.clear()
    y_arr.clear()
    file = open(x, "r")
    lines = file.readlines()
    line = lines.pop(0)
    line = line.split(',')
    axs[cnt].set(xlabel = line[0], ylabel = line[1])

    for line in lines:
        line = line.strip()
        line = line.split(',')
        x_arr.append(float(line[0]))
        y_arr.append(float(line[1]))

    file.close()
    axs[cnt].plot(x_arr, y_arr)
    axs[cnt].set_title(x)
    cnt = cnt + 1

tight_layout()
show()
