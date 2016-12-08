#include "QueryPropagation.h"

module QueryPropagationC
{
  uses 
  {

    interface Timer<TMilli> as QueryTimer;
    interface Timer<TMilli> as ForwardQueryTimer;
    interface Timer<TMilli> as SensorTimer;
    interface Timer<TMilli> as PiggybackTimer;
    interface Timer<TMilli> as StatsTimer;
    interface Timer<TMilli> as JoinTimer;
    interface Timer<TMilli> as ResultTimer;
    interface Timer<TMilli> as Broadcast;

    interface SplitControl as RadioAMControl;
    interface SplitControl as SerialAMControl;
    interface Packet as RadioPacket;
    interface Packet as SerialPacket;
    interface AMPacket as SerialAMPacket;
    interface AMPacket as RadioAMPacket;
    interface AMSend as RadioSend;
    interface AMSend as SerialSend;
    interface Receive as RadioReceive;
    interface Receive as SerialReceive;

    interface Boot;
    interface Read<uint16_t>;
    interface Leds;

  }
}

implementation
{
  message_t packet;
  uint8_t depth, subTreeDepth;
  bool sendBusy;
  
  am_addr_t parent;
  
  /*piggyback*/
  uint16_t timerStep;
  uint16_t duration;
  uint16_t waitingPeriod;
  uint16_t children;
  uint16_t lifeTime;

  query_t queryCache;
  cacheP_t metrics[ 10 ];

  piggyback_t resultsP[MAX_CACHE_SIZE];

  /*stats*/
  cacheS_t metricsStats[ 10 ];

  bool hasQuery;

  none_t results[MAX_CACHE_SIZE];
  uint16_t noneIndex;
  uint16_t noneFwdIndex;

  uint16_t transmissions;

  //init all the variables
  void init()
  {
    int i, j;

    transmissions = 0;

    subTreeDepth = 0;
    depth = 0;

    sendBusy = FALSE;
    hasQuery = FALSE;
    parent = 0;

    timerStep = 1;
    duration = 0;
    waitingPeriod = 0;
    children = 0;
    lifeTime = 0;

    noneIndex = 0;
    noneFwdIndex = 0;

    for ( i = 0; i < 50; i++ )
    {
      metrics[i].period = -1;
      metrics[i].sensorValue = 0;

      metricsStats[i].period = -1;
      metricsStats[i].maxValue = 0;
      metricsStats[i].avgValue = 0;
      metricsStats[i].minValue = 0;
      metricsStats[i].numOfResults = 0;

    }

    for ( i = 0; i < MAX_CACHE_SIZE; i++ )
    {
      results[i].sensorID = 0;
      results[i].sensorValue = 0;
      results[i].iterPeriod = 0;
    }

    for ( i = 0; i < MAX_CACHE_SIZE; i++ )
    {
      resultsP[i].sensorID = 0;
      resultsP[i].period = 0;
      resultsP[i].depth = 0;
      for ( j = 0; j < PAYLOAD_LENGTH; j++ )
      {
        resultsP[i].sensorValue[j] = 0;
      }
    }



    queryCache.lifeTime = 0;
    queryCache.originatorID = 0;
    queryCache.sensorT = 0;       
    queryCache.samplingPeriod = 0;
    queryCache.aggregationMode = 0;  // type 1: none, type 2: piggyback, type 3: stats
    queryCache.currentPeriod = 0; // indicates the current period
    queryCache.depth = 0;

  }

 

  
  event void SerialSend.sendDone( message_t *msg, error_t error ) 
  {

  }


  void printPiggyback( piggyback_t *msg )
  {

    int i; 
    char str[128]; 
    int idx = 0; 
    int cnt = 0; 
    for ( i = 0; i < PAYLOAD_LENGTH; i++ ) 
    { 
      if ( msg->sensorValue[i] != 0 ) 
      { 
        idx += sprintf( &str[ idx ], "%d ", msg->sensorValue[i] ); 
        cnt++; 
      } 
    } 
    sprintf( &str[ idx ], "%c", '\0' ); 
    dbg( "Originator", "[Originator]: Sample period: %d | %s\n[Originator]: Received %d values -> %s\n", msg->period, sim_time_string(), cnt, str );
    dbg("Coverage","iter %d:Coverage %d\n", msg->period, cnt);


    #ifdef DEBUG_INFO
    #endif
  }

  event void Boot.booted()
  {
    init();

    call RadioAMControl.start();
    call SerialAMControl.start();

    dbg( "Debug", "[%d/Boot]: Node %d booted | %s\n", TOS_NODE_ID, TOS_NODE_ID, sim_time_string() );
  }

  event void RadioAMControl.startDone( error_t error )
  {
    if ( error == SUCCESS )
    {
      // for simulation purposes only
      #ifdef SIMULATION
      if ( TOS_NODE_ID == 1 )
      {
        call QueryTimer.startOneShot( 10 );
        hasQuery = TRUE;
      }
      #endif

      if ( hasQuery == FALSE )
      {
        call JoinTimer.startPeriodic( 5000 );
      }
    }
    else
    {
      call RadioAMControl.start();
    }
  }

  event void SerialAMControl.startDone( error_t error ) {}

  event void RadioAMControl.stopDone( error_t error ) {}

  event void SerialAMControl.stopDone( error_t error ) {}

  event void QueryTimer.fired()   /* For simulation purpose only - originator sends the query */
  {
    query_t *query;

    if ( sendBusy == TRUE )
    {
      call QueryTimer.startOneShot(1);
      return;
    }
    
    query = ( query_t * ) call RadioPacket.getPayload( &packet, sizeof( query_t ) );

    if ( query == NULL )
    {
      return;
    }

    query->originatorID = TOS_NODE_ID;
    query->sensorT = BRIGHTNESS;
    query->samplingPeriod = 10;
    query->lifeTime = 60;
    query->depth = 0;
    query->aggregationMode = STATS;

    queryCache.originatorID = query->originatorID;
    queryCache.sensorT = query->sensorT;
    queryCache.samplingPeriod = query->samplingPeriod;
    queryCache.lifeTime = query->lifeTime;
    queryCache.aggregationMode = query->aggregationMode;
    queryCache.currentPeriod = query->currentPeriod;
    queryCache.depth = query->depth;

    call Read.read();

    call SensorTimer.startPeriodic( query->samplingPeriod * 1000 );

    if ( call RadioSend.send( AM_BROADCAST_ADDR, &packet, sizeof( query_t ) ) == SUCCESS )
    {
      dbg( "Query", "[Originator-Send] Query sent | %s\n", sim_time_string() );
      sendBusy = TRUE;
    }

  }

  event void Broadcast.fired()
  {

  }

  event message_t *SerialReceive.receive( message_t *msg, void *payload, uint8_t len )
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
      
      recvMsg->originatorID = TOS_NODE_ID;
      queryCache = *recvMsg;

      call Leds.led2On();

      parent = 0;
      
      call ForwardQueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI*1000 );

      return msg;
    }
  }

  event void JoinTimer.fired()
  {
    if ( sendBusy == TRUE )
    {
      return;
    }
    else
    {
      join_t *join = ( join_t * ) call RadioPacket.getPayload( &packet, sizeof( join_t ) );

      if ( join == NULL )
      {
        return;
      }

      join->sensorID = TOS_NODE_ID;

      if ( call RadioSend.send( AM_BROADCAST_ADDR, &packet, sizeof( join_t ) ) == SUCCESS )
      {
        sendBusy = TRUE;
      }

      dbg( "Join", "Join sent by %d\n", TOS_NODE_ID );

    }
  }

  event void ForwardQueryTimer.fired()
  {
    if ( sendBusy == TRUE )
    {
      call ForwardQueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );
      return;
    }
    else
    {
      query_t* broadcastQuery = ( query_t * ) call RadioPacket.getPayload( &packet, sizeof( query_t ) );

      if ( broadcastQuery == NULL )
      {
        return;
      }

      *broadcastQuery = queryCache;
      broadcastQuery->samplingPeriod = queryCache.samplingPeriod;

      if ( call RadioSend.send( AM_BROADCAST_ADDR, &packet, sizeof( query_t ) ) == SUCCESS )
      {
        dbg( "Query", "[%d/QueryForward] Type: %d, samplingPeriod: %d, lifeTime: %d | %s\n", TOS_NODE_ID, broadcastQuery->sensorT, broadcastQuery->samplingPeriod, broadcastQuery->lifeTime, sim_time_string() );
        sendBusy = TRUE;
      }

    }
  }

  event void SensorTimer.fired()
  {
    
    call Read.read(); //metrhsh

    queryCache.lifeTime -= queryCache.samplingPeriod;
    queryCache.currentPeriod += 1;

    dbg( "Lifetime", "[%d/lifeTime]  %d | %s\n", queryCache.lifeTime, sim_time_string() );

    if( queryCache.lifeTime < queryCache.samplingPeriod )
    {
      call Leds.led2Off();
      dbg( "Lifetime", "[%d/Piggyback]: Lifetime expired | %s\n", TOS_NODE_ID, sim_time_string() );
      dbg( "Piggyback","[%d/Piggyback]: Finished taking metrics. Stopping sensor... | %s\n", TOS_NODE_ID, sim_time_string() );
      if( queryCache.aggregationMode == NONE )
      {
        call Leds.led2Off();
      }
      call SensorTimer.stop();
    }
    
  }

  event void Read.readDone( error_t result, uint16_t data ) 
  {
    if ( result == SUCCESS ) 
    {
      if( queryCache.aggregationMode == NONE )
      {
        none_t *resultMsg = ( none_t * ) call RadioPacket.getPayload( &packet, sizeof( none_t ) );;
        
        
        results[ noneIndex ].sensorID = queryCache.originatorID;
        results[ noneIndex ].iterPeriod = queryCache.currentPeriod;
        results[ noneIndex ].sensorValue = TOS_NODE_ID;

        noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;


        if( queryCache.originatorID == TOS_NODE_ID )
        { 
          dbg("None", "EIMAI O ORIGINATOR result for iteration %d is %d\n", resultMsg->iterPeriod, resultMsg->sensorValue);
          dbg("DEBUG",  "eimai o ORIGINATOR  %d kai phra metrhsh\n", queryCache.originatorID);
          dbg("Coverage","iter %d:Coverage 1\n",queryCache.currentPeriod);
          dbg("Delay","iter %d: Delay %s - %d\n",queryCache.currentPeriod, sim_time_string() , queryCache.currentPeriod*queryCache.samplingPeriod*1000);
        }
        else
        {
          call Leds.led2Toggle();
          call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );
          dbg( "Query", "Results Send: Type = %d, Time: %s\n", resultMsg->sensorValue, sim_time_string() );
          dbg("DEBUG",  "eimai o komvos %d kai esteila ta result ston %d gi thn samplingPeriod %d\n", TOS_NODE_ID, parent, resultMsg->iterPeriod );
          // sendBusy = TRUE;
        }

      }
      else if ( queryCache.aggregationMode == PIGGYBACK )
      {
        int i;
        if( queryCache.originatorID == TOS_NODE_ID )
        {
          dbg("Coverage","iter %d:Coverage 1\n",queryCache.currentPeriod);
          dbg("Delay","iter %d: Delay %s - %d\n",queryCache.currentPeriod, sim_time_string() , queryCache.currentPeriod*queryCache.samplingPeriod*1000);
        }
        for ( i = 0; i < 50; i++ )
        {
          if ( metrics[i].period == -1 )
          {
            metrics[i].sensorValue = TOS_NODE_ID; // TODO: Enter sensor data
            metrics[i].period = queryCache.currentPeriod;
            break;
          }

        }

      }
      else if ( queryCache.aggregationMode == STATS )
      {
        int i;
        if( queryCache.originatorID == TOS_NODE_ID )
        {
          dbg("Coverage","iter %d:Coverage 1\n",queryCache.currentPeriod);
          dbg("Delay","iter %d: Delay %s - %d\n",queryCache.currentPeriod, sim_time_string() , queryCache.currentPeriod*queryCache.samplingPeriod*1000);
        }
        for ( i = 0; i < 50; i++ )
        {
          if ( metricsStats[i].period == -1 )
          {
            metricsStats[i].maxValue = TOS_NODE_ID*1000;
            metricsStats[i].avgValue = TOS_NODE_ID*1000;
            metricsStats[i].minValue = TOS_NODE_ID*1000; // TODO: Enter sensor data
            metricsStats[i].numOfResults = 1;
            metricsStats[i].period = queryCache.currentPeriod;
            if(TOS_NODE_ID == 2){
              dbg("Cache","!!!apothhkeusa thn timh mou node 2 %d @ %s\n", metricsStats[i].period, sim_time_string() );
            }
            break;
          }

        }
      }

    }
 
  }

  event void PiggybackTimer.fired()
  {
    int len = 0;
    int i;


    resultsP[noneIndex].period = waitingPeriod;
    resultsP[noneIndex].depth = subTreeDepth;
    resultsP[noneIndex].sensorID = queryCache.originatorID; // sensorID points to the ID of the originator
    
    

    for ( i = 0; i < 50; i++ )
    {
      if ( metrics[i].period == waitingPeriod )
      {
        resultsP[noneIndex].period = waitingPeriod;
        resultsP[noneIndex].depth = subTreeDepth;
        resultsP[noneIndex].sensorID = queryCache.originatorID;
        resultsP[noneIndex].sensorValue[len] = metrics[i].sensorValue;
        metrics[i].period = -1; // mark this place as free for writing
        len++;

      }

      if ( len == PAYLOAD_LENGTH ) // if piggyback msg has been filled
      {
        
        noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;
        call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI);
        len = 0;
      }
    }

    if ( len > 0 )
    {
      noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;
      call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI);
    }
    
    waitingPeriod++;
    
    if ( ( lifeTime / queryCache.samplingPeriod ) + 1 < waitingPeriod )
    {
      dbg( "transmissions","transmissions %d \n", transmissions );
      
      return;
    }

    dbg( "Piggyback", "[%d/Piggyback]: Piggyback sent @ %d | %s\n", TOS_NODE_ID, waitingPeriod, sim_time_string() );
    
    duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * queryCache.samplingPeriod + timerStep + rand() % 999;
    call PiggybackTimer.startOneShot( duration );

  }

  event void ResultTimer.fired()
  {

    if ( sendBusy == TRUE )
    {
      call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI *10);
      return;
    }
    else
    {
      if( queryCache.aggregationMode == NONE )
      {
        none_t* sendResult = ( none_t * ) call RadioPacket.getPayload( &packet, sizeof( none_t ) );

        if ( sendResult == NULL )
        {
          return;
        }
        
        //*sendResult = results[ noneFwdIndex ];
        sendResult->iterPeriod =  results[ noneFwdIndex ].iterPeriod;
        sendResult->sensorValue =  results[ noneFwdIndex ].sensorValue;
        sendResult->sensorID =  results[ noneFwdIndex ].sensorID;
        if(results[ noneFwdIndex ].iterPeriod!=-1){
          if ( call RadioSend.send( parent, &packet, sizeof( none_t ) ) == SUCCESS )
          {
            transmissions++;
            dbg( "transmissions","transmissions %d \n", transmissions );
      
            call Leds.led1Toggle();
            dbg("Query", "Query Forward %d %d, time: %s\n", sendResult->sensorID, sendResult->iterPeriod, sim_time_string());
            dbg("DEBUG","ResultTimer: eimai o komvos %d kai stelnw to munhma tou komvou %d gia thn samplingPeriod %d\n",TOS_NODE_ID,sendResult->sensorValue,sendResult->iterPeriod);
            sendBusy = TRUE;
            results[ noneFwdIndex ].iterPeriod = -1;
            noneFwdIndex = ( noneFwdIndex + 1 ) % MAX_CACHE_SIZE;
          }
        }
      }
      else
      {
        int i;
        piggyback_t* sendResult = ( piggyback_t * ) call RadioPacket.getPayload( &packet, sizeof( piggyback_t ) );

        if ( sendResult == NULL )
        {
          return;
        }
        
        //*sendResult = results[ noneFwdIndex ];
        sendResult->period =  resultsP[ noneFwdIndex ].period;
        sendResult->sensorID =  resultsP[ noneFwdIndex ].sensorID;
        sendResult->depth =  resultsP[ noneFwdIndex ].depth;


        for ( i = 0; i < PAYLOAD_LENGTH; i++ )
        {
          sendResult->sensorValue[i] = resultsP[ noneFwdIndex ].sensorValue[i];
        }
        

        if ( call RadioSend.send( parent, &packet, sizeof( piggyback_t ) ) == SUCCESS )
        {
          transmissions++;
          call Leds.led1Toggle();
          sendBusy = TRUE;
          noneFwdIndex = ( noneFwdIndex + 1 ) % MAX_CACHE_SIZE;
        }
      }

    }

  }

  event void StatsTimer.fired()
  {
    stats_t *stats;
    int i;
    bool check_min = FALSE;

    stats = ( stats_t * ) call RadioPacket.getPayload( &packet, sizeof( stats_t ) );
    
    if ( stats == NULL )
    {
      return;
    }

    stats->maxValue = 0;
    stats->avgValue = 0;
    stats->minValue = 0;
    stats->numOfResults = 0;
    stats->foo = 0;
    stats->period = waitingPeriod;
    stats->depth = subTreeDepth;
    stats->sensorID = queryCache.originatorID; // sensorID points to the ID of the originator

    for ( i = 0; i < 50; i++ )
    {
      if(TOS_NODE_ID == 2){
        dbg("Cache","|CACHE| period: %d value: %d @ %s\n", metricsStats[i].period, metricsStats[i].avgValue, sim_time_string() );
      }
      if ( metricsStats[i].period == waitingPeriod )
      {
        //thetw to min gia thn prwht fora
        if( !check_min )
        {
          stats->minValue = metricsStats[i].minValue;
          check_min = TRUE;
        }
        //Ypologismos max timhs
        if( metricsStats[i].maxValue > stats->maxValue )
        {
          stats->maxValue = metricsStats[i].maxValue;
        }

        //Ypologismos min timhs
        if( metricsStats[i].minValue < stats->minValue )
        {
          stats->minValue = metricsStats[i].minValue;
        }

        //Ypologismos avg timhs
        stats->avgValue = stats->avgValue * (1.0 * stats->numOfResults / ( stats->numOfResults + metricsStats[i].numOfResults )) + metricsStats[i].avgValue * ( 1.0 * metricsStats[i].numOfResults  / ( stats->numOfResults + metricsStats[i].numOfResults ));
        stats->numOfResults += metricsStats[i].numOfResults; 
        metricsStats[i].period = -1;

      }

    }
    
    if ( check_min )
    {
      if ( call RadioSend.send( parent, &packet, sizeof( stats_t ) ) == SUCCESS )
      {
        transmissions++;
        call Leds.led1Toggle();
        sendBusy = TRUE;
      }
    }
    
    waitingPeriod++;
    
    if ( ( lifeTime / queryCache.samplingPeriod ) + 1 < waitingPeriod )
    {
      call Leds.led2Off();
      dbg( "transmissions","transmissions %d \n", transmissions );
      
      call StatsTimer.stop();
      return;
    }
    
    duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * queryCache.samplingPeriod + timerStep + rand() % 999;
    call StatsTimer.startOneShot( duration );

  }

  event void RadioSend.sendDone( message_t *msg, error_t error )
  {
    if ( &packet == msg )
    {
      sendBusy = FALSE;
    }
  }

  event message_t *RadioReceive.receive( message_t *msg, void *payload, uint8_t len )
  {
    int i, count = 0;
    int fixedDuration = 0;
    am_addr_t child;
    

    if ( len == sizeof( none_t ) )
    {
      none_t *recvResult;
      recvResult = ( none_t * ) payload; 
      

      if( recvResult->sensorID == TOS_NODE_ID )
      {
        dbg("None", "Received result  from %d for iteration %d is %d\n", call RadioAMPacket.source(msg), recvResult->iterPeriod, recvResult->sensorValue);
        // dbg("None", "sensorID == TOS_NODE_ID\n" );
        dbg("Coverage","iter %d:Coverage 1\n",recvResult->iterPeriod);
        dbg("Delay","iter %d: Delay %s - %d\n",recvResult->iterPeriod, sim_time_string() , recvResult->iterPeriod*queryCache.samplingPeriod*1000);
        return msg;
      }

      results[ noneIndex ].sensorID = recvResult->sensorID;
      results[ noneIndex ].iterPeriod = recvResult->iterPeriod;
      results[ noneIndex ].sensorValue = recvResult->sensorValue;

      noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;

      call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );
      return msg;
    }
    else if ( len == sizeof( join_t ) )
    {
      query_t *query;

      join_t *joinMsg;

      joinMsg = ( join_t * ) payload;

      dbg("Join", "Node %d has joined the group\n", joinMsg->sensorID );

      if ( hasQuery == FALSE )
      {
        return msg;
      }

      child = call RadioAMPacket.source( msg );

      query = ( query_t * ) call RadioPacket.getPayload( &packet, sizeof( query_t ) );

      query->originatorID = queryCache.originatorID; 
      query->lifeTime = queryCache.lifeTime;
      query->sensorT = queryCache.sensorT;
      query->samplingPeriod = queryCache.samplingPeriod;
      query->aggregationMode = queryCache.aggregationMode;
      query->currentPeriod = queryCache.currentPeriod;
      query->depth = queryCache.depth;

      if ( call RadioSend.send( child, &packet, sizeof( query_t ) ) == SUCCESS )
      {
        sendBusy = TRUE;
      }

      if ( children == 0 && waitingPeriod != 0 )
      {
        subTreeDepth++;
      }
        
      children++;

      return msg;
    }
    else if ( len == sizeof( stats_t ) )
    {
      stats_t *recvResult;
      recvResult = ( stats_t* ) payload;

      if ( subTreeDepth - 1 < recvResult->depth )
      {

        subTreeDepth = recvResult->depth + 1;

      }
      dbg("Stats","I received message from %d\n",call RadioAMPacket.source( msg ));

      if ( recvResult->sensorID == TOS_NODE_ID )
      {        
        dbg("Stats1","[Originator]/%d: min = %d, max = %d, avg = %d, numOfResults = %d \n",recvResult->period,recvResult->minValue,recvResult->maxValue, recvResult->avgValue, recvResult->numOfResults);
        dbg("Coverage","iter %d:Coverage %d\n",recvResult->period, recvResult->numOfResults);
        dbg("Delay","iter %d: Delay %s - %d\n",recvResult->period, sim_time_string() , recvResult->period*queryCache.samplingPeriod*1000);
        return msg;
      }

      if ( recvResult->period < waitingPeriod )
      {
        stats_t *sendResult = ( stats_t * ) call RadioPacket.getPayload( &packet, sizeof( stats_t ) );

        timerStep += 500; // 1000
        duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * queryCache.samplingPeriod + timerStep + rand()%999;

        dbg("Stats1", " at time:%s\n", sim_time_string());
        if ( sendResult == NULL )
        {
          return msg;
        }
        
        recvResult->depth = subTreeDepth;
        sendResult->period = recvResult->period;
        sendResult->sensorID = recvResult->sensorID;
        sendResult->maxValue = recvResult->maxValue;
        sendResult->avgValue = recvResult->avgValue;
        sendResult->minValue = recvResult->minValue;
        sendResult->foo = 0;

        if ( call RadioSend.send( parent, &packet, sizeof( stats_t ) ) == SUCCESS )
        {
          transmissions++;
          call Leds.led0Toggle();
          sendBusy = TRUE;
        }
        
        fixedDuration = call StatsTimer.getNow();
        fixedDuration -= call StatsTimer.gett0();
        call StatsTimer.startOneShot( duration - fixedDuration );

        return msg;
      }

      if ( recvResult->period == 0 )
      {
        children++;
      }


      for ( i = 0; i < 50; i++ )
      {
        if(metricsStats[i].period<0){
          metricsStats[i].maxValue = recvResult->maxValue;
          metricsStats[i].avgValue = recvResult->avgValue;
          metricsStats[i].minValue = recvResult->minValue;
          metricsStats[i].numOfResults = recvResult->numOfResults;
          metricsStats[i].period = recvResult->period;
          if(TOS_NODE_ID == 2){
            dbg("Cache","apothhkeusa sthn cache node 2 %d sth thesh %d @ %s\n", recvResult->period, i , sim_time_string() );
          }
          break;
        }
      }

      return msg;


    }
    else if ( len == sizeof( piggyback_t ) ) // check if type is aggregationType
    {
      piggyback_t *recvResult;
      recvResult = ( piggyback_t * ) payload;

      call Leds.led0Toggle();

      dbg( "Piggyback", "[%d/Piggyback-Recv]: %d | %s\n", TOS_NODE_ID, recvResult->period, sim_time_string() );
      
      if ( subTreeDepth - 1 < recvResult->depth )
      {

        subTreeDepth = recvResult->depth + 1;
        dbg( "Depth","[%d/Depth]: My subdepth is %d, my kids depth is %d | %s\n", TOS_NODE_ID, subTreeDepth, recvResult->depth, sim_time_string() );

      }

      if ( recvResult->sensorID == TOS_NODE_ID )
      {        
        printPiggyback( recvResult );
        dbg("Delay","iter %d: Delay %s - %d\n",recvResult->period, sim_time_string() , recvResult->period*queryCache.samplingPeriod*1000);

        return msg;
      }

      if ( recvResult->period < waitingPeriod )
      {

        timerStep += 500; // 1000
        duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * queryCache.samplingPeriod + timerStep + rand()%999;

        

        resultsP[noneIndex].period = recvResult->period;
        resultsP[noneIndex].depth = subTreeDepth;
        resultsP[noneIndex].sensorID = recvResult->sensorID;
        for( i = 0; i < PAYLOAD_LENGTH; i++ )
        {
          resultsP[noneIndex].sensorValue[i] = recvResult->sensorValue[i];
        }
        
        dbg("None","NONE: iteration %d   from: ", recvResult->period);

        noneIndex = ( noneIndex + 1 ) % MAX_CACHE_SIZE;
        call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI);

        fixedDuration = call PiggybackTimer.getNow();
        fixedDuration -= call PiggybackTimer.gett0();
        call PiggybackTimer.startOneShot( duration - fixedDuration );

        return msg;
      }

      if ( recvResult->period == 0 )
      {
        children++;
      }


      for ( i = 0; i < 50; i++ )
      {
        if(metrics[i].period<0){
          metrics[i].sensorValue = recvResult->sensorValue[count];
          metrics[i].period = recvResult->period;
          count++;
          if( count == PAYLOAD_LENGTH || recvResult->sensorValue[count] == 0)
          {
            break;
          }
        }
      }

      return msg;
    }
    else if ( len == sizeof( query_t ) )
    {
      query_t *recvQuery;
      recvQuery = ( query_t * ) payload; 

      call Leds.led2On();
      dbg( "Query", "[%d/QueryRecv]: Type: %d, samplingPeriod: %d,  lifeTime: %d | %s\n", TOS_NODE_ID, recvQuery->sensorT, recvQuery->samplingPeriod, recvQuery->lifeTime, sim_time_string() );

      if ( hasQuery == FALSE && call JoinTimer.isRunning() )
      {
        dbg("Join", "                   stop timer\n");
        call JoinTimer.stop();
      }

      if ( recvQuery->originatorID == TOS_NODE_ID )
      {
        return msg;
      }

      if ( queryCache.originatorID == recvQuery->originatorID )
      {
        dbg( "Query", "[%d/QueryRecv]: Duplicate query_t packet | %s\n", TOS_NODE_ID, sim_time_string() );
        return msg;

      }

      parent = call RadioAMPacket.source( msg );

      recvQuery->depth++;
      depth = recvQuery->depth;
      lifeTime = recvQuery->lifeTime;
      
      queryCache.originatorID = recvQuery->originatorID;
      queryCache.sensorT = recvQuery->sensorT;
      queryCache.samplingPeriod = recvQuery->samplingPeriod;
      queryCache.lifeTime = recvQuery->lifeTime;
      queryCache.aggregationMode = recvQuery->aggregationMode;
      queryCache.currentPeriod = recvQuery->currentPeriod;
      queryCache.depth = recvQuery->depth;

      hasQuery = TRUE;

      call ForwardQueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );

      if( queryCache.aggregationMode == PIGGYBACK )
      {
        duration = queryCache.samplingPeriod * 1000 + 1000 / depth + rand() % ( 1000 / depth );

        call PiggybackTimer.startOneShot( duration );
      }
      else if( queryCache.aggregationMode == STATS )
      {
        duration = queryCache.samplingPeriod * 1000 + 1000 / depth + rand() % ( 1000 / depth );

        call StatsTimer.startOneShot( duration );

      }

      call Read.read();

      call SensorTimer.startPeriodic( recvQuery->samplingPeriod *1000 );

      return msg;
    }
    else
    {
      dbg( "Query", "[%d/Receive]: Received an unknown packet | %s\n", TOS_NODE_ID, sim_time_string() );
      return msg;
    }
  }

}