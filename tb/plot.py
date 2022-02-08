#!/usr/bin/python

# DaveMuscle

import sys
from matplotlib.pyplot import *

infile = open(sys.argv[1], "r")
outfile = open(sys.argv[2], "r")

inlines = infile.readlines()
outlines = outfile.readlines()

infile.close()
outfile.close()

indata = [float(d) for d in inlines]
outdata = [float(d) for d in outlines]

plottype = plot

subplot(211)
plottype([i for i in range(len(indata))], indata)
xlabel('samples')
ylabel('voltage(V)')
title('input data')

subplot(212)
plottype([i for i in range(len(outdata))], outdata)
xlabel('samples')
ylabel('voltage(V)')
title('output data')

tight_layout()
show()
