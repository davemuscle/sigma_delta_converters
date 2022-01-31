#!/usr/bin/python3

import os
import serial
import sys
import math
import time
from matplotlib.pyplot import *
from scipy.signal import *

from dad import *

def read_hw_uart(device, num_samples):
    ser = serial.Serial(device, 115200)
    print(ser.name)
    start = time.time()
    ser.write(b's')
    samples = [0]*num_samples
    for x in range(num_samples):
        line = ser.readline()
        line = line.decode('utf-8')
        line = line.strip()
        #print(line)
        samples[x] = int(line,16)
    end = time.time()
    ser.close()
    print("read from uart, time: ", end-start)
    return samples

def dft(samples, DFT_SIZE, SAMP_FREQ):
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

def filter(samples, samp_freq):
    nyq_rate = samp_freq / 2
    width = 3200/nyq_rate
    ripple_db = 60
    N, beta = kaiserord(ripple_db, width)
    cutoff_hz = 20000
    taps = firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))
    return lfilter(taps, 1.0, samples)

def get_amplitude(samples):
    low = samples[0]
    high = samples[0]
    for x in range(1, len(samples)):
        if(samples[x] < low):
            low = samples[x];
        if(samples[x] > high):
            high = samples[x];
    return high-low

def oneshot_run(freq, amp, uart_device, num_samples, filter=0):
    dad = DigilentAnalogDiscovery()
    dad.open_device()
    dad.wavegen_config_sine_out(freq=freq, amp=amp)
    samples = read_hw_uart(uart_device, num_samples)
    dad.close_device()

    for x in range(num_samples):
        samples[x] = samples[x] * vcc / (bosr*bosr) 
    amp = get_amplitude(samples)

    mid = sum(samples) / len(samples)
    
    print("Amplitude measured: " + str(amp))
    print("DC measured: " + str(mid))
    
    Xf, XM = dft(samples, num_samples, samp_freq)

    fig,axs = subplots(2,1)
    axs[0].plot(samples)
    axs[0].set_title("Hardware Data")
    axs[1].plot(Xf, XM)
    axs[1].set_title("FFT")

    if(filter):
        samples_filtered = filter(samples, samp_freq)
        Xf_f, XM_f = dft(samples_filtered, num_samples, samp_freq)
        fig,axs = subplots(2,1)
        axs[0].plot(samples_filtered)
        axs[0].set_title("Hardware Data Filtered")
        axs[1].plot(Xf_f, XM_f)
        axs[1].set_title("FFT")

    tight_layout()
    show()

#def bode_plot(samples, num_samples, samp_freq, bosr, vcc, filter):
        

func_freq = 440
func_amp = 0.5
num_samples = 1024
device = '/dev/ttyS2'
bosr = 1024
samp_freq = 50000000 / bosr
vcc = 2.5

start_freq = 220
num_steps = 5
log_step = 2.0**(1.0/12.0)

if(len(sys.argv) == 2 and sys.argv[1] == 'o'):
    oneshot_run(func_freq, func_amp, device, num_samples)
    exit()

if(len(sys.argv) == 2 and sys.argv[1] == 'f'):
    start_freq = 220
    freq = start_freq
    amp = 0.5
    log_step = 2.0**(1.0/12.0)
    num_steps = 30
    amps = [0]*num_steps
    freqs = [0]*num_steps
    dad = DigilentAnalogDiscovery()
    dad.open_device()
    for x in range(num_steps):
        print("Loop iteration: " + str(x) + " freq = ", str(freq))
        dad.wavegen_config_sine_out(freq=freq, amp=amp)
        samples = read_hw_uart(device, num_samples)
        for j in range(num_samples):
            samples[j] = samples[j] * vcc / (bosr*bosr) 
        amps[x] = get_amplitude(samples) / amp
        freqs[x] = freq
        freq = freq * log_step
    dad.close_device()
    figure()
    plot(freqs, amps)
    title("Bode Plot")
    tight_layout()
    show()



