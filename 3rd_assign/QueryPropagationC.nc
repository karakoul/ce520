#include "QueryPropagation.h"
//#define QUERY_SERIAL

module QueryPropagationC
{
  uses 
  {
    interface Timer<TMilli> as QueryTimer;
    interface Timer<TMilli> as ForwardQueryTimer;
    interface Timer<TMilli> as SensorTimer;
    interface Timer<TMilli> as ResultTimer;
    interface Boot;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface AMSend;
    interface Receive;
    interface Read<uint16_t>;
    interface Leds;

#ifdef QUERY_SERIAL
    interface Timer<TMilli> as Broadcast;
    interface Receive as SerialRec;
#endif
  }
}

implementation
{
  message_t queryPacket;
  message_t fwdQueryPacket;
  message_t nonePacket;
  message_t resultPacket;
  uint16_t seqNo;
  bool broadcastBusy;
  bool forwardBusy;
  uint16_t nodeID;
  query_t cache[MAX_CACHE_SIZE];
  uint16_t index;
  uint16_t fwdIndex;
  bool sensorState[3];
  /*none_t*/
  none_t results[MAX_CACHE_SIZE];
  uint16_t parent;
  uint16_t noneIndex;
  uint16_t noneFwdIndex;

  event void Boot.booted()
  {
    int i;

    seqNo = 0;
    index = 0;
    fwdIndex = 0;
    broadcastBusy = FALSE;
    forwardBusy = FALSE;
    parent = 0;
    noneIndex = 0;
    noneFwdIndex = 0;

    for( i = 0; i < 3; i++ )
    {
      sensorState[i] = FALSE;
    }
    for( i = 0; i < MAX_CACHE_SIZE; i++ )
    {
      cache[i].sensorID = 0;
      cache[i].seqNo = 0;
      cache[i].sensorT = 0;
      cache[i].samplingPeriod = 0;
      cache[i].lifeTime = 0;
      cache[i].aggregationMode = 0;
      cache[i].currentPeriod = 0;
      cache[i].address = 0;

      results[i].sensorID = 0;
      results[i].sensorValue = 0;
      results[i].iterPeriod = 0;
    }

    call AMControl.start();
  }

  event void AMControl.startDone( error_t error )
  {
    if ( error == SUCCESS )
    {
      nodeID = TOS_NODE_ID;

      // for simulation purposes only
#ifndef QUERY_SERIAL
      if(nodeID == 1){
        call QueryTimer.startOneShot( 1000 );
      }
#endif

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
    cache[index] = *query;
    index = ( index + 1 ) % MAX_CACHE_SIZE;
    call SensorTimer.startPeriodic(query->samplingPeriod);

    if ( call AMSend.send( AM_BROADCAST_ADDR, &queryPacket, sizeof( query_t ) ) == SUCCESS )
    {
      dbg( "Query", "Query Init: Type = %d, Time: %s\n", query->sensorT, sim_time_string() );
      broadcastBusy = TRUE;
    }

  }

#ifdef QUERY_SERIAL
  event void Broadcast.fired()
  {

  }

  event message_t* SerialRec.receive( message_t* msg, void* payload, uint8_t len )
  {
    if ( len != sizeof( query_t ) )
    {
      return msg;
    }
    else
    {
      int i;
      query_t* recvMsg;
      recvMsg = ( query_t * ) payload;
      
      recvMsg->address = call AMPacket.address();
      cache[ index ] = *recvMsg;

      index = ( index + 1 ) % MAX_CACHE_SIZE;
      
      call ForwardQueryTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );


      return msg;
    }
  }
#endif

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
    cache[0].currentPeriod += 1;
    dbg("Lifetime", "New lifetime = %d \n", cache[0].lifeTime);

    if( cache[0].lifeTime < cache[0].samplingPeriod )
    {
      dbg("Lifetime", "Lifetime expired\n");
      call SensorTimer.stop();
    }
  }

  event void Read.readDone(error_t result, uint16_t data) 
  {
    //dbg("Brightness", "Check %d \n", data);
    if(result == SUCCESS) 
    {

      none_t *resultMsg = ( none_t * ) call Packet.getPayload( &nonePacket, sizeof( none_t ) );;
      

      resultMsg->sensorID = cache[0].sensorID;
      resultMsg->sensorValue = data+nodeID;
      resultMsg->iterPeriod = cache[0].currentPeriod;

      if ( call AMSend.send( cache[0].address, &nonePacket, sizeof( none_t ) ) == SUCCESS )
      {
        dbg( "Query", "Results Send: Type = %d, Time: %s\n", resultMsg->sensorValue, sim_time_string() );
        broadcastBusy = TRUE;
      }

    }
    
    
  }
  event void ResultTimer.fired()
  {
    if ( broadcastBusy == TRUE && forwardBusy == TRUE )
    {
      call ResultTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      none_t* sendResult = ( none_t * ) call Packet.getPayload( &resultPacket, sizeof( none_t ) );

      if ( sendResult == NULL )
      {
        return;
      }
      *sendResult = results[ noneFwdIndex ];

      if ( call AMSend.send( parent, &resultPacket, sizeof( none_t ) ) == SUCCESS )
      {
        dbg("Query", "Query Forward %d %d, time: %s\n", sendResult->sensorID, sendResult->iterPeriod, sim_time_string());
        forwardBusy = TRUE;
        noneFwdIndex = ( noneFwdIndex + 1 ) % MAX_CACHE_SIZE;
      }

    }

  }

  event void AMSend.sendDone( message_t *msg, error_t error )
  {
    if ( &queryPacket == msg || &nonePacket == msg)
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
    int i;
    if ( len == sizeof( none_t ) )
    {
      none_t *recvResult;
      recvResult = ( none_t * ) payload; 
      //check if it is already in
        
      if( recvResult->sensorID == nodeID )
      {
        dbg("None", "result for iteration %d is %d\n", recvResult->iterPeriod, recvResult->sensorValue);
        return msg;
      }
      for ( i = 0; i < MAX_CACHE_SIZE; i++ )
      {
        if ( ( results[i].sensorID == recvResult->sensorID ) && ( results[i].iterPeriod >= recvResult->iterPeriod ) )
        {
          dbg( "Debug", "Discard\n" );
          return msg;
        }

      } 
      results[ noneIndex ] = *recvResult;

      noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;

      call ResultTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return msg;
    }

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

      recvQuery->address = call AMPacket.address();
      cache[ index ] = *recvQuery;

      index = ( index + 1 ) % MAX_CACHE_SIZE;

      parent = cache[0].address;

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