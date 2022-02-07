#!/usr/bin/python

# Helper functions for driving model, testbench, and hardware

import sys
from matplotlib.pyplot import *

from Waveform import *
from Signal import *
from IO import *
from ModelsimTestbench import *

import numpy as np

"""
ADC Simulation 00
Input a DC then a sine wave. Plot the inputs and outputs for visual inspection
Provide frequency, amplitude, and offset as float arguments
Usage example:
  ./sim.py test_adc_00
  arg0 - directive file
  arg1 - frequency
  arg2 - amplitude
  arg3 - offset
"""
def test_adc_00(*args):
    x = ModelsimTestbench()
    x.parse(args[0])
    x.print_parsed()
    x.compile()

    num_samples = 512

    w = Waveform()
    w.frequency  = float(args[1])
    w.amplitude  = float(args[2])
    w.offset     = float(args[3])
    w.samplerate = int(x.defines['BCLK'])
    w.length     = int(x.defines['OVERSAMPLE_RATE']) * num_samples
    w.clear_samples()
    w.generate_dc()
    w.generate_sine()

    input_samples = w.samples
    fexport(x.defines['INPUT_FILE'], input_samples)
    
    x.run()

    output_samples = fimport(x.defines['OUTPUT_FILE'], float)

    subplot(211)
    plot(input_samples)
    subplot(212)
    plot(output_samples)
    tight_layout()
    show()

"""
ADC Simulation 01
Sweep sine wave input and record bode plot from ADC
Usage example:
  ./sim.py test_adc_01
  arg0 - directive
  arg1 - sweep_start
  arg2 - sweep_end
  arg3 - sweep_steps
  arg4 - amplitude
  arg5 - offset
"""
def test_adc_01(*args):
    x = ModelsimTestbench()
    x.parse(args[0])
    x.print_parsed()
    x.compile()

    num_samples = 4096
    num_cycles = 16

    w = Signal()

    w.amplitude  = float(args[1])
    w.offset     = float(args[2])
    w.samplerate = int(x.defines['BCLK'])
    w.length     = int(x.defines['OVERSAMPLE_RATE']) * num_samples

    w.clear_samples()
    w.generate_dc()
    
    w.set_sweep(
            start = float(args[3]),
            end   = float(args[4]),
            steps =   int(args[5]),
            cycles_per = num_cycles)

    w.generate_sine_sweep()

    input_samples = w.samples
    fexport(x.defines['INPUT_FILE'], input_samples)
    
    x.run()

    output_samples = fimport(x.defines['OUTPUT_FILE'], float)

    amps = [0]*len(w.sweep_length)
    idx = num_samples
    for i in range(len(w.sweep_length)):
        low_idx = idx
        high_idx = low_idx + int(w.sweep_length[i] / int(x.defines['OVERSAMPLE_RATE']))
        #amps[i] = w.get_amplitude(output_samples[low_idx : high_idx])
        amps[i] = w.get_amplitude(input_samples[low_idx : high_idx])
        idx = high_idx

    print(amps)
    for i in range(len(w.sweep_length)):
        amps[i] = 20*np.log10(amps[i] / w.amplitude)

    subplot(311)
    plot(input_samples)
    subplot(312)
    plot(output_samples)
    subplot(313)
    plot(w.sweep_frequency, amps)
    tight_layout()
    show()

"""
Cleanup directory
"""
def clean(*args):
    x = ModelsimTestbench()
    x.clean()

# command-line entry point
if __name__ == '__main__':
    # call a function in this file
    # the function name has to be the first argument
    globals()[sys.argv[1]](*sys.argv[2:len(sys.argv)])
