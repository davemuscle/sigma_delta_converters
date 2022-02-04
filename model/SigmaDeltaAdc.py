#!/usr/bin/python3

# DaveMuscle

from SigmaDeltaMod import *
import numpy
import scipy.signal
import matplotlib.pyplot as pylab
import math
from matplotlib.widgets import Cursor

def cic_decimator(samples, decimator, stages):
    # integrator
    yn = [0]*stages
    ynm = [0]*stages
    # copy to buffer
    buf = []
    for n in samples:
        buf.append(n)
    # perform integrator
    for n in range(len(samples)):
        for s in range(stages):
            ynm[s] = yn[s]
            yn[s] = ynm[s] + buf[n]
            buf[n] = yn[s]
    # downsample
    dec = []
    for n in range(0, len(samples), decimator):
        dec.append(buf[n])
    # comb
    xn = [0]*stages
    xnm = [0]*stages
    # perform comb
    for n in range(len(dec)):
        for s in range(stages):
            xnm[s] = xn[s]
            xn[s] = dec[n]
            dec[n] = xn[s] - xnm[s]
    return dec

def cic_compensator(samples, order):
    if(order == 1):
        A = -18
    if(order == 2 or order == 3):
        A = -10
    if(order == 4 or order == 5):
        A = -6
    if(order >= 6):
        A = -4
    d1 = 0
    d2 = 0
    d = []
    for x in samples:
        d.append(d2 + x + A*d1)
        d2 = d1
        d1 = x
    return d

def cic_compensator_a(samples, a):
    d1 = 0
    d2 = 0
    d = []
    for x in samples:
        y = (-1*a/2)*d2  + (1+a)*d1
        d.append(y)
        d2 = d1 + x
        d1 = x
    return d

def generate_input(scale, num_samples, freq, sample_rate):
    x = [0]*num_samples
    for n in range(num_samples):
        x[n] = scale*numpy.cos((2*numpy.pi*freq*n)/sample_rate)
    return x
        
class SigmaDeltaAdc:
    _vcc = 0.0

    _bosr = 256
    _cic_stages = 1
    _sclk = 44800
    _num_samples = 256
    _freq = 440

    _sweep_start = 220
    _sweep_steps = 160
    _sweep_mult = 2.0**(0.5/12.0)

    def __init__(self, vcc):
        self._vcc = vcc
        self._mod = SigmaDeltaMod(self._vcc)

    def run(self):
        analog_in = generate_input(0.9*self._vcc, self._num_samples*self._bosr, self._freq, self._sclk*self._bosr)
        # run analog input through sigma-delta mod
        for n in range(self._num_samples*self._bosr):
            # condition
            analog_in[n] = (self._vcc/2) + (analog_in[n] / 2)

        # run modulator to obtain bitstream
        # run cic decimator
        digital_out = cic_decimator(self._mod.loop(analog_in), self._bosr, self._cic_stages)
        # run compensator
        digital_out = cic_compensator(digital_out, self._cic_stages)
        # convert to voltage
        analog_out = []
        for x in bits_filtered:
            analog_out.append(x * self._vcc / (self._bosr ** self._cic_stages))
        # remove transient
        for x in range(25):
            analog_out.pop(0)
        ## DC Removal
        #yn = 0
        #yn_mul = 0
        #yn_reg = 0
        #xn_reg = 0
        #for n in range(self._num_samples):
        #    #self._digital_out[n] = bits_filtered[n] - xn_reg + 0.995*yn_reg
        #    #xn_reg = bits_filtered[n]
        #    #yn_reg = self._digital_out[n]

        #    yn = bits_filtered[n] - yn_reg
        #    yn_mul = yn * 0.005
        #    self._digital_out[n] = self._vcc * yn
        #    yn_reg = yn_mul + yn_reg
        pylab.figure("Analog Input Data")
        pylab.plot(analog_in)
        pylab.figure("Digital Output Data")
        pylab.plot(analog_out)
        pylab.show()

    def get_amplitude(self, samples):
        low = samples[0]
        high = samples[0]
        for x in range(1, len(samples)):
            if(samples[x] < low):
                low = samples[x];
            if(samples[x] > high):
                high = samples[x];
        return ((high-low)/2)

    def sweep(self):
        freq = self._sweep_start
        freqs = []
        amps = []
        amps_unc = []
        gen_amp = 1.0
        for x in range(self._sweep_steps):
            freqs.append(freq)
            analog_in = generate_input(gen_amp, self._num_samples * self._bosr, freq, self._sclk * self._bosr)
            for n in range(len(analog_in)):
                analog_in[n] += self._vcc / 2
            digital_out = cic_decimator(self._mod.loop(analog_in), self._bosr, self._cic_stages)
            analog_out = []
            for x in digital_out:
                analog_out.append(x * self._vcc / (self._bosr ** self._cic_stages))
            analog_out_unc = []
            for x in analog_out:
                analog_out_unc.append(x)
            analog_out = cic_compensator_a(analog_out, 0.2)
            for x in range(25):
                analog_out.pop(0)
                analog_out_unc.pop(0)
            amp = self.get_amplitude(analog_out)
            amp_unc = self.get_amplitude(analog_out_unc)
            print("Freq = " + str(freq) + ", Amp = " + str(amp), "AmpUnc = " + str(amp_unc))
            amps.append(20*math.log10(amp / self.get_amplitude(analog_in)))
            amps_unc.append(20*math.log10(amp_unc / self.get_amplitude(analog_in)))
            freq *= self._sweep_mult
        pylab.figure("Bode Plot Uncompensated")
        pylab.plot(freqs, amps_unc)
        pylab.xscale('log')
        pylab.figure("Bode Plot")
        pylab.plot(freqs, amps)
        pylab.xscale('log')
        pylab.show()

x = SigmaDeltaAdc(2.5)
#x.run()
x.sweep()

