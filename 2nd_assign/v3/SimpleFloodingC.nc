/**
 * Assignment 2
 *
 * Develop an algorithm/mechanism for a best-effort network-wide broadcast.
 * The approach is to propagate a packet to nodes using simple flooding. 
 * For each broadcast, the system should, eventually, reach a steady silent state where nodes stop transmitting packets. 
 * To achieve this, duplicate packets should be handled appropriately.
 * Your mechanism should also try to avoid collisions that might occur 
 * if two or more nodes that are in range of each other attempt to transmit a packet simultaneously. 
 * This is especially important given that the radio support of the sensor nodes is rather simple 
 * (there are no sophisticated collision detection/avoidance schemes).
 *
 * Evaluate your algorithm in TOSSIM for different network topologies (chain, tree, grid), different number of nodes, 
 * and different number of concurrent sources. Use an application issues a broadcast periodically. 
 * For each case, record (i) the actual per-node transmissions, (ii) the total number of transmissions, 
 * (iii) the average per-node transmissions, (iv) the coverage (number of nodes that received a given message), 
 * and (v) the minimum, average and maximum message latency.
 * 
 * Develop a simple application that uses the mechanism to propagate to the network every message it receives over the serial port
 * 
 * Staging
 *
 * 1. Develop and test your flooding mechanism using TOSSIM
 * 2. Develop code that receives a packet from the serial port
 * 3. Add code to transmit the received packet via the broadcast mechanism
 * 4. Add your flooding algorithm 
 *
 * Hints
 *
 * Read carefully the radio communication tutorial
 * Think how to use the LEDs of the nodes in order to visualize the state of the system during real trials, 
 * in a practical way that is easy to observe.
 * Try to see how well randomness works vs more deterministic back-off algorithms.
 * Note that when using TOSSIM all nodes will run the same code/firmware. 
 * Node-specific behavior in the simulations can be achieved by introducing branches in the code, based on the local node identifier.
 * 
 * @author Apostolos Tsaousis
 * @author Katerina Karakoula
 * @date   October 28 2016
 */

#define SIMPLE_FLOODING_BUTTON

#include "Timer.h"
#include "SimpleFlooding.h"
#include <stdlib.h>
#ifdef SIMPLE_FLOODING_BUTTON
#include <UserButton.h>
#endif

module SimpleFloodingC
{
  uses 
  {
    interface Timer<TMilli> as Forward;
#ifndef SIMPLE_FLOODING_BUTTON
    interface Timer<TMilli> as Broadcast;
#endif
    interface Leds;
    interface Boot;
    interface SplitControl as AMControl;
    interface Packet;
    interface Receive as Rec;
    interface Receive as SerialRec;
    interface AMSend;
#ifdef SIMPLE_FLOODING_BUTTON
	  interface Get<button_state_t>;
	  interface Notify<button_state_t>;
    interface AMPacket;
#endif
  }
}

implementation
{
  
  bcast_msg_t cache[ MAX_CACHE_SIZE ];
  uint16_t nodeID;
  uint16_t seqNo = 1;
  uint8_t index = 0;
  uint8_t fwdIndex = 0;
  uint8_t broadcasts = 0;
  bool broadcastBusy = FALSE;
  bool forwardBusy = FALSE;
  message_t broadcastPacket;
  message_t forwardPacket;
  bcast_msg_t* forwardMsg;

  task void init()
  {
    int i;

    for ( i = 0; i < MAX_CACHE_SIZE; i++ )
    {
      cache[i].sourceID = 0;
      cache[i].seqNo = 0;
    }

    dbg( "Debug", "Cache init\n" );
  }

  event void Boot.booted()
  {

    post init();
	
#ifdef SIMPLE_FLOODING_BUTTON
	call Notify.enable();
#endif
	
    call AMControl.start();
  }

  event void AMControl.startDone( error_t error )
  {
    if ( error == SUCCESS )
    {
      nodeID = TOS_NODE_ID;

	  #ifndef SIMPLE_FLOODING_BUTTON
      dbg( "Debug", "nodeID: %d\n", nodeID );
	
      if ( nodeID % 2 == 1 )
      {
        call Broadcast.startPeriodic( ((BROADCAST_PERIOD_MILLI)+1) * 100 * nodeID ); // Attempts to send a new bcast message every 'x' ms
      }
	  #endif
    }
    else
    {
      call AMControl.start();
    }
  }

  event message_t* Rec.receive( message_t* msg, void* payload, uint8_t len )
  {
    if ( len != sizeof( bcast_msg_t ) )
    {
      return msg;
    }
    else
    {
      int i;
      bcast_msg_t* recvMsg;
      recvMsg = ( bcast_msg_t * ) payload;

      dbg("Receive", "receive %d %d, time: %s\n", recvMsg->sourceID, recvMsg->seqNo, sim_time_string());


      if ( recvMsg->sourceID == nodeID )
      {
        dbg( "Debug", "Discard\n" );
        return msg;
      }

      for ( i = 0; i < MAX_CACHE_SIZE; i++ )
      {
        if ( ( cache[i].sourceID == recvMsg->sourceID ) && ( cache[i].seqNo >= recvMsg->seqNo ) )
        {
          dbg( "Debug", "Discard\n" );
          return msg;
        }

      }

      cache[ index ] = *recvMsg;
      dbg( "Debug", "Cache[%d]: %d:%d\n", index, cache[index].sourceID, cache[index].seqNo );
	  if(recvMsg->sourceID == 1){
		call Leds.led0Toggle();
	  } else if(recvMsg->sourceID == 2){
		  call Leds.led1Toggle();
	  }
	  else{
		  call Leds.led2Toggle();
	  }

      index = ( index + 1 ) % MAX_CACHE_SIZE;

      dbg( "SimpleFloodingC", "Received Message with sourceID: %d and seqNo: %d\n", recvMsg->sourceID, recvMsg->seqNo );

      call Forward.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );

      return msg;
    }
  }

  event void AMControl.stopDone( error_t error ) {}

  event void AMSend.sendDone( message_t* msg, error_t error )
  {
    if ( &broadcastPacket == msg )
    {
      dbg( "Debug", "Bcast Sent done %s\n", sim_time_string() );

      broadcastBusy = FALSE;
    }
    else if ( &forwardPacket == msg )
    {
      dbg( "Debug", "Fwd Sent done %s\n", sim_time_string() );

      forwardBusy = FALSE;
    }

  }

  event void Forward.fired()
  {
    if ( forwardBusy == TRUE )
    {
      call Forward.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      bcast_msg_t* broadcastMsg = ( bcast_msg_t * ) call Packet.getPayload( &forwardPacket, sizeof( bcast_msg_t ) );

      if ( broadcastMsg == NULL )
      {
        return;
      }

      *broadcastMsg = cache[ fwdIndex ];

      if ( call AMSend.send( AM_BROADCAST_ADDR, &forwardPacket, sizeof( bcast_msg_t ) ) == SUCCESS )
      {
        dbg( "Debug", "Send %s\n", sim_time_string() );
        dbg("Send", "send %d %d, time: %s\n", broadcastMsg->sourceID, broadcastMsg->seqNo, sim_time_string());
        forwardBusy = TRUE;
        fwdIndex = ( fwdIndex + 1 ) % MAX_CACHE_SIZE;
      }

    }


  }

