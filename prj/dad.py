#!/usr/bin/python

# Dave Muscle
# 
# Helper for running Digilent's Analog Discovery via Python
# Adapted mostly from their sample code

import sys
sys.path.append("/usr/share/digilent/waveforms/samples/py")

from ctypes import *
from dwfconstants import *

class DigilentAnalogDiscovery:

    loud = 1

    def __init__(self):
        # Load Linux Library
        self.dwf = cdll.LoadLibrary("libdwf.so")

    def enable_prints(self):
        self.loud = 1
    def disable_prints(self):
        self.loud = 0

    def get_version(self):
        if(self.loud):
            version = create_string_buffer(16)
            self.dwf.FDwfGetVersion(version)
            print("DWF Version: " + str(version.value))

    # open device, defaults to first (-1)
    def open_device(self, device=-1):
        self.hdwf = c_int()
        self.dwf.FDwfDeviceOpen(c_int(device), byref(self.hdwf))
        if(self.loud):
            if self.hdwf.value == hdwfNone.value:
                print("Failed to open device")
            else:
                print("Opened device")

    def close_device(self):
        self.dwf.FDwfDeviceClose(self.hdwf)
        if(self.loud):
            print("Closed device")

x = DigilentAnalogDiscovery()
x.enable_prints()
x.get_version()
x.open_device()

channel = c_int(0)

x.dwf.FDwfDeviceAutoConfigureSet(x.hdwf, c_int(0))

x.dwf.FDwfAnalogOutNodeEnableSet   (x.hdwf, channel, AnalogOutNodeCarrier, c_bool(True))
x.dwf.FDwfAnalogOutNodeFunctionSet(x.hdwf, channel, AnalogOutNodeCarrier, funcSine)
x.dwf.FDwfAnalogOutNodeFrequencySet(x.hdwf, channel, AnalogOutNodeCarrier, c_double(440))
x.dwf.FDwfAnalogOutNodeAmplitudeSet(x.hdwf, channel, AnalogOutNodeCarrier, c_double(0.400))
x.dwf.FDwfAnalogOutNodeOffsetSet   (x.hdwf, channel, AnalogOutNodeCarrier, c_double(1.60))

x.dwf.FDwfAnalogOutConfigure(x.hdwf, channel, c_bool(True))
input("press enter")
x.close_device()


