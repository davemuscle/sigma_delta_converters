#!/usr/bin/python3

import os
import serial
import sys
import math
import time
import random
from matplotlib.pyplot import *
from scipy.signal import *

from dad import *

class HwTest:
    
    def __init__(self):
        use_dad = 0
        self.set_FPGA_params()
        self.set_WVFM_params()

    # Set FPGA parameters to match HW build
    def set_FPGA_params(self,
                        num_samples=1024,
                        bosr=1024,
                        cic_stages=2,
                        bclk=50000000,
                        bits=24,
                        vcc=2.5,
                        signed_output=True,
                        uart='/dev/ttyS2',
                        baud=115200):
        self.FPGA_num_samples   = num_samples
        self.FPGA_bosr          = bosr
        self.FPGA_cic_stages    = cic_stages
        self.FPGA_bclk          = bclk
        self.FPGA_sclk          = bclk / bosr
        self.FPGA_bits          = bits
        self.FPGA_vcc           = vcc
        self.FPGA_signed_output = signed_output
        self.FPGA_uart          = uart
        self.FPGA_baud          = baud

    # Setup parameters of incoming signal for analysis
    def set_WVFM_params(self,
                        freq = 440,
                        amp=1.0,
                        sweep_start = 110,
                        sweep_mult = 2**(1.0/12.0),
                        sweep_steps = 80,
                        dft_size=1024):
        self.WVFM_freq        = freq
        self.WVFM_amp         = amp
        self.WVFM_sweep_start = sweep_start
        self.WVFM_sweep_steps = sweep_steps
        self.WVFM_sweep_mult  = sweep_mult
        self.WVFM_dft_size    = dft_size
        self.WVFM_dft_delta   = self.FPGA_sclk / self.WVFM_dft_size
        self.WVFM_dft_fbin    = round(self.WVFM_freq / self.WVFM_dft_delta)

    # Print out parameters for debug
    def dump_params(self):
        print('-'*20 + " FPGA Parameters " + '-'*20)
        print(f"*  {self.FPGA_num_samples   = }")
        print(f"*  {self.FPGA_bosr          = }")
        print(f"*  {self.FPGA_cic_stages    = }")
        print(f"*  {self.FPGA_bclk          = }")
        print(f"*  {self.FPGA_sclk          = }")
        print(f"*  {self.FPGA_bits          = }")
        print(f"*  {self.FPGA_vcc           = }")
        print(f"*  {self.FPGA_signed_output = }")
        print(f"*  {self.FPGA_uart          = }")
        print(f"*  {self.FPGA_baud          = }")

        print('-'*20 + " WVFM Parameters " + '-'*20)
        print(f"*  {self.WVFM_freq        = }")
        print(f"*  {self.WVFM_amp         = }")
        print(f"*  {self.WVFM_sweep_start = }")
        print(f"*  {self.WVFM_sweep_steps = }")
        print(f"*  {self.WVFM_sweep_mult  = }")
        print(f"*  {self.WVFM_dft_size    = }")
        print(f"*  {self.WVFM_dft_fbin    = }")

    # Use Digilent Device
    def open_dad(self):
        self.dad = DigilentAnalogDiscovery()
        self.dad.open_device()
        self.use_dad = 1

    def close_dad(self):
        if(self.use_dad):
            self.dad.close_device()

    def setup_dad_waveform(self):
        if(self.use_dad):
            self.dad.wavegen_config_sine_out(freq=self.WVFM_freq, amp=self.WVFM_amp)
    
    # Read lines from FPGA serial port, can lock up easily
    def read_serial(self):
        ser = serial.Serial(self.FPGA_uart, self.FPGA_baud)
        ser.write(b's')
        lines = []
        for i in range(self.FPGA_num_samples):
            lines.append(ser.readline())
        ser.close()
        return lines

    # Convert ascii lines to integers
    def decode_serial(self, lines):
        samples = []
        for line in lines:
            decoded_stripped = line.decode('utf-8')
            decoded_stripped = decoded_stripped.strip()
            integer = int(line, 16)
            if(self.FPGA_signed_output == True and (integer & (1 << self.FPGA_bits-1))):
                integer -= (1 << self.FPGA_bits)
            samples.append(integer)
        return samples

    # Convert digital output to float voltage value
    def get_voltages(self, samples):
        voltages = []
        for sample in samples:
            v = sample * self.FPGA_vcc
            for i in range(self.FPGA_cic_stages):
                v /= self.FPGA_bosr
            voltages.append(v)
        return voltages
    
    # Convert array of samples to single amplitude = peak-peak / 2
    def get_amplitude(self, samples):
        low = samples[0]
        high = samples[0]
        for x in range(1, len(samples)):
            if(samples[x] < low):
                low = samples[x];
            if(samples[x] > high):
                high = samples[x];
        return ((high-low)/2)

    # Get DC value
    def get_dc(self, samples):
        return (sum(samples)/len(samples))

    # Get RMS of the set
    def get_rms(self, samples):
        sq_sum = 0
        for x in samples:
            sq_sum += (x**2)
        sq_sum /= len(samples)
        return math.sqrt(sq_sum)

    # Calculate DFT, skips DC bin
    def get_dft(self, samples):
        XQ = [0]*self.WVFM_dft_size
        XI = [0]*self.WVFM_dft_size

        for k in range(self.WVFM_dft_size):
            for n in range(self.FPGA_num_samples):
                XQ[k] = XQ[k] + samples[n] * (math.cos(2*3.14*k*n/self.WVFM_dft_size))
                XI[k] = XI[k] + samples[n] * -1 * (math.sin(2*3.14*k*n/self.WVFM_dft_size))

        XM   = [0]*((self.WVFM_dft_size>>1)-1)
        Xf   = [0]*((self.WVFM_dft_size>>1)-1)
        XM_l = [0]*len(XM)

        sample_freq = self.FPGA_bclk / self.FPGA_bosr

        for k in range((self.WVFM_dft_size>>1)-1):
            Xf[k] = k * sample_freq / self.WVFM_dft_size
            XM[k] = math.sqrt(XQ[k+1]**2 + XI[k+1]**2) / (self.WVFM_dft_size/2)
            XM_l[k] = 20*math.log10(XM[k] / hw.WVFM_amp)

        return Xf, XM, XM_l

    # Get frequency closest to DFT bin 
    def match_dft_bin_freq(self):
        self.WVFM_freq = self.WVFM_dft_fbin * self.WVFM_dft_delta

    # Get signal-to-noise ratio via DFT magnitudes
    def get_snr(self, mags):
        idx = self.WVFM_dft_fbin - 1
        top = mags[idx]
        mags[idx] = 0
        low = self.get_rms(mags)
        mags[idx] = top
        return 20*math.log10(top/low)



