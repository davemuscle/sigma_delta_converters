#!/usr/bin/python3
import os
import glob
from matplotlib.pyplot import *
path = "./tb_dumps";
files = sorted(glob.glob('./tb_dumps/*.txt'))
num_files = len(files)
arr = []
file = 0
cnt = 0
fig, axs = subplots(num_files,1)
for x in files:
    arr.clear()
    file = open(x, "r")
    for line in file.readlines():
        line = line.strip()
        arr.append(float(line))
    file.close()
    axs[cnt].plot(arr)
    axs[cnt].set_title(x)
    cnt = cnt + 1

tight_layout()
show()
