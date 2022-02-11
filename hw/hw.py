#!/usr/bin/python3

import serial
import time
import random
import argparse

from matplotlib.pyplot import *

from DigilentAnalogDiscovery import *
from Signal import *

# constants for ADC inst
ADC_OVERSAMPLE_RATE = 1024
ADC_CIC_STAGES      = 2
ADC_BITLEN          = 24
ADC_SIGNED_OUTPUT   = False

# constants for FPGA build
FPGA_NUM_SAMPLES = 1024
FPGA_BCLK        = 50000000
FPGA_UART        = '/dev/ttyS2'
FPGA_BAUD        = 115200
FPGA_VCC         = 3.3

# waveform with overrides that can change via cmdline
waveform_frequency   = 440.0
waveform_amplitude   = 1.0
waveform_sweep_start = 220.0
waveform_sweep_end   = 60000.0
waveform_sweep_steps = 40
waveform_dft_size    = 1024

# Read lines from FPGA serial port, can lock up easily
def read_serial():
    ser = serial.Serial(FPGA_UART, FPGA_BAUD)
    ser.write(b's')
    samples = []
    for i in range(FPGA_NUM_SAMPLES):
        line = ser.readline()
        decoded_stripped = line.decode('utf-8')
        decoded_stripped = decoded_stripped.strip()
        integer = int(line, 16)
        if(ADC_SIGNED_OUTPUT == True and (integer & (1 << ADC_BITLEN-1))):
            integer -= (1 << ADC_BITLEN)
        samples.append(integer)
    ser.close()
    return samples

# Convert digital output to float voltage value
def get_voltages(samples):
    voltages = []
    for sample in samples:
        v = sample * FPGA_VCC
        for i in range(ADC_CIC_STAGES):
            v /= ADC_OVERSAMPLE_RATE
        voltages.append(v)
    return voltages

