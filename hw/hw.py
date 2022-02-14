#!/usr/bin/python3

from serial import Serial
from time import sleep
from random import randrange
from argparse import ArgumentParser

from matplotlib.pyplot import *

from scipy.fft import fft
from scipy.fftpack import fftfreq

from DigilentAnalogDiscovery import *

class HwTest:
    # constants for ADC inst
    ADC_OVERSAMPLE_RATE = 1024
    ADC_CIC_STAGES      = 2
    ADC_BITLEN          = 20
    
    # constants for FPGA build
    FPGA_NUM_SAMPLES = 4096
    FPGA_BCLK        = 50000000
    FPGA_UART        = '/dev/ttyS2'
    FPGA_BAUD        = 115200
    FPGA_VCC         = 3.3
    FPGA_SAMPLERATE  = FPGA_BCLK/ADC_OVERSAMPLE_RATE
    
    # waveform with overrides that can change via cmdline
    waveform_frequency   = 440.0
    waveform_amplitude   = 1.0
    waveform_sweep_start = 220.0
    waveform_sweep_end   = 60000.0
    waveform_sweep_steps = 40
    waveform_dft_size    = 1024
    waveform_offset      = FPGA_VCC/2
    
    # Read lines from FPGA serial port, can lock up easily
    def read_serial(self, raw=False):
        ser = Serial(self.FPGA_UART, self.FPGA_BAUD)
        ser.write(b's')
        samples = []
        for i in range(self.FPGA_NUM_SAMPLES):
            line = ser.readline()
            decoded_stripped = line.decode('utf-8')
            decoded_stripped = decoded_stripped.strip()
            integer = int(line, 16)
            samples.append(integer)
        ser.close()
        # convert digital to voltage
        if(raw == True):
            return samples
        voltages = []
        for sample in samples:
            v = sample * self.FPGA_VCC
            for i in range(self.ADC_CIC_STAGES):
                v /= self.ADC_OVERSAMPLE_RATE
            voltages.append(v)
        return voltages

    # calculate and return FFT freq,magnitudes
    def get_spectral_analysis(self, samples, log=True):
        # take fft
        fft_out = fft(samples, n = self.waveform_dft_size, norm = "forward")
        # cutout dc and Fs/2 bins
        fft_out = fft_out[1:len(fft_out)>>1]
        # scale to match input range for only real-valued samples
        fft_out *= 2
        
        # calc mags
        dft_mags = np.abs(fft_out)
        # calc freqs
        dft_freqs = fftfreq(self.waveform_dft_size, 1/float(self.FPGA_SAMPLERATE))
        # cutout dc and Fs/2 bins
        dft_freqs = dft_freqs[1:len(dft_freqs)>>1]
        if(log == True):
            return (dft_freqs, [20*np.log10(i/self.waveform_amplitude) for i in dft_mags])
        else:
            return (dft_freqs, dft_mags)

    # calculate signal amplitude, dc, rms values
    def get_signal_properties(self, samples):
        # amplitude
        amp = (max(samples) - min(samples)) / 2
        # dc
        dc = sum(samples)/len(samples)
        # rms
        rms = 0
        for x in samples:
            rms += (x**2)
        rms /= len(samples)
        rms = np.sqrt(rms)
        return amp, dc, rms

    # calculate SNR, THD+N
    def get_signal_qualities(self, magnitudes):
        # snr
        mags_copy = [i for i in magnitudes]
        idx = mags_copy.index(max(mags_copy))
        top = mags_copy[idx]
        mags_copy[idx] = 0
        a,b,rms = self.get_signal_properties(mags_copy)
        snr = 20*np.log10(top/rms)
        # thd+n
        mags_copy = [i for i in magnitudes]
        idx = mags_copy.index(max(mags_copy))
        fundamental = mags_copy[idx]
        mags_copy[idx] = 0
        sum_harmonics = 0
        harmonic = 2
        curr_freq = self.waveform_frequency * harmonic
        delta = self.FPGA_SAMPLERATE / self.waveform_dft_size
        while(curr_freq < self.FPGA_SAMPLERATE/2):
            curr_idx = int(round(float(curr_freq)/float(delta)))
            sum_harmonics = sum_harmonics + mags_copy[curr_idx]
            mags_copy[curr_idx] = 0
            harmonic += 1
            curr_freq = self.waveform_frequency * harmonic
        a,b,noise = self.get_signal_properties(mags_copy)
        thdn = (sum_harmonics + noise)/fundamental
        return snr, thdn

    # send in a signal, record it, and print/plot the result and FFT
    def test_sine(self, use_dad=True):

        fullscale = (2**(self.ADC_BITLEN))-1
        
        if(use_dad):
            dad = DigilentAnalogDiscovery() 
            dad.open_device()
            dad.wavegen_config_sine_out(freq = self.waveform_frequency, amp = self.waveform_amplitude, offset = self.waveform_offset)
            sleep(0.1)
        else:
            self.waveform_amplitude = 1.0
        samples = self.read_serial(raw=True)
        if(use_dad):
            dad.close_device()
        
        voltages = [x*self.FPGA_VCC / fullscale for x in samples]
        amplitude, dc, rms = self.get_signal_properties(samples)
        amplitude_v, dc_v, rms_v = self.get_signal_properties(voltages)
        freqs, mags = self.get_spectral_analysis(voltages, log=False)
        snr, thdn = self.get_signal_qualities(mags)
        mags = [20*np.log10(i/self.waveform_amplitude) for i in mags]
        max_s = max(samples)
        min_s = min(samples)
        max_s_v = max_s * self.FPGA_VCC / fullscale
        min_s_v = min_s * self.FPGA_VCC / fullscale

        print('-'*20 + " Test Result " + '-'*20)
        if(use_dad):
            print("* Freq: %0.3f" % (self.waveform_frequency))
        print("*  Amp: %8d = %.3f V" % (amplitude, amplitude_v))
        print("*   DC: %8d = %.3f V" % (dc, dc_v))
        print("*  RMS: %8d = %.3f V" % (rms, rms_v))
        print("*  Max: %8d = %.3f V" % (max_s, max_s_v))
        print("*  Min: %8d = %.3f V" % (min_s, min_s_v))
        print("*  SNR: %f (dB)" % (snr))
        print("* THDN: %f" % (thdn))
        subplot(211)
        plot(samples)
        grid()
        title("Hardware Data")
        xlabel('Samples')
        ylabel('Digital Value')
        subplot(212)
        plot(freqs, mags)
        xscale('log')
        grid()
        title("FFT")
        xlabel('Frequency (Hz)')
        if(use_dad):
            ylabel('Magnitude (dB)')
        else:
            ylabel('Magnitude (dBV)')

        tight_layout()
        show()

    # record ambient noise, a clean signal, and a noisy signal then print/plot results
    def test_measure(self):

        delta = self.FPGA_SAMPLERATE / self.waveform_dft_size
        fbin = round(self.waveform_frequency / delta)
        self.waveform_frequency = fbin*delta

        titles = ['Ambient', 'Clean', 'Noisy']
        noise_amp = 0.1 

        dad = DigilentAnalogDiscovery() 
        dad.open_device()
        
        custom_len = round(self.FPGA_SAMPLERATE / self.waveform_frequency)
        dad.setup_custom_data(custom_len)

        for i in range(3):
            for n in range(custom_len):
                if(i == 0):
                    dad.custom_data[n] = 0
                if(i == 1):
                    dad.custom_data[n] = np.cos(2*3.14*self.waveform_frequency*n/self.FPGA_SAMPLERATE)
                if(i == 2):
                    dad.custom_data[n] += noise_amp*randrange(-100,100,1)/100

            dad.wavegen_config_custom_out(0, self.waveform_frequency, self.waveform_amplitude, self.waveform_offset)
            sleep(0.1)
            samples = self.read_serial()

            
            amplitude, dc, rms = self.get_signal_properties(samples)

            freqs, mags = self.get_spectral_analysis(samples, log=False)
            snr, thdn = self.get_signal_qualities(mags)
            mags = [20*np.log10(i/self.waveform_amplitude) for i in mags]

            print('-'*20 + " " + titles[i] + " Results " + '-'*20)
            print("*  Amp(V): " + str(amplitude))
            print("*   DC(V): " + str(dc))
            print("*  RMS(V): " + str(rms))
            print("*  Max(V): " + str(max(samples)))
            print("*  Min(V): " + str(min(samples)))
            print("*  SNR (dB): " + str(snr))
            print("*  THDN  : " + str(thdn))

            subplot(320 + (i*2) + 1)
            plot([i+1 for i in range(len(samples))], samples)
            grid()
            title(titles[i] + " Data")
            xlabel('Samples')
            ylabel('Voltage(V)')
            subplot(320 + (i*2)+2)
            plot(freqs, mags)
            title(titles[i] + " FFT")
            xlabel('Frequency (Hz)')
            ylabel('Magnitude (dB)')
            xscale('log')
            grid()

        dad.close_device()

        tight_layout()
        show()
           
    def test_bode(self):

        freqs = []
        amplitudes = []

        # build up list of frequencies
        sweep_mult = (float(self.waveform_sweep_end)/float(self.waveform_sweep_start)) ** (1.0/float(self.waveform_sweep_steps-1))
        freq = self.waveform_sweep_start
        for i in range(self.waveform_sweep_steps):
            freqs.append(freq)
            freq *= sweep_mult

        dad = DigilentAnalogDiscovery()
        dad.open_device()

        # record samples for each freq and store amplitude
        for freq in freqs:
            dad.wavegen_config_sine_out(freq = freq, amp = self.waveform_amplitude, offset=self.waveform_offset)
            sleep(0.1)
            samples = self.read_serial()
            amplitude, dc, rms = self.get_signal_properties(samples)
            amplitudes.append(amplitude)

        dad.close_device()

        # convert amplitudes to gain in dB
        for i in range(self.waveform_sweep_steps):
            amplitudes[i] = 20*np.log10(amplitudes[i] / self.waveform_amplitude) 

        # plot
        plot(freqs, amplitudes)
        xscale('log')
        title('Bode Plot')
        xlabel('Frequency (Hz)')
        ylabel('Gain (dB)')
        show()
        tight_layout()

