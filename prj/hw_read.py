#!/usr/bin/python3

import os
import serial
import sys
import math
from matplotlib.pyplot import *
from scipy.signal import *

ser = serial.Serial('/dev/ttyS2', 115200)
print(ser.name)

num_samples = 1024
ser.write(b's')
samples = [0]*num_samples
for x in range(num_samples):
    line = ser.readline()
    line = line.decode('utf-8')
    line = line.strip()
    #print(line)
    samples[x] = int(line,16)

ser.close()


#for n in range(DFT_SIZE):
#    samples[n] = math.cos(2*3.14*n*440/SAMP_FREQ)*1000
DFT_SIZE = num_samples
SAMP_FREQ = 50000000 / 1024

def dft(samples_in, DFT_SIZE, SAMP_FREQ):
    XQ = [0]*DFT_SIZE
    XI = [0]*DFT_SIZE

    for k in range(DFT_SIZE):
        for n in range(DFT_SIZE):
            XQ[k] = XQ[k] + samples[n] * (math.cos(2*3.14*k*n/DFT_SIZE))
            XI[k] = XI[k] + samples[n] * -1 * (math.sin(2*3.14*k*n/DFT_SIZE))

    XM = [0]*((DFT_SIZE>>1)-1)
    Xf = [0]*((DFT_SIZE>>1)-1)

    for k in range(1, (DFT_SIZE>>1)-1):
        Xf[k] = k * SAMP_FREQ / DFT_SIZE
        XM[k] = math.sqrt(XQ[k]**2 + XI[k]**2)

    return Xf, XM

nyq_rate = SAMP_FREQ / 2
width = 3200/nyq_rate
ripple_db = 60
N, beta = kaiserord(ripple_db, width)
cutoff_hz = 20000
taps = firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))

fig,axs = subplots(2,2)
axs[0,0].plot(samples)
axs[0,0].set_title("Hardware Data")

Xf, XM = dft(samples, DFT_SIZE, SAMP_FREQ)

axs[0,1].plot(Xf, XM)
axs[0,1].set_title("FFT")

filtered = lfilter(taps, 1.0, samples)

axs[1,0].plot(filtered)
axs[1,0].set_title("Hardware Data Filtered")

Xf, XM = dft(filtered, DFT_SIZE, SAMP_FREQ)

axs[1,1].plot(Xf, XM)
axs[1,1].set_title("FFT")

tight_layout()
show()
