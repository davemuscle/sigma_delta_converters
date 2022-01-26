#!/usr/bin/python3
import os
import glob
from matplotlib.pyplot import *
files = ['./tb_dumps/sigma_delta_adc_tb_input.txt', './tb_dumps/sigma_delta_adc_tb_output.txt']
arr = [[],[]]
file = 0
for x in files:
    figure(x)
    with open(x) as f:
        lines = f.readlines()
    cnt = 0
    for line in lines:
        cnt = cnt + 1
        line = line.strip()
        arr[file].append(float(line))
    file = file + 1

fig, axs = subplots(2,1)
for i in range(file):
    axs[i].plot(arr[i])
    axs[i].set_title(files[i])

show()
