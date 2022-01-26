#!/usr/bin/python3
import os
import glob
from matplotlib.pyplot import *
files = glob.glob("./tb_signals/adc_tb_*.txt")
for x in files:
    figure(x)
    with open(x) as f:
        lines = f.readlines()
    y = []
    cnt = 0
    for line in lines:
        cnt = cnt + 1
        line = line.strip()
        y.append(float(line))
    plot(y)

show()
