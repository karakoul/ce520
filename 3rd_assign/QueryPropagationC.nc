#include "QueryPropagation.h"

module QueryPropagationC
{
  uses 
  {
  	interface Boot;
    interface Leds;
    interface Read<uint16_t>;

    interface Timer<TMilli> as QueryTimer;
    interface Timer<TMilli> as SensorTimer;
    interface Timer<TMilli> as ResultTimer;
    interface Timer<TMilli> as PiggybackTimer;
    interface Timer<TMilli> as StatsTimer;
    interface Timer<TMilli> as JoinTimer;

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
  }
}

implementation
{
	message_t packet;
	bool hasQuery = FALSE;
	bool busy = FALSE;
	am_addr_t parent;
	query_t query;
	none_t resultNone[ 20 ];
	uint8_t noneIndex = 0;
	uint8_t noneFwdIndex = 0;
	uint8_t BROADCAST_PERIOD_MILLI = 2;
	uint8_t depth = 0;
	piggyback_t resultPiggy[ 20 ];
	cacheP_t metricsP[ 10 ];
	uint8_t subTreeDepth = 0;
	uint16_t timerStep = 1;
	uint16_t duration = 0;
	uint16_t waitingPeriod = 0;
	uint16_t children = 0;
	uint16_t lifeTime = 0;
	cacheS_t metricsS[ 10 ];

	event void Boot.booted()
	{
		int i;
		for ( i = 0; i < 10; i++ )
		{
			metricsP[i].sensorValue = 0;
			metricsP[i].period = -1;
			metricsS[i].minValue = 0;
			metricsS[i].maxValue = 0;
			metricsS[i].avgValue = 0;
			metricsS[i].numOfResults = 0;
			metricsS[i].period = -1;
		}
		call RadioAMControl.start();
		call SerialAMControl.start();
	}

	event void RadioAMControl.startDone( error_t error ) 
	{
		if ( error == SUCCESS )
	    {
	      if ( hasQuery == FALSE )
	      {
	        call JoinTimer.startPeriodic( 1000 );
	      }
	    }
	}

	event void SerialAMControl.startDone( error_t error ) {}

	event void RadioAMControl.stopDone( error_t error ) {}

	event void SerialAMControl.stopDone( error_t error ) {}



	event message_t *SerialReceive.receive( message_t *msg, void *payload, uint8_t len )
	{
		if ( len == sizeof( query_t ) )
		{
			query_t *serialQuery = ( query_t * ) payload;

			
			call JoinTimer.stop();
			

			query.originatorID = TOS_NODE_ID;
			query.sensorT = serialQuery->sensorT; 
			query.samplingPeriod = serialQuery->samplingPeriod;
			query.lifeTime = serialQuery->lifeTime;
			query.aggregationMode = serialQuery->aggregationMode;
			query.currentPeriod = serialQuery->currentPeriod;
			query.depth = 0;

			lifeTime = query.lifeTime;

			hasQuery = TRUE;
			parent = 0;

			call Read.read();
			call QueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI * 1000 );
			
			duration = query.samplingPeriod * 1000 + 1000 / (depth + 1) + rand() % ( 1000 / (depth + 1) );
			if( query.aggregationMode == PIGGYBACK )
			{
				call PiggybackTimer.startOneShot( duration );
			}
			else if( query.aggregationMode == STATS )
			{
				call StatsTimer.startOneShot( duration );
			}

      		call SensorTimer.startPeriodic( serialQuery->samplingPeriod * 1000 );
    	}

		return msg;
	}

	event message_t *RadioReceive.receive( message_t *msg, void *payload, uint8_t len )
	{
		if ( len == sizeof( query_t ) )
		{
			query_t *recvQuery = ( query_t * ) payload;

			if ( recvQuery->originatorID == TOS_NODE_ID )
			{
				return msg;
			}

			if ( hasQuery == TRUE )
      		{
        		return msg;
      		}

      		if (call JoinTimer.isRunning() )
			{
				call JoinTimer.stop();
			}

			call Leds.led0Toggle();
			parent = call RadioAMPacket.source( msg );
			
			query.originatorID = recvQuery->originatorID;
			query.sensorT = recvQuery->sensorT;
			query.samplingPeriod = recvQuery->samplingPeriod;
			query.lifeTime = recvQuery->lifeTime;

			query.aggregationMode = recvQuery->aggregationMode;
			query.currentPeriod = recvQuery->currentPeriod;

			depth = recvQuery->depth + 1;
			query.depth = depth;
			lifeTime = recvQuery->lifeTime;

			hasQuery = TRUE;

			call Read.read();

			call QueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );

			duration = query.samplingPeriod * 1000 + 1000 / (depth+1) + rand() % ( 1000 / (depth+1) );
			if( query.aggregationMode == PIGGYBACK )
			{
				call PiggybackTimer.startOneShot( duration );
			}
			else if( query.aggregationMode == STATS )
			{
				call StatsTimer.startOneShot( duration );
			}

      		call SensorTimer.startPeriodic( query.samplingPeriod * 1000 );
		}
		else if ( len == sizeof( none_t ) )
		{
			none_t *recvNone = ( none_t * ) payload;

			if ( recvNone->sensorID == TOS_NODE_ID )
			{
				none_t* response = ( none_t * ) call SerialPacket.getPayload( &packet, sizeof( none_t ) );

				if ( response == NULL )
				{
					return msg;
				}

				response->sensorID = recvNone->sensorID;
				response->sensorValue = recvNone->sensorValue;
				response->iterPeriod = recvNone->iterPeriod;

				if ( call SerialSend.send( AM_BROADCAST_ADDR, &packet, sizeof( none_t ) ) == SUCCESS )
				{
				}
			}
			else
			{
				resultNone[ noneIndex ].sensorID = recvNone->sensorID;
				resultNone[ noneIndex ].iterPeriod = recvNone->iterPeriod;
				resultNone[ noneIndex ].sensorValue = recvNone->sensorValue;

				noneIndex = ( noneIndex + 1 ) % 20;

				call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI *10);
			}
		}
		else if ( len == sizeof( piggyback_t ) ) // check if type is aggregationType
		{
			int i, count = 0;
			int fixedDuration = 0;
			piggyback_t *recvResult;
			recvResult = ( piggyback_t * ) payload;

			if ( subTreeDepth - 1 < recvResult->depth )
			{
				subTreeDepth = recvResult->depth + 1;
			}

			
			if ( recvResult->period == 0 )
			{
				children++;
			}
			if ( recvResult->period < waitingPeriod )
			{

				timerStep += 1000; // 1000
				duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * query.samplingPeriod + timerStep + rand()%999;

				resultPiggy[noneIndex].period = recvResult->period;
				resultPiggy[noneIndex].depth = subTreeDepth;
				resultPiggy[noneIndex].sensorID = recvResult->sensorID;

				for( i = 0; i < 10; i++ )
				{
					resultPiggy[noneIndex].sensorValue[i] = recvResult->sensorValue[i];
				}

				noneIndex = ( noneIndex + 1 ) % 20;
				call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI);

				fixedDuration = call PiggybackTimer.getNow();
				fixedDuration -= call PiggybackTimer.gett0();
				call PiggybackTimer.startOneShot( duration - fixedDuration );

			}
			else
			{
				for ( i = 0; i < 10; i++ )
				{
					if(metricsP[i].period<0){
						metricsP[i].sensorValue = recvResult->sensorValue[count];
						metricsP[i].period = recvResult->period;
						count++;

						call Leds.led1Toggle();
					}
				}
			}

			
		}
		else if ( len == sizeof( stats_t ) ) // check if type is aggregationType
		{
			stats_t *recvResult;
			int i, fixedDuration = 0;
      		recvResult = ( stats_t* ) payload;

      		if ( subTreeDepth - 1 < recvResult->depth )
			{
				subTreeDepth = recvResult->depth + 1;
			}

			if ( recvResult->period == 0 )
			{
				children++;
			}

			
			if ( recvResult->period < waitingPeriod)
			{
				stats_t *sendResult;
				
				if(query.originatorID != TOS_NODE_ID)
				{
					sendResult = ( stats_t * ) call RadioPacket.getPayload( &packet, sizeof( stats_t ) );
				}
				else
				{
					sendResult = ( stats_t * ) call SerialPacket.getPayload( &packet, sizeof( stats_t ) );
				}

				if ( sendResult == NULL )
				{
					return msg;
				}

				timerStep += 1000; // 1000
				duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * query.samplingPeriod + timerStep + rand()%999;


				sendResult->depth = subTreeDepth;
				sendResult->period = recvResult->period;
				sendResult->sensorID = recvResult->sensorID;
				sendResult->maxValue = recvResult->maxValue;
				sendResult->avgValue = recvResult->avgValue;
				sendResult->minValue = recvResult->minValue;
				sendResult->numOfResults = recvResult->numOfResults;
				sendResult->foo = 0;

				if(query.originatorID != TOS_NODE_ID)
				{
					if ( call RadioSend.send( parent, &packet, sizeof( stats_t ) ) == SUCCESS )
					{
						busy = TRUE;
					}
				}
				else
				{
					if ( call SerialSend.send( AM_BROADCAST_ADDR, &packet, sizeof( stats_t ) ) == SUCCESS )
					{
						busy = TRUE;
					}
				}

				fixedDuration = call StatsTimer.getNow();
				fixedDuration -= call StatsTimer.gett0();
				call StatsTimer.startOneShot( duration - fixedDuration );
			}
			else
			{
				for ( i = 0; i < 10; i++ )
				{
					if(metricsS[i].period<0){
						metricsS[i].maxValue = recvResult->maxValue;
						metricsS[i].avgValue = recvResult->avgValue;
						metricsS[i].minValue = recvResult->minValue;
						metricsS[i].numOfResults = recvResult->numOfResults;
						metricsS[i].period = recvResult->period;
						break;
					}
				}
			}
			
		}
		else if ( len == sizeof( join_t ) )
	    {
	      query_t *queryJ;

	      join_t *joinMsg;

	      am_addr_t child;

	      joinMsg = ( join_t * ) payload;

	      if ( hasQuery == FALSE )
	      {
	        return msg;
	      }

	      child = call RadioAMPacket.source( msg );

	      queryJ = ( query_t * ) call RadioPacket.getPayload( &packet, sizeof( query_t ) );

	      queryJ->originatorID = query.originatorID; 
	      queryJ->lifeTime = query.lifeTime;
	      queryJ->sensorT = query.sensorT;
	      queryJ->samplingPeriod = query.samplingPeriod;
	      queryJ->aggregationMode = query.aggregationMode;
	      queryJ->currentPeriod = query.currentPeriod;
	      queryJ->depth = query.depth;

	      if ( call RadioSend.send( child, &packet, sizeof( query_t ) ) == SUCCESS )
	      {
	        busy = TRUE;
	      }

	      if ( children == 0 && waitingPeriod != 0 )
	      {
	        subTreeDepth++;
	      }
	        
	      children++;

	    }

		return msg;
	}

	event void QueryTimer.fired()
	{
		query_t *bcastQuery;

		if ( busy )
		{
			call QueryTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI );
			return;
		}

		bcastQuery = ( query_t * ) call RadioPacket.getPayload( &packet, sizeof( query_t ) );

		if ( bcastQuery == NULL )
		{
			return;
		}

		bcastQuery->originatorID = query.originatorID;
		bcastQuery->sensorT = query.sensorT;
		bcastQuery->samplingPeriod = query.samplingPeriod;
		bcastQuery->lifeTime = query.lifeTime;
		bcastQuery->aggregationMode = query.aggregationMode;
		bcastQuery->currentPeriod = query.currentPeriod;
		bcastQuery->depth = query.depth;

		if ( call RadioSend.send( AM_BROADCAST_ADDR, &packet, sizeof( query_t ) ) == SUCCESS )
		{
			busy = TRUE;
		}	

	}

	event void SensorTimer.fired()
	{
		call Read.read();

		query.lifeTime -= query.samplingPeriod;
	    query.currentPeriod += 1;

	    if( query.lifeTime < query.samplingPeriod )
	    {
	      call SensorTimer.stop();
	    }
	}

	event void Read.readDone( error_t result, uint16_t data )
	{
		if ( result != SUCCESS )
		{
			return;
		}

		if ( query.aggregationMode == NONE )
		{
			resultNone[ noneIndex ].sensorID = query.originatorID;
			resultNone[ noneIndex ].iterPeriod = query.currentPeriod;
			resultNone[ noneIndex ].sensorValue = data;

			noneIndex = ( noneIndex + 1 ) % 20;

			call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI *10);
		}
		else if ( query.aggregationMode == PIGGYBACK )
		{
			int i;
			for ( i = 0; i < 10; i++ )
			{
				if ( metricsP[i].period == -1 )
				{
					metricsP[i].sensorValue = data;
					metricsP[i].period = query.currentPeriod;
					break;
				}

			}
		}
		else if ( query.aggregationMode == STATS )
		{
			int i;
			
			for ( i = 0; i < 10; i++ )
			{
				if ( metricsS[i].period == -1 )
				{
					metricsS[i].maxValue = data;
					metricsS[i].avgValue = data;
					metricsS[i].minValue = data;
					metricsS[i].numOfResults = 1;
					metricsS[i].period = query.currentPeriod;
					
					break;
				}

			}
      }
	}

	event void ResultTimer.fired()
	{
		if ( busy )
		{
			call ResultTimer.startOneShot( TOS_NODE_ID * BROADCAST_PERIOD_MILLI * 10 );
			return;
		}

		if ( query.aggregationMode == NONE )
		{
			none_t *sendResult;

			if ( query.originatorID == TOS_NODE_ID )
			{
				sendResult = ( none_t * ) call SerialPacket.getPayload( &packet, sizeof( none_t ) );

				if ( sendResult == NULL )
				{
					return;
				}

				sendResult->sensorID = resultNone[ noneFwdIndex ].sensorID;
				sendResult->sensorValue = resultNone[ noneFwdIndex ].sensorValue;
				sendResult->iterPeriod = resultNone[ noneFwdIndex ].iterPeriod;

				if ( call SerialSend.send( AM_BROADCAST_ADDR, &packet, sizeof( none_t ) ) == SUCCESS ) 
				{
					noneFwdIndex = ( noneFwdIndex + 1 ) % 20;
				}

				return;
			}

			sendResult = ( none_t * ) call RadioPacket.getPayload( &packet, sizeof( none_t ) );

			if ( sendResult == NULL )
			{
				return;
			}

			sendResult->sensorID = resultNone[ noneFwdIndex ].sensorID;
			sendResult->sensorValue = resultNone[ noneFwdIndex ].sensorValue;
			sendResult->iterPeriod = resultNone[ noneFwdIndex ].iterPeriod;

			if ( call RadioSend.send( parent, &packet, sizeof( none_t ) ) == SUCCESS )
			{
				busy = TRUE;
				noneFwdIndex = ( noneFwdIndex + 1 ) % 20;
			}
		}
		else if ( query.aggregationMode == PIGGYBACK )
		{
			int i;
			if(query.originatorID == TOS_NODE_ID)
			{
				piggyback_t* sendResult = ( piggyback_t * ) call SerialPacket.getPayload( &packet, sizeof( piggyback_t ) );

				if ( sendResult == NULL )
				{
					return;
				}

				sendResult->sensorID = resultPiggy[ noneFwdIndex ].sensorID;
				sendResult->depth = resultPiggy[ noneFwdIndex ].depth;
				sendResult->period = resultPiggy[ noneFwdIndex ].period;

				for ( i = 0; i < 10; i++ )
		        {
		          sendResult->sensorValue[i] = resultPiggy[ noneFwdIndex ].sensorValue[i];
		        }


				if ( call SerialSend.send( AM_BROADCAST_ADDR, &packet, sizeof( piggyback_t ) ) == SUCCESS ) 
				{
					noneFwdIndex = ( noneFwdIndex + 1 ) % 20;
				}

				return;

			}
			else
			{
		        piggyback_t* sendResult = ( piggyback_t * ) call RadioPacket.getPayload( &packet, sizeof( piggyback_t ) );

		        if ( sendResult == NULL )
		        {
		          return;
		        }
		        
		        //*sendResult = results[ noneFwdIndex ];
		        sendResult->period =  resultPiggy[ noneFwdIndex ].period;
		        sendResult->sensorID =  resultPiggy[ noneFwdIndex ].sensorID;
		        sendResult->depth =  resultPiggy[ noneFwdIndex ].depth;

		        for ( i = 0; i < 10; i++ )
		        {
		          sendResult->sensorValue[i] = resultPiggy[ noneFwdIndex ].sensorValue[i];
		        }
		        

		        if ( call RadioSend.send( parent, &packet, sizeof( piggyback_t ) ) == SUCCESS )
		        {
		          busy = TRUE;
		          noneFwdIndex = ( noneFwdIndex + 1 ) % 20;
		        }
		    }
		}
	}

	event void PiggybackTimer.fired()
	{
		int len = 0;
		int i;

		for ( i = 0; i < 10; i++ )
		{
			resultPiggy[noneIndex].sensorValue[i] = 0;
		}

		for ( i = 0; i < 10; i++ )
		{
			if ( metricsP[i].period == waitingPeriod )
			{
				resultPiggy[noneIndex].period = waitingPeriod;
				resultPiggy[noneIndex].depth = subTreeDepth;
				resultPiggy[noneIndex].sensorID = query.originatorID;
				resultPiggy[noneIndex].sensorValue[len] = metricsP[i].sensorValue;
				metricsP[i].period = -1; // mark this place as free for writing
				len++;
				call Leds.led0Toggle();

			}

			if ( len == 10 ) // if piggyback msg has been filled
			{
				noneIndex = ( noneIndex + 1 ) % 20;
				call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI*10);
				len = 0;
			}
		}

		if ( len > 0)
		{
			noneIndex = ( noneIndex + 1 ) % 20;
			call ResultTimer.startOneShot(TOS_NODE_ID*BROADCAST_PERIOD_MILLI*10);
		}

		waitingPeriod++;

		if ( ( lifeTime / query.samplingPeriod ) + 1 < waitingPeriod )
		{
			if(lifeTime == 9){

			}
			return;
		}

		duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * query.samplingPeriod + timerStep + rand() % 999;
		call PiggybackTimer.startOneShot( duration );
	}

	event void StatsTimer.fired()
	{
		stats_t *stats;
		int i;
		bool check_min = FALSE;

		if(query.originatorID == TOS_NODE_ID)
		{
			stats = ( stats_t * ) call SerialPacket.getPayload( &packet, sizeof( stats_t ) );
		}
		else
		{
			stats = ( stats_t * ) call RadioPacket.getPayload( &packet, sizeof( stats_t ) );
		}

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
		stats->sensorID = query.originatorID; // sensorID points to the ID of the originator

		for ( i = 0; i < 10; i++ )
		{
			if ( metricsS[i].period == waitingPeriod )
			{
			//thetw to min gia thn prwht fora
				if( !check_min )
				{
					stats->minValue = metricsS[i].minValue;
					check_min = TRUE;
				}
				//Ypologismos max timhs
				if( metricsS[i].maxValue > stats->maxValue )
				{
					stats->maxValue = metricsS[i].maxValue;
				}

				//Ypologismos min timhs
				if( metricsS[i].minValue < stats->minValue )
				{
					stats->minValue = metricsS[i].minValue;
				}

				//Ypologismos avg timhs
				stats->avgValue = stats->avgValue * (1.0 * stats->numOfResults / ( stats->numOfResults + metricsS[i].numOfResults )) + metricsS[i].avgValue * ( 1.0 * metricsS[i].numOfResults  / ( stats->numOfResults + metricsS[i].numOfResults ));
				stats->numOfResults += metricsS[i].numOfResults; 
				metricsS[i].period = -1;

			}

		}

		if ( check_min )
		{

			if(query.originatorID == TOS_NODE_ID)
			{
				if ( call SerialSend.send( parent, &packet, sizeof( stats_t ) ) == SUCCESS )
				{
				}
			}
			else
			{
				if ( call RadioSend.send( parent, &packet, sizeof( stats_t ) ) == SUCCESS )
				{
					busy = TRUE;
				}
			}
			
		}

		waitingPeriod++;

		if ( ( lifeTime / query.samplingPeriod ) + 1 < waitingPeriod )
		{
			call StatsTimer.stop();
			return;
		}

		duration = ( 600 * ( subTreeDepth + 1 ) + 400 * ( children + 1 ) ) * query.samplingPeriod + timerStep + rand() % 999;
		call StatsTimer.startOneShot( duration );
	}

	event void JoinTimer.fired()
  	{
  		if ( busy == TRUE )
	    {
	      return;
	    }
	    else
	    {
	      join_t *join = ( join_t * ) call RadioPacket.getPayload( &packet, sizeof( join_t ) );

	      call Leds.led1Toggle();

	      if ( join == NULL )
	      {
	        return;
	      }

	      join->sensorID = TOS_NODE_ID;

	      if ( call RadioSend.send( AM_BROADCAST_ADDR, &packet, sizeof( join_t ) ) == SUCCESS )
	      {
	        busy = TRUE;
	      }

	    }
  	}

	event void RadioSend.sendDone( message_t *msg, error_t error )
	{
		if ( &packet == msg )
		{
			busy = FALSE;
		}
	}

	event void SerialSend.sendDone( message_t *msg, error_t error ) {}
}