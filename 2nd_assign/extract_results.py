import re
from collections import defaultdict

messages = []
numOfNodes = 0
nodes = defaultdict( list )
totalTransmissions = 0
recvMessages = defaultdict( list )

class Message():

  def __init__( self, srcID, seqNo ):
      self.srcID = srcID
      self.seqNo = seqNo
      self.transmissions = 1
      self.firstSent = ""
      self.lastRcv = ""

  def __hash__( self ):
    return hash( ( self.srcID, self.seqNo ) )

  def __eq__( self, other ):
    return ( self.srcID, self.seqNo ) == ( other.srcID, other.seqNo )

  def __ne__( self, other ):
    return not ( self == other )

  def setFirstSent( self, time ):
  	self.firstSent = time

  def setLastReceived( self, time ):
  	self.lastRcv = time

  def incrTransmissions( self ):
    self.transmissions += 1

  def getTransmissions( self ):
    return self.transmissions

  def getSrcID( self ):
    return self.srcID
  
  def getSeqNo( self ):
    return self.seqNo

  def isEqual( Message ):
    return ( ( self.srcID == msg.getSrcID() ) and ( self.seqNo == msg.getSeqNo() ) )

  def printMsg( self ):
    # print "SourceID: " + str( self.srcID ) + " SeqNo: " + str( self.seqNo ) + " Transmitted: " + str( self.transmissions )
    # print "First sent: " + self.firstSent
    # print "Last Recv: " + self.lastRcv
    print ""

  def getLatency( self ):
    match = re.search( r'([0-9]+):([0-9]+):([0-9.]+)', self.firstSent, re.M | re.I )

    if ( match ):
      firstSentNs = int( match.group(1) ) * 3600 + int( match.group(2) ) * 60 + float( match.group(3) )
    else:
      return -1

    match = re.search( r'([0-9]+):([0-9]+):([0-9.]+)', self.lastRcv, re.M | re.I )

    if ( match ):
      lastRcvNs = int( match.group(1) ) * 3600 + int( match.group(2) ) * 60 + float( match.group(3) )
    else:
      return -1

    latency = lastRcvNs - firstSentNs

    return latency
  	# print "Latency: " + str( lastRcvNs - firstSentNs )


def printTotalTransmissions():
  print ( "\n============= Total transmissions =============" )
  print ( "Total transmissions made: " + str( totalTransmissions ) )
  print ( "============= Total transmissions =============\n" )


def printActualPerNodeTransmissions():
  msg = "\n============= Actual per node transmissions =============\n"

  for node in nodes:
    msg += "Node:\t" + str( node )

    perNodeTrans = 0

    for message in nodes[ node ].get( node ):
      perNodeTrans += message.getTransmissions()

    msg += "\tTransmissions: " + str( perNodeTrans ) + "\n"

  msg += "============= Actual per node transmissions =============\n"

  # print msg


def printAveragePerNodeTransmissions():
	print "============= Average per node transmissions ============="
	print "Average per node transmissions: " + str( totalTransmissions / float( numOfNodes ) )
	print "============= Average per node transmissions =============\n"    

def printCoverage():
  totalMsgsRecv = 0
  msg = "\n============= Coverage =============\n"
  for message in messages:
    nodeRecv = 0
    recvBy = []
    # msg += "Message with sourceID: " + str( message.getSrcID() ) + " seqNo: " + str( message.getSeqNo() ) + " has been received by "

    for node in recvMessages:
      if ( message in recvMessages[ node ].get( node ) ):
        nodeRecv += 1
        recvBy.append( node )

    totalMsgsRecv += nodeRecv
    # msg += str( nodeRecv ) + "/" + str( numOfNodes ) + " nodes  Received by: " + str( recvBy ) + "\n" 

  msg += "\n===================================="
  msg += "\nTotal Coverage Percentage: " + str( 100.0 * totalMsgsRecv / float ( len( messages ) * numOfNodes ) ) + "%"
  msg += "\n============= Coverage =============\n"

  print msg


