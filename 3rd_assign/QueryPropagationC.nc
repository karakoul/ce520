#include "QueryPropagation.h"

module QueryPropagationC
{
  uses 
  {
    interface Timer<TMilli> as QueryTimer;
    interface Boot;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMSend;
    interface Receive;
  }
}

implementation
{
  message_t queryPacket;
  uint16_t seqNo;
  bool broadcastBusy;
  uint16_t nodeID;

  event void Boot.booted()
  {
    seqNo = 0;
    broadcastBusy = FALSE;

    call AMControl.start();
  }

  event void AMControl.startDone( error_t error )
  {
    if ( error == SUCCESS )
    {
      nodeID = TOS_NODE_ID;

      // for simulation purposes only
      call QueryTimer.startOneShot( 1000 );

    }
    else
    {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone( error_t error ) {}

  /* For simulation purpose only */
  event void QueryTimer.fired()
  {
    query_t *query = ( query_t * ) call Packet.getPayload( &queryPacket, sizeof( query_t ) );

    if ( query == NULL )
    {
      return;
    }

    query->sensorID = nodeID;
    query->seqNo = seqNo;
    query->sensorT = BRIGHTNESS;
    query->samplingPeriod = 1;
    query->lifeTime = 5;

    // seqNo++;

    if ( call AMSend.send( AM_BROADCAST_ADDR, &queryPacket, sizeof( query_t ) ) == SUCCESS )
    {
      dbg( "Query", "Query Init: Type = %d, Time: %s\n", query->sensorT, sim_time_string() );
      broadcastBusy = TRUE;
    }

  }

  event void AMSend.sendDone( message_t *msg, error_t error )
  {
    if ( &queryPacket == msg )
    {
      broadcastBusy = FALSE;
    }
  }

  event message_t* Receive.receive( message_t* msg, void* payload, uint8_t len )
  {
    if ( len != sizeof( query_t ) ) // check if type is aggregationType
    {
      return msg;
    }
    else
    {
      int i;
      query_t *recvQuery;
      recvQuery = ( query_t * ) payload;

      dbg( "Query", "Query Receive Type: %d samplingPeriod: %d  lifeTime: %d, time: %s\n", recvQuery->sensorT, recvQuery->samplingPeriod, recvQuery->lifeTime, sim_time_string() );

      if ( recvQuery->sensorID == nodeID )
      {
        return msg;
      }

      /*for ( i = 0; i < MAX_CACHE_SIZE; i++ )
      {
        if ( ( cache[i].sourceID == recvMsg->sourceID ) && ( cache[i].seqNo >= recvMsg->seqNo ) )
        {
          dbg( "Debug", "Discard\n" );
          return msg;
        }

      }*/

      //cache[ index ] = *recvMsg;

      //index = ( index + 1 ) % MAX_CACHE_SIZE;

      return msg;
    }
  }

}