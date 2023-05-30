#!/usr/bin/python3

# convert xlsx  to tab delimited
#
# arg1 input xlsx file
# arg2 output tab delimited file
#
# necesita 
#    numpy     1.23.5  (no funciona con version >= 1.24.0)
#    openpyxl  3.0.7  (no fnciona con anterior)
#
#   usar  
#       sudo pip3 install numpy==1.23.5
#       sudo pip3 install openpyxl==3.0.
#

import os
import sys
import pandas as pd

xls_name = sys.argv[1]
csv_name = sys.argv[2]


print ("XLSX: ", xls_name)
print ("TEXT: ", csv_name)

file = pd.read_excel(xls_name)

file.to_csv(csv_name, sep="\t", index=False)