# Display whatever is on the pin
def Test_Read():

    samples = read_serial()
    voltages = get_voltages(samples)
    
    samplerate = FPGA_BCLK / ADC_OVERSAMPLE_RATE
    
    dft_real, dft_imag = get_dft(voltages, samplerate, waveform_dft_size)
    dft_freqs, dft_mags = get_dft_mags((dft_real, dft_imag), samplerate, waveform_dft_size)
    dft_mags_log10 = [20*np.log10(i/1.0) for i in dft_mags]
    
    subplot(211)
    plot(voltages)
    grid()
    title("Hardware Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(212)
    plot(dft_freqs, dft_mags_log10)
    xscale('log')
    grid()
    title("FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dBV)')
    tight_layout()
    show()

# send in a signal, record it, and print/plot the result and FFT
def Test_Sine():

    dad = DigilentAnalogDiscovery() 
    dad.open_device()
    dad.wavegen_config_sine_out(freq = waveform_frequency, amp = waveform_amplitude)
    time.sleep(0.1)

    samples = read_serial()
    voltages = get_voltages(samples)

    dad.close_device()
    
    amplitude = get_amplitude(voltages)
    dc = get_dc(voltages)
    rms = get_rms(voltages)
    
    samplerate = FPGA_BCLK / ADC_OVERSAMPLE_RATE

    dft_real, dft_imag = get_dft(voltages, samplerate, waveform_dft_size)
    dft_freqs, dft_mags = get_dft_mags((dft_real, dft_imag), samplerate, waveform_dft_size)
    dft_mags_log10 = [20*np.log10(i/waveform_amplitude) for i in dft_mags]

    print('-'*20 + " Test Result " + '-'*20)
    print("* Freq: " + str(waveform_frequency))
    print("*  Amp: " + str(amplitude))
    print("*   DC: " + str(dc))
    print("*  RMS: " + str(rms))
    print("*  Max: " + str(max(voltages)))
    print("*  Min: " + str(min(voltages)))
    
    subplot(211)
    plot(voltages)
    grid()
    title("Hardware Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(212)
    plot(dft_freqs, dft_mags_log10)
    xscale('log')
    grid()
    title("FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dB)')
    tight_layout()
    show()

# record ambient noise, a clean signal, and a noisy signal then print/plot results
def Test_Measure():

    samplerate = FPGA_BCLK / ADC_OVERSAMPLE_RATE
    freq = set_frequency_to_dft_bin(waveform_frequency, samplerate, waveform_dft_size)
    samples = [[]]*3
    
    dad = DigilentAnalogDiscovery() 
    dad.open_device()
    time.sleep(0.1)

    # ambient
    samples[0] = read_serial()

    # create clean signal then record it
    custom_len = round(samplerate / freq)
    dad.setup_custom_data(custom_len)
    for i in range(custom_len):
        dad.custom_data[i] = np.cos(2*3.14*freq*i/samplerate)
    dad.wavegen_config_custom_out(0, freq, waveform_amplitude, 0)
    time.sleep(0.1)

    # clean
    samples[1] = read_serial()

    # add noise clean signal then record it
    noise_amp = 0.1
    for i in range(custom_len):
        noise = noise_amp*random.randrange(-100,100,1)/100
        dad.custom_data[i] += noise
    dad.wavegen_config_custom_out(0, freq, waveform_amplitude, 0)
    time.sleep(0.1)
    # noisy
    samples[2] = read_serial()
    dad.close_device()

    voltage = [[]]*3
    amplitude = [0]*3
    dc = [0]*3
    rms = [0]*3
    dft = [()]*3
    dft_mags_log10 = [[]]*3
    snr = [0]*3
    thdn = [0]*3
    titles = ['Ambient', 'Clean', 'Noisy']

    for i in range(3):
        voltage[i] = get_voltages(samples[i])
        amplitude[i] = get_amplitude(voltage[i])
        dc[i] = get_dc(voltage[i])
        rms[i] = get_rms(voltage[i])
        dft[i] = get_dft_mags(get_dft(voltage[i], samplerate, waveform_dft_size), samplerate, waveform_dft_size)
        dft_mags_log10[i] = [20*np.log10(i/waveform_amplitude) for i in dft[i][1]]
        snr[i] = get_snr(dft[i][1])
        thdn[i] = get_thdn(dft[i][1], freq, waveform_dft_size, samplerate)

        print('-'*20 + " " + titles[i] + " Results " + '-'*20)
        print("*  Amp(V): " + str(amplitude[i]))
        print("*   DC(V): " + str(dc[i]))
        print("*  RMS(V): " + str(rms[i]))
        print("*  Max(V): " + str(max(voltage[i])))
        print("*  Min(V): " + str(min(voltage[i])))
        print("*  SNR (dB): " + str(snr[i]))
        print("*  THDN  : " + str(thdn[i]))

        subplot(320 + (i*2) + 1)
        plot([i+1 for i in range(len(voltage[i]))], voltage[i])
        grid()
        title(titles[i] + " Data")
        xlabel('Samples')
        ylabel('Voltage(V)')
        subplot(320 + (i*2)+2)
        plot(dft[i][0], dft_mags_log10[i])
        title(titles[i] + " FFT")
        xlabel('Frequency (Hz)')
        ylabel('Magnitude (dB)')
        xscale('log')
        grid()

    tight_layout()
    show()
       
def Test_Bode():
    # build up list of frequencies
    freqs = get_sweep(waveform_sweep_start, waveform_sweep_end, waveform_sweep_steps)
    amplitudes = []

    dad = DigilentAnalogDiscovery()
    dad.open_device()

    # record samples for each freq and store amplitude
    for freq in freqs:
        dad.wavegen_config_sine_out(freq = freq, amp = waveform_amplitude, offset=0)
        time.sleep(0.1)
        amplitudes.append(get_amplitude(get_voltages(read_serial())))

    dad.close_device()

    # convert amplitudes to gain in dB
    for i in range(waveform_sweep_steps):
        amplitudes[i] = 20*np.log(amplitudes[i] / waveform_amplitude) 

    # plot
    plot(freqs, amplitudes)
    xscale('log')
    title('Bode Plot')
    xlabel('Frequency (Hz)')
    ylabel('Gain (dB)')
    show()
    tight_layout()

# parse args
parser = argparse.ArgumentParser(description = 'Hardware Test Script for ADC')
parser.add_argument('--mode', metavar='mode',        nargs=1, help = 'mode = [read, sine, measure, bode]')
parser.add_argument('--freq', metavar='frequency',   nargs=1, help = 'waveform frequency')
parser.add_argument('--amp',  metavar='amplitude',   nargs=1, help = 'waveform amplitude')
parser.add_argument('--start',metavar='sweep_start', nargs=1, help = 'waveform sweep start frequency')
parser.add_argument('--end',  metavar='sweep_end',   nargs=1, help = 'waveform sweep end frequency')
parser.add_argument('--steps',metavar='sweep_steps', nargs=1, help = 'waveform sweep steps')
parser.add_argument('--dft',  metavar='dft_size',    nargs=1, help = 'dft size')
args = parser.parse_args()

# overrides to waveform parameters
if(args.freq):
    waveform_frequency = float(args.freq[0])
if(args.amp):
    waveform_amplitude = float(args.amp[0])
if(args.start):
    waveform_sweep_start = float(args.start[0])
if(args.end):
    waveform_sweep_end = float(args.end[0])
if(args.steps):
    waveform_sweep_steps = int(args.steps[0])
if(args.dft):
    waveform_dft_size = int(args.steps[0])

# run the script
if(args.mode[0] == 'read'):
    Test_Read()
if(args.mode[0] == 'sine'):
    Test_Sine()
if(args.mode[0] == 'measure'):
    Test_Measure()
if(args.mode[0] == 'bode'):
    Test_Bode()