def filter(samples, samp_freq):
    nyq_rate = samp_freq / 2
    width = 3200/nyq_rate
    ripple_db = 60
    N, beta = kaiserord(ripple_db, width)
    cutoff_hz = 20000
    taps = firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))
    return lfilter(taps, 1.0, samples)

def test_normal(hw):
    # config device, setup wavegen
    hw.open_dad()
    hw.setup_dad_waveform()
    time.sleep(0.1)
    # read sample buffer, convert to voltage
    samples = hw.decode_serial(hw.read_serial())
    voltages = hw.get_voltages(samples)
    # get output results
    amplitude = hw.get_amplitude(voltages)
    dc = hw.get_dc(voltages)
    rms = hw.get_rms(voltages)
    dft_freqs, dft_mags, dft_mags_log = hw.get_dft(voltages)
    # show params
    hw.dump_params()
    # print results
    print('-'*20 + " Normal Test Result " + '-'*20)
    print("*  Amp: " + str(amplitude))
    print("*   DC: " + str(dc))
    print("*  RMS: " + str(rms))
    print("*  Max: " + str(max(voltages)))
    print("*  Min: " + str(min(voltages)))
    # plot
    subplot(211)
    plot(voltages)
    grid()
    title("Hardware Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(212)
    plot(dft_freqs, dft_mags_log)
    xscale('log')
    grid()
    title("FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dB)')
    tight_layout()
    show()
    hw.close_dad()

def test_measurement(hw):
    # config device
    hw.open_dad()
    # get the next available frequency based on FFT
    hw.match_dft_bin_freq();

    # record ambient noise
    ambient_samples = hw.decode_serial(hw.read_serial())

    # create clean signal then record it
    custom_len = round(hw.FPGA_sclk / hw.WVFM_freq)
    hw.dad.setup_custom_data(custom_len)
    for i in range(custom_len):
        hw.dad.custom_data[i] = math.cos(2*3.14*hw.WVFM_freq*i/hw.FPGA_sclk)
    hw.dad.wavegen_config_custom_out(0, hw.WVFM_freq, hw.WVFM_amp, 0)
    time.sleep(0.1)
    clean_samples = hw.decode_serial(hw.read_serial())

    # add noise clean signal then record it
    noise_amp = 0.1
    for i in range(custom_len):
        noise = noise_amp*random.randrange(-100,100,1)/100
        hw.dad.custom_data[i] += noise
    hw.dad.wavegen_config_custom_out(0, hw.WVFM_freq, hw.WVFM_amp, 0)
    time.sleep(0.1)
    dirty_samples = hw.decode_serial(hw.read_serial())
   
    # gather measurements
    ambient_voltages = hw.get_voltages(ambient_samples)
    clean_voltages = hw.get_voltages(clean_samples)
    dirty_voltages = hw.get_voltages(dirty_samples)

    ambient_amp = hw.get_amplitude(ambient_voltages)
    clean_amp   = hw.get_amplitude(clean_voltages)
    dirty_amp   = hw.get_amplitude(dirty_voltages)
    
    ambient_dc = hw.get_dc(ambient_voltages)
    clean_dc   = hw.get_dc(clean_voltages)
    dirty_dc   = hw.get_dc(dirty_voltages)

    ambient_rms = hw.get_rms(ambient_voltages)
    clean_rms   = hw.get_rms(clean_voltages)
    dirty_rms   = hw.get_rms(dirty_voltages)

    ambient_dft_freqs, ambient_dft_mags, ambient_dft_mags_log = hw.get_dft(ambient_voltages)
    clean_dft_freqs, clean_dft_mags, clean_dft_mags_log       = hw.get_dft(clean_voltages)
    dirty_dft_freqs, dirty_dft_mags, dirty_dft_mags_log       = hw.get_dft(dirty_voltages)

    clean_snr = hw.get_snr(clean_dft_mags)
    dirty_snr = hw.get_snr(dirty_dft_mags)

    # print out
    hw.dump_params()

    print('-'*20 + " Ambient Results " + '-'*20)
    print("*  Amp(V): " + str(ambient_amp))
    print("*   DC(V): " + str(ambient_dc))
    print("*  RMS(V): " + str(ambient_rms))
    print("*  Max(V): " + str(max(ambient_voltages)))
    print("*  Min(V): " + str(min(ambient_voltages)))
    print('-'*20 + " Clean Results " + '-'*20)
    print("*  Amp (V): " + str(clean_amp))
    print("*   DC (V): " + str(clean_dc))
    print("*  RMS (V): " + str(clean_rms))
    print("*  Max (V): " + str(max(clean_voltages)))
    print("*  Min (V): " + str(min(clean_voltages)))
    print("*  SNR (dB): " + str(clean_snr))
    print('-'*20 + " Noisy Results " + '-'*20)
    print("*  Amp (V): " + str(dirty_amp))
    print("*   DC (V): " + str(dirty_dc))
    print("*  RMS (V): " + str(dirty_rms))
    print("*  Max (V): " + str(max(dirty_voltages)))
    print("*  Min (V): " + str(min(dirty_voltages)))
    print("*  SNR (dB): " + str(dirty_snr))

    # plot
    subplot(321)
    plot(ambient_voltages)
    grid()
    title("Ambient Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(322)
    plot(ambient_dft_freqs, ambient_dft_mags_log)
    title("Ambient FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dB)')
    xscale('log')
    grid()
    
    subplot(323)
    plot(clean_voltages)
    grid()
    title("Clean Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(324)
    plot(clean_dft_freqs, clean_dft_mags_log)
    title("Clean FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dB)')
    xscale('log')
    grid()

    subplot(325)
    plot(dirty_voltages)
    grid()
    title("Noisy Data")
    xlabel('Samples')
    ylabel('Voltage(V)')
    subplot(326)
    plot(dirty_dft_freqs, dirty_dft_mags_log)
    title("Noisy FFT")
    xlabel('Frequency (Hz)')
    ylabel('Magnitude (dB)')
    xscale('log')
    grid()

    tight_layout()
    show()
    # close device
    hw.close_dad()

       
hw = HwTest()
#test_normal(hw)
test_measurement(hw)

#if(len(sys.argv) == 2 and sys.argv[1] == 'o'):
#    oneshot_run(func_freq, func_amp, device, num_samples, signed, 0)
#    exit()
#
#if(len(sys.argv) == 2 and sys.argv[1] == 'f'):
#    start_freq = 110
#    freq = start_freq
#    amp = 0.5
#    log_step = 2.0**(1.0/12.0)
#    num_steps = 90
#    amps = [0]*num_steps
#    freqs = [0]*num_steps
#    dad = DigilentAnalogDiscovery()
#    dad.open_device()
#    for x in range(num_steps):
#        print("Loop iteration: " + str(x) + " freq = ", str(freq))
#        dad.wavegen_config_sine_out(freq=freq, amp=amp)
#        samples = read_hw_uart(device, num_samples)
#        for j in range(num_samples):
#            samples[j] = samples[j] * vcc / (bosr*bosr) 
#        amps[x] = get_amplitude(samples) / amp
#        freqs[x] = freq
#        freq = freq * log_step
#    dad.close_device()
#    figure()
#    plot(freqs, amps)
#    ylim([0, 1.5])
#    title("Bode Plot")
#    tight_layout()
#    show()



