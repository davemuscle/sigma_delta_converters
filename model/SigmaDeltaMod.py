#!/usr/bin/python3

# DaveMuscle

"""
Sigma-Delta Modulator Class

Usage:
  Create object:
      x = SigmaDeltaMod(vcc), vcc = float value of adc power pin

  Run the loop on input samples, corresponding to the bit clk:
      x.loop(), returns output of SD modulator
"""

class SigmaDeltaMod:
    _intvalue = 0.0
    _summer = 0.0
    _impulse = 0
    _afeedback = 0.0

    _vcc = 0.0

    def __init__(self, vcc):
        self._vcc = vcc

    def loop(self, samples):
        y = []
        for x in samples:
            # adder
            self._summer = x - self._afeedback
            # integrator
            self._intvalue = self._intvalue + self._summer
            # comparator 
            if(self._intvalue > 0.0):
                self._impulse = 1
            else:
                self._impulse = 0
            # feedback
            self._afeedback = self._vcc * self._impulse
            y.append(self._impulse)
        return y
