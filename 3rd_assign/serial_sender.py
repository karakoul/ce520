#!/usr/bin/env python

import sys
import tos
import time

AM_ID=20

serial_port = tos.Serial("/dev/ttyUSB0",115200)
am = tos.AM(serial_port)

tx_pckt = tos.Packet( [('originatorID',  'int', 2),
					   ('sensorT','int',2),
					   ('samplingPeriod',  'int', 2),
					   ('lifeTime',  'int', 2),
					   ('aggregationMode',  'int', 2),
					   ('currentPeriod',  'int', 2),
					   ('depth',  'int', 2)],[])

tx_pckt.originatorID = 0
tx_pckt.sensorT = 0
tx_pckt.samplingPeriod = 10
tx_pckt.lifeTime = 120
tx_pckt.aggregationMode = 1
tx_pckt.currentPeriod = 0
tx_pckt.depth = 0

print tx_pckt.samplingPeriod
# input_mode = raw_input( "Enter aggregation mode: " )
am.write(tx_pckt,AM_ID, None, False)
print "Send done"

for i in xrange(1,1000):
	pckt = am.read()
	print "Read"
	if pckt is not None:
		print pckt.type
		print pckt.destination
		print pckt.source
		print pckt.data
