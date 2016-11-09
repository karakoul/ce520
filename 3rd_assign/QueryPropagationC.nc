#include "QueryPropagation.h"

module QueryPropagationC
{
  uses 
  {
    interface Timer<TMilli> as QueryTimer;
    interface Timer<TMilli> as ForwardQueryTimer;
    interface Timer<TMilli> as SensorTimer;
    interface Boot;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface Receive;
    interface Read<uint16_t>;
  }
}

implementation
{
  message_t queryPacket;
  message_t fwdQueryPacket;
  message_t nonePacket;
  uint16_t seqNo;
  bool broadcastBusy;
  bool forwardBusy;
  uint16_t nodeID;
  query_t cache[MAX_CACHE_SIZE];
  uint16_t index;
  uint16_t fwdIndex;
  bool sensorState[3];

  event void Boot.booted()
  {
    int i;

    seqNo = 0;
    index = 0;
    fwdIndex = 0;
    broadcastBusy = FALSE;
    forwardBusy = FALSE;

    for( i = 0; i < 3; i++ )
    {
      sensorState[i] = FALSE;
    }

    call AMControl.start();
  }

  event void AMControl.startDone( error_t error )
  {
    if ( error == SUCCESS )
    {
      nodeID = TOS_NODE_ID;

      // for simulation purposes only
      if(nodeID == 1){
        call QueryTimer.startOneShot( 1000 );
      }

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

    if(broadcastBusy == TRUE && forwardBusy == TRUE){
      call QueryTimer.startOneShot(1);
      return;
    }

    if ( query == NULL )
    {
      return;
    }

    query->sensorID = nodeID;
    query->seqNo = seqNo;
    query->sensorT = BRIGHTNESS;
    query->samplingPeriod = 1;
    query->lifeTime = 5;
    query->currentPeriod = 0;
    query->address = call AMPacket.address();

    dbg("Query", "Sender address %d\n", query->address);

    // seqNo++;

    if ( call AMSend.send( AM_BROADCAST_ADDR, &queryPacket, sizeof( query_t ) ) == SUCCESS )
    {
      dbg( "Query", "Query Init: Type = %d, Time: %s\n", query->sensorT, sim_time_string() );
      broadcastBusy = TRUE;
    }

  }

   event void ForwardQueryTimer.fired()
  {
    if ( broadcastBusy == TRUE && forwardBusy == TRUE )
    {
      call ForwardQueryTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      query_t* broadcastQuery = ( query_t * ) call Packet.getPayload( &fwdQueryPacket, sizeof( query_t ) );

      if ( broadcastQuery == NULL )
      {
        return;
      }

      *broadcastQuery = cache[ fwdIndex ];

      if ( call AMSend.send( AM_BROADCAST_ADDR, &fwdQueryPacket, sizeof( query_t ) ) == SUCCESS )
      {
        //dbg( "Debug", "Send %s\n", sim_time_string() );
        dbg("Query", "Query Forward %d %d, time: %s\n", broadcastQuery->sensorID, broadcastQuery->seqNo, sim_time_string());
        forwardBusy = TRUE;
        fwdIndex = ( fwdIndex + 1 ) % MAX_CACHE_SIZE;
      }

    }
  }

  event void SensorTimer.fired()
  {
    //metrhsh
    call Read.read();

    cache[0].lifeTime -= cache[0].samplingPeriod;
    dbg("Lifetime", "New lifetime = %d \n", cache[0].lifeTime);

    if( cache[0].lifeTime < cache[0].samplingPeriod )
    {
      dbg("Lifetime", "Lifetime expired\n");
      call SensorTimer.stop();
    }
  }

  event void Read.readDone(error_t result, uint16_t data) 
  {
//    dbg("Brightness", "Check %d \n", data);
    if(result == SUCCESS) 
    {
      aggregation_none_t *resultMsg = ( aggregation_none_t * ) call Packet.getPayload( &nonePacket, sizeof( aggregation_none_t ) );;

      resultMsg->sensorID = nodeID;
      resultMsg->sensorValue = data;
      resultMsg->iterPeriod = 0;

      if ( call AMSend.send( cache[0].address, &nonePacket, sizeof( aggregation_none_t ) ) == SUCCESS )
      {
        dbg( "Query", "Results Send: Type = %d, Time: %s\n", resultMsg->sensorValue, sim_time_string() );
        broadcastBusy = TRUE;
      }

    }
    else 
    {
      return;
    }
    
    
  }

  event void AMSend.sendDone( message_t *msg, error_t error )
  {
    if ( &queryPacket == msg )
    {
      broadcastBusy = FALSE;
    }
    else if( &fwdQueryPacket == msg )
    {
      forwardBusy = FALSE;
    }
  }

  event message_t* Receive.receive( message_t* msg, void* payload, uint8_t len )
  {
    if ( len != sizeof( query_t ) ) // check if type is aggregationType
    {
       dbg( "Query", "RECEIVED\n");
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

      for ( i = 0; i < MAX_CACHE_SIZE; i++ )
      {
        if ( ( cache[i].sensorID == recvQuery->sensorID ) && ( cache[i].seqNo >= recvQuery->seqNo ) )
        {
          dbg( "Debug", "Discard\n" );
          return msg;
        }

      }

      cache[ index ] = *recvQuery;

      index = ( index + 1 ) % MAX_CACHE_SIZE;

      call ForwardQueryTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );

      if( sensorState[ recvQuery->sensorT ] == FALSE )
      {
        sensorState[ recvQuery->sensorT ] = TRUE;
        call SensorTimer.startPeriodic( recvQuery->samplingPeriod *1000);
      }

      

      return msg;
    }
  }

}