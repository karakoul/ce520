#include "QueryPropagation.h"

module QueryPropagationC
{
  uses 
  {
    interface Timer<TMilli> as QueryTimer;
    interface Timer<TMilli> as ForwardQueryTimer;
    interface Timer<TMilli> as SensorTimer;
    interface Timer<TMilli> as ResultTimer;
    interface Timer<TMilli> as PiggybackTimer;
    interface Boot;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface AMSend as Radio;
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
  message_t packet;
  uint8_t depth, subTreeDepth;
  
  uint16_t seqNo;
  bool sendBusy;
  uint16_t nodeID;
  query_t cache[MAX_CACHE_SIZE];
  uint16_t index;
  uint16_t fwdIndex;
  bool sensorState[3];
  
  /*none*/
  none_t results[MAX_CACHE_SIZE];
  uint16_t parent;
  uint16_t noneIndex;
  uint16_t noneFwdIndex;
  
  /*piggyback*/
  cacheP_t cacheP[PAYLOAD_LENGTH];
  uint16_t timerStep;
  uint16_t duration;
  uint16_t waitingPeriod;

  event void Boot.booted()
  {
    int i, j;

    subTreeDepth = 1;
    depth = 0;

    seqNo = 0;
    index = 0;
    fwdIndex = 0;
    sendBusy = FALSE;
    parent = 0;
    noneIndex = 0;
    noneFwdIndex = 0;

    timerStep = 1;
    duration = 0;
    waitingPeriod = 0;


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

    for ( i = 0; i < PAYLOAD_LENGTH; i++ )
    {
      cacheP[i].iter = 0;
      for ( j = 0; j < PAYLOAD_LENGTH; j++ )
      {
        cacheP[i].sensorValue[j] = 0;
      }
      cacheP[i].check = FALSE;
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
    query_t *query;

    if ( sendBusy == TRUE )
    {
      call QueryTimer.startOneShot(1);
      return;
    }
    
    query = ( query_t * ) call Packet.getPayload( &packet, sizeof( query_t ) );

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
    query->depth = 0;
    query->aggregationMode = 0;

    // seqNo++;
    cache[index] = *query;
    index = ( index + 1 ) % MAX_CACHE_SIZE;
    call SensorTimer.startPeriodic(query->samplingPeriod);

    if ( call Radio.send( AM_BROADCAST_ADDR, &packet, sizeof( query_t ) ) == SUCCESS )
    {
      dbg( "Query", "Query Init: Type = %d, Time: %s\n", query->sensorT, sim_time_string() );
      sendBusy = TRUE;
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
    if ( sendBusy == TRUE )
    {
      call ForwardQueryTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      query_t* broadcastQuery = ( query_t * ) call Packet.getPayload( &packet, sizeof( query_t ) );

      if ( broadcastQuery == NULL )
      {
        return;
      }
      *broadcastQuery = cache[ fwdIndex ];

      if ( call Radio.send( AM_BROADCAST_ADDR, &packet, sizeof( query_t ) ) == SUCCESS )
      {
        dbg("Query", "Query Forward %d %d, time: %s\n", broadcastQuery->sensorID, broadcastQuery->seqNo, sim_time_string());
        sendBusy = TRUE;
        fwdIndex = ( fwdIndex + 1 ) % MAX_CACHE_SIZE;
      }

    }
  }

  event void SensorTimer.fired()
  {
    //metrhsh
    call Read.read();

    
  }

  event void Read.readDone(error_t result, uint16_t data) 
  {
    //dbg("Brightness", "Check %d \n", data);
    if(result == SUCCESS) 
    {
      if(cache[0].aggregationMode == NONE )
      {
        none_t *resultMsg = ( none_t * ) call Packet.getPayload( &packet, sizeof( none_t ) );;
        
        
        resultMsg->sensorID = cache[0].sensorID;
        resultMsg->sensorValue = nodeID; //gia real time prepei na valoume data adi gia nodeid
        resultMsg->iterPeriod = cache[0].currentPeriod;


        if( cache[0].sensorID == nodeID )
        { 
          dbg("None", "EIMAI O ORIGINATOR result for iteration %d is %d\n", resultMsg->iterPeriod, resultMsg->sensorValue);
          dbg("DEBUG",  "eimai o ORIGINATOR  %d kai phra metrhsh\n",cache[0].sensorID);
        }
        else if ( call Radio.send( parent, &packet, sizeof( none_t ) ) == SUCCESS )
        {
          dbg( "Query", "Results Send: Type = %d, Time: %s\n", resultMsg->sensorValue, sim_time_string() );
          dbg("DEBUG",  "eimai o komvos %d kai esteila ta result ston %d gi thn samplingPeriod %d\n",nodeID,parent,cache[0].currentPeriod);
          sendBusy = TRUE;
        }

      }
      else if ( cache[0].aggregationMode == PIGGYBACK )
      {
        int i,j, check = FALSE;

        for ( i = 0; i < PAYLOAD_LENGTH; i++ )
        {
          if(cacheP[i].iter == cache[0].currentPeriod)
          {
            for ( j = 0; j < PAYLOAD_LENGTH; j++ )
            {
              if (cacheP[i].sensorValue[j] == 0 ){
                cacheP[i].sensorValue[j] = nodeID; // DATA
                check = TRUE;
                cacheP[i].iter = cache[0].currentPeriod;
                break;
              }
            } 
            
            if(check)
            {
              break;
            }
          }
        }      
      }
    }

    cache[0].lifeTime -= cache[0].samplingPeriod;
    cache[0].currentPeriod += 1;
    dbg("Lifetime", "New lifetime = %d \n", cache[0].lifeTime);

    if( cache[0].lifeTime < cache[0].samplingPeriod )
    {
      dbg("Lifetime", "Lifetime expired\n");
      call SensorTimer.stop();
    }
    piggyback_t *sendMsg;
    int len = 0;
    int numofmes = 0;
    int i,j;

    for(i = 0; i < PAYLOAD_LENGTH; i++)
    {
      if(cacheP[i].iter == waitingPeriod){
        for(j = 0; j < PAYLOAD_LENGTH; j++)
        {
          if(cacheP[i].sensorValue[j] != 0)
          {
            numofmes++;
          }
          else
          {
            break;
          }

        }
      }
    }


    
    
  }

  event void PiggybackTimer.fired()
  {

  }

  event void ResultTimer.fired()
  {
    if ( sendBusy == TRUE )
    {
      call ResultTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      none_t* sendResult = ( none_t * ) call Packet.getPayload( &packet, sizeof( none_t ) );

      if ( sendResult == NULL )
      {
        return;
      }
      *sendResult = results[ noneFwdIndex ];

      if ( call Radio.send( parent, &packet, sizeof( none_t ) ) == SUCCESS )
      {
        dbg("Query", "Query Forward %d %d, time: %s\n", sendResult->sensorID, sendResult->iterPeriod, sim_time_string());
        dbg("DEBUG","eimai o komvos %d kai stelnw to munhma tou komvou %d gia thn samplingPeriod %d\n",nodeID,sendResult->sensorValue,sendResult->iterPeriod);
        sendBusy = TRUE;
        noneFwdIndex = ( noneFwdIndex + 1 ) % MAX_CACHE_SIZE;
      }

    }

  }

  event void Radio.sendDone( message_t *msg, error_t error )
  {
    if ( &packet == msg )
    {
      sendBusy = FALSE;
    }
  }

  event message_t *Receive.receive( message_t *msg, void *payload, uint8_t len )
  {
    int i, j, count = 0, fixedDuration = 0;
    
    if ( len == sizeof( none_t ) )
    {
      none_t *recvResult;
      recvResult = ( none_t * ) payload; 
      
      if( recvResult->sensorID == nodeID )
      {
        dbg("None", "result for iteration %d is %d\n", recvResult->iterPeriod, recvResult->sensorValue);
        return msg;
      }

      results[ noneIndex ] = *recvResult;

      noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;

      call ResultTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );
      return msg;
    }
    else if ( len == sizeof( piggyback_t ) )
    {
      piggyback_t *recvResult;
      recvResult = ( piggyback_t * ) payload;

      if ( subTreeDepth < recvResult->depth - depth )
      {
        subTreeDepth = recvResult->depth - depth;
      }

      if(recvResult->iterPeriod < waitingPeriod){
        piggyback_t* sendResult = ( piggyback_t * ) call Packet.getPayload( &packet, sizeof( piggyback_t ) );
        timerStep *= 10;
        duration = subTreeDepth*(cache[0].samplingPeriod*timerStep);

        if ( sendResult == NULL )
        {
          return;
        }
        recvResult->depth = depth;
        sendResult = recvResult;
        if ( call Radio.send( parent, &packet, sizeof( piggyback_t ) ) == SUCCESS )
        {
          sendBusy = TRUE;
        }
        //kaloume timer pali me upologismeno to duration sumfwna me oso exei hdh perimenei
        fixedDuration = call PiggybackTimer.getNow();
        fixedDuration -= call PiggybackTimer.gett0();
        call PiggybackTimer.startOneShot(duration - fixedDuration);
        return msg;
      }

//prepei se periptwsh p den exei xwro na bei na tsekarw to check(dhladh oti einai kapoio diegrameno)! auto prepei na ginei kai sth read pou apothhkeuei ta dika tou apotelesmata!!!!!!
      for( i = 0; i < PAYLOAD_LENGTH; i++ )
      {
        if(recvResult->sensorValue[count] == 0){
            break;
        }
        if(recvResult->iterPeriod == cacheP[i].iter){
          for( j = 0; j < PAYLOAD_LENGTH; j++ )
          {
            if(cacheP[i].sensorValue[j] == 0 && recvResult->sensorValue[count] != 0){
              cacheP[i].sensorValue[j]  = recvResult->sensorValue[count];
              count++;
            }
            if(recvResult->sensorValue[count] == 0){
              break;
            }
          }
      }


    }
    else if ( len != sizeof( query_t ) ) // check if type is aggregationType
    {
      dbg( "Query", "RECEIVED\n");
      return msg;
    }
    else
    {
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
          //dbg( "Debug", "Discard\n" );
          return msg;
        }

      }

      parent = recvQuery->address;
      recvQuery->address = call AMPacket.address();
      recvQuery->depth++;
      depth = recvQuery->depth;
      dbg("Depth","my depth is %d\n",depth);
      cache[ index ] = *recvQuery;

      index = ( index + 1 ) % MAX_CACHE_SIZE;


      call ForwardQueryTimer.startOneShot( nodeID * BROADCAST_PERIOD_MILLI );

      duration = subTreeDepth*cache[0].samplingPeriod*timerStep;
      call PiggybackTimer.startOneShot(duration);

      if( sensorState[ recvQuery->sensorT ] == FALSE )
      {
        sensorState[ recvQuery->sensorT ] = TRUE;
        call SensorTimer.startPeriodic( recvQuery->samplingPeriod *1000);
      }

      

      return msg;
    }
  }

}