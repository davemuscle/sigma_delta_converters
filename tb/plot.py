#!/usr/bin/python

# DaveMuscle

import sys
from matplotlib.pyplot import *

for i in range(2):
    # sys.argv[1] and sys.argv[2]
    file = open(sys.argv[i+1], "r") 
    lines = file.readlines()
    file.close()

    data = [float(d) for d in lines]

    subplot(210 + (i+1))
    plot([x for x in range(len(data))], data)
    xlabel('samples')
    ylabel('voltage(V)')
    title(sys.argv[i+1])

tight_layout()
show()
