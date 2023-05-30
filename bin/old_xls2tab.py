#!/usr/bin/python3

# convert xls (old format) to tab delimited
#
# arg1 input xls file
# arg2 output tab delimited file
#

# necesita
#    numpy     1.23.5  (no funciona con version >= 1.24.0)
#    openpyxl  3.0.7  (no fnciona con anterior)
#
#   usar
#       sudo pip3 install numpy==1.23.5
#       sudo pip3 install openpyxl==3.0.7
#

import os
import sys
import xlrd
import csv

in_name = sys.argv[1]

out_name = sys.argv[2]

print ("in XLS: ", in_name)
print ("out CSV: ", out_name)
print ("")


# open the output csv
with open(out_name, 'w') as myCsvfile:
    # define a writer
    wr = csv.writer(myCsvfile, delimiter="\t")

    # open the xlsx file 
    myfile = xlrd.open_workbook(in_name)
    # get a sheet
    mysheet = myfile.sheet_by_index(0)

    # write the rows
    for rownum in range(mysheet.nrows):
        wr.writerow(mysheet.row_values(rownum))
