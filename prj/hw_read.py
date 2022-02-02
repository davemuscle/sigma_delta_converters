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

    def dump_params(self):
        print('-'*20 + " FPGA Parameters " + '-'*20)
        print(f"*  {self.FPGA_num_samples   = }")
        print(f"*  {self.FPGA_bosr          = }")
        print(f"*  {self.FPGA_cic_stages    = }")
        print(f"*  {self.FPGA_bclk          = }")
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
        # has to match FPGA
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

        XM = [0]*((self.WVFM_dft_size>>1)-1)
        Xf = [0]*((self.WVFM_dft_size>>1)-1)

        sample_freq = self.FPGA_bclk / self.FPGA_bosr

        for k in range((self.WVFM_dft_size>>1)-1):
            Xf[k] = k * sample_freq / self.WVFM_dft_size
            XM[k] = math.sqrt(XQ[k+1]**2 + XI[k+1]**2) / self.WVFM_dft_size

        return Xf, XM
    
    # Crude SFDR function
    def get_sfdr(self, mags):
        highest = mags[0]
        highest_idx = 0
        highest2nd = mags[0]
        highest2nd_idx = 0
        for i in range(1,len(mags)):
            if(mags[i] > highest):
                highest_idx = i
                highest = mags[i]
        for i in range(0,len(mags)):
            if(i != highest_idx and mags[i] > highest2nd):
                highest2nd = mags[i]
                highest2nd_idx = i
        return highest, highest2nd



def filter(samples, samp_freq):
    nyq_rate = samp_freq / 2
    width = 3200/nyq_rate
    ripple_db = 60
    N, beta = kaiserord(ripple_db, width)
    cutoff_hz = 20000
    taps = firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))
    return lfilter(taps, 1.0, samples)


def oneshot_run(freq, amp, uart_device, num_samples, signed=0, filter=0):

    if(filter):
        samples_filtered = filter(samples, samp_freq)
        Xf_f, XM_f = dft(samples_filtered, num_samples, samp_freq)
        fig,axs = subplots(2,1)
        axs[0].plot(samples_filtered)
        axs[0].set_title("Hardware Data Filtered")
        axs[1].plot(Xf_f, XM_f)
        axs[1].set_title("FFT")


#def bode_plot(samples, num_samples, samp_freq, bosr, vcc, filter):
def oneshot(hw):
    # config device
    hw.open_dad()
    #hw.setup_dad_waveform()
    
    samp_clk = hw.FPGA_bclk / hw.FPGA_bosr
    custom_len = round(samp_clk / hw.WVFM_freq)
    hw.dad.setup_custom_data(custom_len)
    # create noise signal
    noise_amp = 0.1
    for i in range(custom_len):
        noise = noise_amp*random.randrange(-100,100,1)/100
        hw.dad.custom_data[i] += noise
    
    # get rms of the noise only
    hw.dad.wavegen_config_custom_out(0, hw.WVFM_freq, hw.WVFM_amp, 0)
    time.sleep(0.1)
    samples = hw.decode_serial(hw.read_serial())
    noise_voltages = hw.get_voltages(samples)
    noise_rms = hw.get_rms(noise_voltages)

    # add in the signal (sine wave)
    for i in range(custom_len):
        hw.dad.custom_data[i] += math.cos(2*3.14*hw.WVFM_freq*i/samp_clk)

    hw.dad.wavegen_config_custom_out(0, hw.WVFM_freq, hw.WVFM_amp, 0)
    time.sleep(0.1)
    #hw.dad.wavegen_config_sine_out(freq=hw.WVFM_freq, amp=hw.WVFM_amp)

    # read sample buffer
    samples = hw.decode_serial(hw.read_serial())
    # convert
    voltages = hw.get_voltages(samples)
    amplitude = hw.get_amplitude(voltages)
    dc = hw.get_dc(voltages)
    rms = hw.get_rms(voltages)
    # get dft
    dft_freqs, dft_mags = hw.get_dft(voltages)
    # show params
    hw.dump_params()
    # print
    print("Amplitude: " + str(amplitude))
    print("DC: " + str(dc))
    print("RMS: " + str(rms))
    print("RMS Noise: "+ str(noise_rms))
    print("SNR: " + str((rms**2)/(noise_rms**2)))
    # plot
    subplot(311)
    plot(noise_voltages)
    title("Noise")
    subplot(312)
    plot(voltages)
    title("Hardware Data")
    subplot(313)
    plot(dft_freqs, dft_mags)
    title("FFT")
    tight_layout()
    show()
    hw.close_dad()
        
hw = HwTest()
oneshot(hw)

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



