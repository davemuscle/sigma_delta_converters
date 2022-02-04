#!/usr/bin/python

# Dave Muscle

"""
  Helper for running Digilent's Analog Discovery via Python
  Adapted mostly from their sample code
"""

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

    def wavegen_config_sine_out(self, channel=0, freq=100, amp=1.0, offset=0):
        self.dwf.FDwfDeviceAutoConfigureSet   (self.hdwf, channel)
        self.dwf.FDwfAnalogOutNodeEnableSet   (self.hdwf, channel, AnalogOutNodeCarrier, c_bool(True))
        self.dwf.FDwfAnalogOutNodeFunctionSet (self.hdwf, channel, AnalogOutNodeCarrier, funcSine)
        self.dwf.FDwfAnalogOutNodeFrequencySet(self.hdwf, channel, AnalogOutNodeCarrier, c_double(freq))
        self.dwf.FDwfAnalogOutNodeAmplitudeSet(self.hdwf, channel, AnalogOutNodeCarrier, c_double(amp))
        self.dwf.FDwfAnalogOutNodeOffsetSet   (self.hdwf, channel, AnalogOutNodeCarrier, c_double(offset))
        self.dwf.FDwfAnalogOutConfigure       (self.hdwf, channel, c_bool(True))

    def setup_custom_data(self, size):
        self.custom_data = (c_double*size)()
        self.custom_len = c_int(size)

    def wavegen_config_custom_out(self, channel=0, freq=100, amp=1.0, offset=0):
        self.dwf.FDwfDeviceAutoConfigureSet   (self.hdwf, channel)
        self.dwf.FDwfAnalogOutNodeEnableSet   (self.hdwf, channel, AnalogOutNodeCarrier, c_bool(True))
        self.dwf.FDwfAnalogOutNodeFunctionSet (self.hdwf, channel, AnalogOutNodeCarrier, funcCustom)
        self.dwf.FDwfAnalogOutNodeDataSet     (self.hdwf, channel, AnalogOutNodeCarrier, self.custom_data, self.custom_len)
        self.dwf.FDwfAnalogOutNodeFrequencySet(self.hdwf, channel, AnalogOutNodeCarrier, c_double(freq))
        self.dwf.FDwfAnalogOutNodeAmplitudeSet(self.hdwf, channel, AnalogOutNodeCarrier, c_double(amp))
        self.dwf.FDwfAnalogOutNodeOffsetSet   (self.hdwf, channel, AnalogOutNodeCarrier, c_double(offset))
        self.dwf.FDwfAnalogOutConfigure       (self.hdwf, channel, c_bool(True))

#x = DigilentAnalogDiscovery()
#x.enable_prints()
#x.get_version()
#x.open_device()
#x.wavegen_config_sine_out(freq=440, amp=0.5)
#input("press enter")
#x.close_device()


