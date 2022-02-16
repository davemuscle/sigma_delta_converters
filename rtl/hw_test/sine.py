#!/usr/bin/python

import numpy as np
len = 256
bits = 20
n = np.arange(len)
s = np.cos(2*np.pi*n/len)
s = s * ((2**(bits-1))-100)
s = s + (2**(bits-1))
for i in range(len):
    print("%d: %d," % (i, s[i]))

