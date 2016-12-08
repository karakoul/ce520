#!/usr/bin/env python

import sys
import tos
import time

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


AM_ID=20

code = bytearray()


# fd = open("app1.hex", 'rb')
# code_send = []
# try:
#     byte = fd.read(1)
#     while byte != "":
#         # Do stuff with byte.
#         if(byte!=" "):
#         	code_send.append(int(byte))
#         byte = fd.read(1)
#         print byte
# finally:
#     fd.close()

# length = len(code_send)
# code_send += (20 - length)*[0]



# print code_send

# serial_port = tos.Serial("/dev/ttyUSB0",115200)
# am = tos.AM(serial_port)

# tx_pckt = tos.Packet( [('seqNum',  'int', 1),
# 					   ('code','blob',20),
# 					   ('length', 'int', 2)
# 					   ],[])

# tx_pckt.seqNum = 0
# tx_pckt.code = code_send
# tx_pckt.length = 20

data = [13, 14, 0, 0, 0, 0, 0, 0]


print "---------------------------------------------"
print "[AppID:" + str(data[0]) + "] " + getCmd( data[1] )
print getRegs( data )
print "---------------------------------------------\n"

# input_mode = raw_input( "Enter aggregation mode: " )
# am.write(tx_pckt,AM_ID, None, False)
# print "Send done"
# for i in xrange(100):

# 	pckt = am.read()
# 	if pckt is not None:
#         # [13, 14, 0, 0, 0, 0, 0, 0]
# 		print pckt.type
# 		print pckt.destination
# 		print pckt.source
# 		print pckt.data

# cur = raw_input("Press to send ")
# am.write(tx_pckt,AM_ID)
