#!/usr/bin/python

# Helper functions for driving model, testbench, and hardware

import sys
from matplotlib.pyplot import *

from Waveform import *
from ModelsimTestbench import *

"""
ADC Simulation 00
Input a DC then a sine wave. Plot the inputs and outputs for visual inspection
Provide frequency, amplitude, and offset as float arguments
Usage example:
  env.py test_adc_simple sim_directive 440.0 1.0 1.25
"""
def test_adc_sim_00(*args):
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
    w.reset()
    w.generate_dc()
    w.generate_sine()
    w.file_export(x.defines['INPUT_FILE'])
    input_samples = [i for i in w.samples]
    
    x.run()

    w.file_import(x.defines['OUTPUT_FILE'])

    subplot(211)
    plot(input_samples)
    subplot(212)
    plot(w.samples)
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