# parse args
parser = ArgumentParser(description = 'Hardware Test Script for ADC')
parser.add_argument('--mode', metavar='mode',        nargs=1, help = 'mode = [sine, measure, bode]')
parser.add_argument('--freq', metavar='frequency',   nargs=1, help = 'waveform frequency')
parser.add_argument('--amplitude',  metavar='amplitude',   nargs=1, help = 'waveform amplitude')
parser.add_argument('--offset',  metavar='offset',   nargs=1, help = 'waveform offset')
parser.add_argument('--start',metavar='sweep_start', nargs=1, help = 'waveform sweep start frequency')
parser.add_argument('--end',  metavar='sweep_end',   nargs=1, help = 'waveform sweep end frequency')
parser.add_argument('--steps',metavar='sweep_steps', nargs=1, help = 'waveform sweep steps')
parser.add_argument('--dft',  metavar='dft_size',    nargs=1, help = 'dft size')
parser.add_argument('--ndad', metavar='no_dad', action='store_const', const=1, help = 'don\'t use dad class for waveform')
args = parser.parse_args()

hw = HwTest()

# overrides to waveform parameters
if(args.freq):
    hw.waveform_frequency = float(args.freq[0])
if(args.amplitude):
    hw.waveform_amplitude = float(args.amplitude[0])
if(args.offset):
    hw.waveform_offset = float(args.offset[0])
if(args.start):
    hw.waveform_sweep_start = float(args.start[0])
if(args.end):
    hw.waveform_sweep_end = float(args.end[0])
if(args.steps):
    hw.waveform_sweep_steps = int(args.steps[0])
if(args.dft):
    hw.waveform_dft_size = int(args.steps[0])
if(args.ndad):
    no_dad = False
    print("Not using DAD script class")
else:
    no_dad = True

# run the script
if(args.mode[0] == 'sine'):
    hw.test_sine(no_dad)
if(args.mode[0] == 'measure'):
    hw.test_measure()
if(args.mode[0] == 'bode'):
    hw.test_bode()
