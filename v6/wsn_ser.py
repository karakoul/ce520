#!/usr/bin/env python

import sys
import tos
import os
import threading
import Queue
import time

#application defined messages

class AppMsg(tos.Packet):
    def __init__(self, packet = None):
        tos.Packet.__init__(self,
                            [('counter',  'int', 2)],
                            packet)


class SerialManager(threading.Thread):

	def __init__(self,rx,tx,SerialDev,SerialBaudRate,AMChannel):
		threading.Thread.__init__(self)
		threading.Thread.deamon = False 
		self.rx = rx
		self.tx = tx
		self.spare=0;
		self.SerialDev = SerialDev
		self.SerialBaudRate = SerialBaudRate
		self.AMChannel = AMChannel
		try:
			self.serial = tos.Serial(self.SerialDev,self.SerialBaudRate)
			self.am = tos.AM(self.serial)
		except :
			print "Error : ",sys.exc_info()[1]
			sys.exit()
		
	def run(self):
		print "AMessage communication started ! "
		while True:
			while self.tx.empty() == False:
				tx_pckt = self.tx.get()
				self.am.write(tx_pckt,self.AMChannel)
				#self.rx.put(tx_pckt)
			try:
				pckt = self.am.read(timeout=0.4)
				if pckt:
					#print pckt
					msg = AppMsg(pckt.data)
					self.rx.put(msg)
			except: 				
				self.spare=0	


def receiver(rx):
	while True:
		msg = rx.get()
		print "Imote -> PC: "+ str(msg.counter)
		if(msg.counter < 50):
			print "Led on"
		else:
			print "Led off"  	


def transmitter(tx):
	while True:
		var = raw_input(" ")
		if var == "q":
			os._exit(1)
		print "PC -> Imote: " + var
		msg=AppMsg((int(var),[]));
                tx.put(msg)
		print "sent"


def main():
	tx = Queue.Queue()
	rx = Queue.Queue()
	Manager = SerialManager(rx,tx,"/dev/ttyUSB0",115200,3)	
	Manager.deamon = False
	Manager.start()

	
	rcv_th=threading.Thread(target=receiver,args=(rx,))
	rcv_th.deamon = False;
	rcv_th.start()
	
	snd_th=threading.Thread(target=transmitter,args=(tx,))
	snd_th.deamon = False;
	snd_th.start()
	


if __name__ == "__main__":
	main()