#ifndef SIMPLE_FLOODING_BUTTON
  event void Broadcast.fired()
  {
    if ( broadcastBusy == TRUE )
    {
      return;
    }
    else
    {
      bcast_msg_t* broadcastMsg = ( bcast_msg_t * ) call Packet.getPayload( &broadcastPacket, sizeof( bcast_msg_t ) );

      if ( broadcastMsg == NULL )
      {
        return;
      }

      broadcastMsg->sourceID = nodeID;
      broadcastMsg->seqNo = seqNo;

      seqNo++;
      broadcasts++;

      dbg( "Debug", "Broadcast started @ %s\n", sim_time_string() );
      dbg( "SimpleFloodingC", "Broadcasted message with nodeID: %d and seqNo: %d\n", broadcastMsg->sourceID, broadcastMsg->seqNo );

      if ( call AMSend.send( AM_BROADCAST_ADDR, &broadcastPacket, sizeof( bcast_msg_t ) ) == SUCCESS )
      {
        dbg( "Debug", "Sent %s\n", sim_time_string() );
        dbg("Send", "send %d %d, time: %s\n", broadcastMsg->sourceID, broadcastMsg->seqNo, sim_time_string());

        broadcastBusy = TRUE;
      }
      if ( broadcasts == MAX_BROADCASTS )
      {
        call Broadcast.stop();
        dbg( "Debug", "Broadcast stopped\n" );
      }

    }
  }
#endif

#ifdef SIMPLE_FLOODING_BUTTON
	event void Notify.notify(button_state_t state)
	{
		bcast_msg_t* broadcastMsg = ( bcast_msg_t * ) call Packet.getPayload( &broadcastPacket, sizeof( bcast_msg_t ) );
		
		broadcastMsg->sourceID = nodeID;
		broadcastMsg->seqNo = seqNo;

		seqNo++;
		if ( call AMSend.send( AM_BROADCAST_ADDR, &broadcastPacket, sizeof( bcast_msg_t ) ) == SUCCESS )
		{
			broadcastBusy = TRUE;
		}
	} 
event message_t* SerialRec.receive( message_t* msg, void* payload, uint8_t len ) {
    if ( len != sizeof( bcast_msg_t ) )
    {
      return msg;
    }
    else
    {
      int i;
      bcast_msg_t* recvMsg;
      recvMsg = ( bcast_msg_t * ) payload;
     call Leds.led1Toggle();

      dbg("Receive", "receive %d %d, time: %s\n", recvMsg->sourceID, recvMsg->seqNo, sim_time_string());


      if ( recvMsg->sourceID == nodeID )
      {
        dbg( "Debug", "Discard\n" );
        return msg;
      }

      for ( i = 0; i < MAX_CACHE_SIZE; i++ )
      {
        if ( ( cache[i].sourceID == recvMsg->sourceID ) && ( cache[i].seqNo >= recvMsg->seqNo ) )
        {
          dbg( "Debug", "Discard\n" );
          return msg;
        }

      }

      cache[ index ] = *recvMsg;
      dbg( "Debug", "Cache[%d]: %d:%d\n", index, cache[index].sourceID, cache[index].seqNo );
      if(recvMsg->sourceID == 1){
      call Leds.led0Toggle();
      } else if(recvMsg->sourceID == 2){
        call Leds.led1Toggle();
      }
      else{
        call Leds.led2Toggle();
      }

        index = ( index + 1 ) % MAX_CACHE_SIZE;

        dbg( "SimpleFloodingC", "Received Message with sourceID: %d and seqNo: %d\n", recvMsg->sourceID, recvMsg->seqNo );

        call Forward.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );

        return msg;
      }
}
#endif
}

