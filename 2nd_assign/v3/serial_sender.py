#!/usr/bin/env python

import sys
import tos
import time

AM_ID=20

serial_port = tos.Serial("/dev/ttyUSB0",115200)
am = tos.AM(serial_port)


for i in xrange(100):
	tx_pckt = tos.Packet([('id',  'int', 2),('seq','int',2)],[])
	tx_pckt.id = 3
	tx_pckt.seq = i
	print tx_pckt;
	am.write(tx_pckt,AM_ID)
	time.sleep(1)
	pckt = am.read(timeout=0.5)
	if pckt is not None:
		print pckt.type
		print pckt.destination
		print pckt.source
		print pckt.data

