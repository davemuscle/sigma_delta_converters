#!/usr/bin/python

import numpy as np
len = 256
bits = 14
cols=8
n = np.arange(len)
s = np.cos(2*np.pi*n/len)
s = s * ((2**(bits-1))-100)
s = s + (2**(bits-1))
col=0
for i in range(len):
    print("%d: %d," % (i, s[i]), end='')
    col = col + 1
    if((col % cols)==0):
        col = 0
        print("")