def printMessages():
  msg = "\n============= Messages =============\n"

  for message in messages:
    msg += "Source: " + str( message.getSrcID() ) + " SeqNo: " + str( message.getSeqNo() ) + "\n"

  msg += "============= Messages =============\n"
  # print msg

def handleReceive( nodeID, recv ):
  srcID = recv.group(1)
  seqNo = recv.group(2)

  msg = Message( srcID, seqNo )

  if ( nodeID not in recvMessages.keys() ):
    recvMessages[ nodeID ] = { nodeID : [] }

  if msg not in recvMessages[ nodeID ].get( nodeID ):
    recvMessages[ nodeID ].get( nodeID ).append( msg )
  

def handleSend( nodeID, send ):
  global totalTransmissions
  totalTransmissions += 1

  srcID = send.group(1)
  seqNo = send.group(2)

  msg = Message( srcID, seqNo )
  #print "Node " + nodeID + " Sent packet with nodeID: " + srcID + " seqNo: " + seqNo

  if ( msg not in messages ):
    messages.append( msg )

  if ( nodeID not in nodes.keys() ):
    nodes[ nodeID ] = { nodeID : [] }

  if msg not in nodes[ nodeID ].get( nodeID ):
    nodes[ nodeID ].get( nodeID ).append( msg )
  else:
     idx = nodes[ nodeID ].get( nodeID ).index( msg )
     nodes[ nodeID ].get( nodeID )[ idx ].incrTransmissions()


def calcLatency():
  f = open( 'results.txt', 'r' )
  messageList = []

  for line in f:
    match = re.search( r'DEBUG \((\d+)\): (\w+) (\d+) (\d+), time: ([0-9:.]+)', line, re.M | re.I ) # finds SEND message

    if ( match ):
      srcID = match.group(3)
      seqNo = match.group(4)
      msg = Message( srcID, seqNo )
      time = match.group(5)

      if ( match.group(2).startswith( "send" ) ):
        msg.setFirstSent( time )
      if ( msg not in messageList ):
        messageList.append( msg )
      elif ( match.group(2).startswith( "receive" ) ):
        msg.setLastReceived( time )
      if ( msg not in messageList ):
        messageList.append( msg )
      else:
        idx = messageList.index( msg )
        messageList[idx].setLastReceived( time )
  				
  minimum = 0
  maximum = 0
  sum_latency = 0
  node_counter = 0
  for message in messageList:
    if( message.getLatency() > maximum ):
      maximum = message.getLatency()

    if ( minimum <= 0 ):
      minimum = message.getLatency()

    if(message.getLatency() != -1):
      sum_latency += message.getLatency()
      node_counter += 1

    if ( message.getLatency() < minimum and message.getLatency() != -1):
      minimum = message.getLatency()

  print "minimum latency " + str(minimum) + " seconds"

  if( node_counter != 0 ):  
    print "average latency " + str(sum_latency/float(node_counter)) + " seconds"
  else :
    print "average latency not available!"

  print "maximum latency " + str(maximum) + " seconds"

# fileName = raw_input( "Give the fileName: " )
fileName = 'results.txt'
fd = open( fileName, 'r' )

for line in fd:

  if ( line.startswith( 'Creating noise model for' ) ):
    numOfNodes += 1
    continue

  node = re.search( r'DEBUG \((\d+)\): ', line, re.M | re.I ) # finds DEBUG message

  if ( node ): # if found
    nodeID = node.group(1)

  send = re.search( r'\w+ \(\d+\): send (\d+) (\d+)', line, re.M | re.I ) # finds SEND message

  if ( send ):
    handleSend( nodeID, send )

  recv = re.search( r'\w+ \(\d+\): receive (\d+) (\d+)', line, re.M | re.I ) # finds SEND message

  if ( recv ):
    handleReceive( nodeID, recv )

fd.close()

printActualPerNodeTransmissions() 
printTotalTransmissions()
printAveragePerNodeTransmissions()
printCoverage()
print "Minimum, average and maximum message latency"
# search the file for the 1st occurence of a message, and search the file for the last occur of each message
#printMessages()
calcLatency()