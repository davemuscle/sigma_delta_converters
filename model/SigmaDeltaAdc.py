#!/usr/bin/python3

# DaveMuscle

from SigmaDeltaMod import *
import numpy
import scipy.signal
import matplotlib.pyplot as pylab
from matplotlib.widgets import Cursor

# Comb/integrator taken from:
# https://github.com/m1geo/CIC-Filter/blob/master/CIC-Filter.py

class inte:
    def __init__(self):
        self.yn = 0;
        self.ynm = 0
    def update(self, inp):
        self.ynm = self.yn
        self.yn = self.ynm + inp
        return self.yn

class comb:
    def __init__(self):
        self.xn = 0
        self.xnm = 0;
    def update(self, inp):
        self.xnm = self.xn
        self.xn = inp
        return self.xn - self.xnm

def generate_input(scale, num_samples, freq, sample_rate):
    x = [0]*num_samples
    for n in range(num_samples):
        x[n] = scale*numpy.cos((2*numpy.pi*freq*n)/sample_rate)
    return x
        
class SigmaDeltaAdc:
    _vcc = 0.0

    _bosr = 256
    _sclk = 44800
    _num_samples = 4000
    _freq = 110

    def __init__(self, vcc):
        self._vcc = vcc
        self._mod = SigmaDeltaMod(self._vcc)
        self._analog_in = generate_input(0.9*self._vcc, self._num_samples*self._bosr, self._freq, self._sclk*self._bosr)
        self._bits = [0] * self._num_samples*self._bosr
        self._digital_out = [0] * self._num_samples

    def run(self):
        # run analog input through sigma-delta mod
        for n in range(self._num_samples*self._bosr):
            # condition
            self._analog_in[n] = (self._vcc/2) + (self._analog_in[n] / 2)
            # run modulator to obtain bitstream
            self._mod.set_analog(self._analog_in[n])
            self._bits[n] = self._mod.loop_tick()

        # create taps for FIR
        nyq_rate = self._sclk / 2
        width = 3200/nyq_rate
        ripple_db = 60
        N, beta = scipy.signal.kaiserord(ripple_db, width)
        cutoff_hz = 20000
        taps = scipy.signal.firwin(N, cutoff_hz/nyq_rate, window=('kaiser', beta))
        #print("%d taps: " % N);
        #for x in taps:
        #    print("  " + str(float(x)));

        # CIC filter
        cic_stages = 1
        intes = [inte() for a in range(cic_stages)]
        combs = [comb() for a in range(cic_stages)]
        n = 0
        bits_filtered = [0] * self._num_samples
        for k in range(self._num_samples*self._bosr):
            z = self._bits[k]
            # integrator
            for g in range(cic_stages):
                z = intes[g].update(z)
            # comb
            if((k % self._bosr)==0):
                for g in range(cic_stages):
                    z = combs[g].update(z)
                    j = z
                bits_filtered[n] = j / (self._bosr ** cic_stages)
                n = n + 1
       
        # Why does a CIC filter on the bitstream give us the the correct output, but a normal FIR doesn't?

        # Low-pass final data
        #self._digital_out = scipy.signal.lfilter(taps, 1.0, bits_filtered) 

        # 

        # DC Removal
        yn = 0
        yn_mul = 0
        yn_reg = 0
        xn_reg = 0
        for n in range(self._num_samples):
            #self._digital_out[n] = bits_filtered[n] - xn_reg + 0.995*yn_reg
            #xn_reg = bits_filtered[n]
            #yn_reg = self._digital_out[n]

            yn = bits_filtered[n] - yn_reg
            yn_mul = yn * 0.005
            self._digital_out[n] = self._vcc * yn
            yn_reg = yn_mul + yn_reg

        debug = 0

        if(debug):
            pylab.figure("debug taps")
            pylab.plot(taps, 'bo-', linewidth=2)
            pylab.title('Filter coefficients (%d taps)' % N)
            pylab.grid(True)

            pylab.figure("filter response (%d taps)" % N)
            pylab.clf()
            w,h = scipy.signal.freqz(taps, worN=8000)
            pylab.plot((w/numpy.pi)*nyq_rate, numpy.absolute(h), linewidth=2)
            pylab.xlabel('Freq (Hz)')
            pylab.ylabel('Gain')
            pylab.ylim(-0.05, 1.05)
            pylab.grid(True)

x = SigmaDeltaAdc(2.5)
x.run()
pylab.figure("Analog Input Data")
pylab.plot(x._analog_in)
pylab.figure("Digital Output Data")
pylab.plot(x._digital_out)

pylab.show()
