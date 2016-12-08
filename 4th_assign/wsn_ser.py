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
                            [('id', 'int', 2),('seqNum',  'int', 2),
						   ('code','blob',30)   
						   ], packet)




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
		print "A Message communication started ! "
		while True:
			while self.tx.empty() == False:
				tx_pckt = self.tx.get()
				# self.am.write(tx_pckt,self.AMChannel)
			try:
				pckt = self.am.read(timeout=0.4)
				if pckt:
					msg = AppMsg(pckt.data)
					self.rx.put(msg)
			except: 				
				self.spare=0	



def getRegs( regs ):
    registers = ""

    for i in range( 2, 8 ):
        registers = registers + "R" + str(i-1) + " = " + str( regs[i] ) + "\n"

    return registers

def getCmd( instr ):
    if ( instr == 0 ):
        cmd = "RET"
    elif ( instr == 1 ):
        cmd = "SET"
    elif ( instr == 2 ):
        cmd = "CPY"
    elif ( instr == 3 ):
        cmd = "ADD"
    elif ( instr == 4 ):
        cmd = "SUB"
    elif ( instr == 5 ):
        cmd = "INC"
    elif ( instr == 6 ):
        cmd = "DEC"
    elif ( instr == 7 ):
        cmd = "MAX"
    elif ( instr == 8 ):
        cmd = "MIN"
    elif ( instr == 9 ):
        cmd = "BGZ"
    elif ( instr == 10 ):
        cmd = "BEZ"
    elif ( instr == 11 ):
        cmd = "BRA"
    elif ( instr == 12 ):
        cmd = "LED"
    elif ( instr == 13 ):
        cmd = "RDB"
    elif ( instr == 14 ):
        cmd = "TMR"

    return cmd



def receiver(rx):
	while True:
		serial_port = tos.Serial("/dev/ttyUSB0",115200)
		am = tos.AM(serial_port)
		pckt = am.read()
		if pckt is not None:
			# print pckt.type
			# print pckt.destination
			# print pckt.source
			print pckt.data
			if(len(pckt.data)!=0): 
				if(pckt.data[0]!=0  ):
					print "[AppID:" + str(pckt.data[0]) + "] " + getCmd( pckt.data[1] )
					print getRegs( pckt.data )
			


def transmitter(tx):
	AM_ID=20

	serial_port = tos.Serial("/dev/ttyUSB0",115200)
	am = tos.AM(serial_port)

	tx_pckt = tos.Packet( [('id', 'int', 2),('seqNum',  'int', 2),
						   ('code','blob',30)   
						   ],[])

	while True:

		code = bytearray()

		fileName = raw_input("Enter application file name: ")
		if fileName == "q":
			os._exit(1)
		fileName = "app"+fileName+".hex"
		fd = open(fileName, 'rb')
		code_send = []
		try:
		    byte = fd.read(5)
		    while byte != "":
		        # Do stuff with byte.
	        	print byte
	        	code_send.append(int(byte[2:4],16))
		        byte = fd.read(5)
		finally:
		    fd.close()

		length = len(code_send)
		code_send += (30 - length)*[0]

		print code_send



		appId = raw_input("Enter the id of the app: ")
		if appId == "q":
			os._exit(1)
		tx_pckt.id = int(appId)
		tx_pckt.seqNum = 0
		tx_pckt.code = code_send

		

		am.write(tx_pckt,AM_ID, None, False)
		print "sent"


def main():
	tx = Queue.Queue()
	rx = Queue.Queue()
	Manager = SerialManager(rx,tx,"/dev/ttyUSB0",115200,20)	
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
