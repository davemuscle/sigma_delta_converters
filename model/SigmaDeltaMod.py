#!/usr/bin/python3

# DaveMuscle

"""
Sigma-Delta Modulator Class

Usage:
  Create object:
      x = SigmaDeltaMod(vcc), vcc = float value of adc power pin
  
  Set input voltage:
      x.set_analog(analog), analog = float

  Run the loop, corresponding to the bit clk:
      x.loop_tick(), returns 0 or 1 as part of the bitstream


Debug:
   Run modulator loop i,j times and prints digital values / bitstream:
      x.test(i, j)
   i corresponds to number of bits to count for comprising a digital sample
   j corresponds to number of samples to gather

"""
class SigmaDeltaMod:
    _avalue = 0.0
    _intvalue = 0.0
    _summer = 0.0
    _impulse = 0
    _afeedback = 0.0

    _vcc = 0.0

    def __init__(self, vcc):
        self._vcc = vcc

    def set_analog(self, float):
        self._avalue = float

    def loop_tick(self):
        # adder
        self._summer = self._avalue - self._afeedback
        # integrator
        self._intvalue = self._intvalue + self._summer
        # comparator 
        if(self._intvalue > 0.0):
            self._impulse = 1
        else:
            self._impulse = 0
        # feedback
        self._afeedback = self._vcc * self._impulse
        return self._impulse

    def test(self, bits, samples):
        for i in range(samples):
            d = 0
            print("  ", end='')
            for j in range(bits):
                v = self.loop_tick()
                d = v + d
                print(str(v) + "", end='')
            print(" -> total = " + str(d), "-> voltage = " + str(self._vcc*d/bits))
