#!/usr/bin/env python

import sys
import tos

#application defined messages

tx_pckt = tos.Packet([('type',  'int', 1)],[])

AM_ID=3

serial_port = tos.Serial("/dev/ttyUSB0",115200)
am = tos.AM(serial_port)

for i in xrange(100):

	am.write(tx_pckt,AM_ID)
	pckt = am.read(timeout=0.5)
	if pckt is not None:
		print pckt.type
		print pckt.destination
		print pckt.source
		print pckt.data



