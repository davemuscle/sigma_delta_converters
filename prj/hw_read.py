#!/usr/bin/python3

import os
import serial
import sys
import math
from matplotlib.pyplot import *

ser = serial.Serial('/dev/ttyS2', 115200)
print(ser.name)

num_samples = 1024
ser.write(b's')
samples = [0]*1024
for x in range(num_samples):
    line = ser.readline()
    line = line.decode('utf-8')
    line = line.strip()
    #print(line)
    samples[x] = int(line,16)

ser.close()

DFT_SIZE = num_samples
SAMP_FREQ = 50000000 / 1024
XQ = [0]*DFT_SIZE
XI = [0]*DFT_SIZE

#for n in range(DFT_SIZE):
#    samples[n] = math.cos(2*3.14*n*440/SAMP_FREQ)*1000

for k in range(DFT_SIZE):
    for n in range(DFT_SIZE):
        XQ[k] = XQ[k] + samples[n] * (math.cos(2*3.14*k*n/DFT_SIZE))
        XI[k] = XI[k] + samples[n] * -1 * (math.sin(2*3.14*k*n/DFT_SIZE))

XM = [0]*DFT_SIZE;
Xf = [0]*DFT_SIZE

for k in range(DFT_SIZE):
    Xf[k] = k * SAMP_FREQ / DFT_SIZE
    XM[k] = math.sqrt(XQ[k]**2 + XI[k]**2)


fig,axs = subplots(1,2)
axs[0].plot(samples)
axs[0].set_title("Hardware Data")
axs[1].plot(Xf, XM)
axs[1].set_title("FFT")
show()
