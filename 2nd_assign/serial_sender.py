#!/usr/bin/env python

import sys
import tos
import time

AM_ID=20

serial_port = tos.Serial("/dev/ttyUSB0",115200)
am = tos.AM(serial_port)


for i in xrange(10,1000):
	tx_pckt = tos.Packet([('id',  'int', 2),('seq','int',2)],[])
	tx_pckt.id = 3
	tx_pckt.seq = i
	cur = raw_input("Press to send ")
	am.write(tx_pckt,AM_ID)

