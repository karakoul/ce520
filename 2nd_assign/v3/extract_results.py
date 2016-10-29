import re
from collections import defaultdict

messages = []
numOfNodes = 17
nodes = defaultdict( list )
totalTransmissions = 0;
recvMessages = defaultdict( list )

class Message():

  def __init__( self, srcID, seqNo ):
      self.srcID = srcID
      self.seqNo = seqNo
      self.transmissions = 1

  def __hash__( self ):
    return hash( ( self.srcID, self.seqNo ) )

  def __eq__( self, other ):
    return ( self.srcID, self.seqNo ) == ( other.srcID, other.seqNo )

  def __ne__( self, other ):
    return not ( self == other )

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
    print "SourceID: " + str( self.srcID ) + " SeqNo: " + str( self.seqNo ) + " Transmitted: " + str( self.transmissions )



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

  print msg


def printAveragePerNodeTransmissions():
  print "Average per node transmissions"

def printCoverage():
  total_message_received = 0
  msg = "\n============= Coverage =============\n"
  for message in messages:
    nodeRecv = 0
    recvBy = []
    msg += "Message with sourceID: " + str( message.getSrcID() ) + " seqNo: " + str( message.getSeqNo() ) + " has been received by "

    for node in recvMessages:
      if ( message in recvMessages[ node ].get( node ) ):
        nodeRecv += 1
        recvBy.append( node )

    total_message_received += nodeRecv
    msg += str( nodeRecv ) + "/" + str( numOfNodes ) + " nodes  Received by: " + str( recvBy ) + "\n" 

    # for each message
    # 
  print msg
  print total_message_received/float(len(messages)*numOfNodes)

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

printActualPerNodeTransmissions() 
printTotalTransmissions()
#printAveragePerNodeTransmissions()
print "Coverage (number of nodes that received a given message)"
printCoverage()
print "Minimum, average and maximum message latency"
printMessages()