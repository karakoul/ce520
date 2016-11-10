#!/usr/bin/env python

import sys
import tos
import time

AM_ID=20

serial_port = tos.Serial("/dev/ttyUSB0",115200)
am = tos.AM(serial_port)

tx_pckt = tos.Packet([('id',  'int', 2),('seq','int',2),('sensorT',  'int', 2),('samplingPeriod',  'int', 2),('lifeTime',  'int', 2),('aggregationMode',  'int', 2),('currentPeriod',  'int', 2),('address',  'int', 2)],[])
tx_pckt.id = 0
tx_pckt.seq = 0
tx_pckt.sensorT = 1
tx_pckt.samplingPeriod = 1
tx_pckt.lifeTime = 5
tx_pckt.aggregationMode = 1
tx_pckt.currentPeriod = 0
tx_pckt.address = 0
cur = raw_input("Press to send ")
am.write(tx_pckt,AM_ID)

