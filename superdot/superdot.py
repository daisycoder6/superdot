import csv



with open('uart_rx.sv', newline='') as csvfile:
 rtlreader = csv.reader(csvfile, delimiter=' ', quotechar='|')
 for row in rtlreader:
     print(', '.join(row))
