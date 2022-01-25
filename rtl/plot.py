#!/usr/bin/python3

from matplotlib.pyplot import *
for x in ["adc_tb_input.txt", "adc_tb_output.txt"]:
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
