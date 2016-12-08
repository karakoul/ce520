#include "SimpleVirtualMachine.h"
#include "InstructionSet.h"

module SimpleVirtualMachineC
{
	uses
	{
		interface Boot;

	    interface Leds;
	    interface Timer<TMilli> as VMTimer;
	    interface Read<uint16_t>;

	    interface SplitControl as SerialAMControl;
	    interface Packet as SerialPacket;
	    interface AMPacket as SerialAMPacket;
	    interface AMSend as SerialSend;
	    interface Receive as SerialReceive;
	}
}

implementation
{
	app_t apps[ MAX_APPS ];
	data_t results[ MAX_APPS ];
	timers_t timers[ MAX_APPS ];

	uint8_t idx = 0;
	bool readBusy = FALSE;
	int8_t appRunning = 0;
	message_t packet;
	bool serialBusy = FALSE;

	void init()
	{
		int i;

		for ( i = 0; i < MAX_APPS; i++ )
		{
			apps[i].id = -1;
			apps[i].status = APP_WAIT;
			apps[i].getResults = FALSE;
			apps[i].hasTimer = FALSE;
			apps[i].timerCnt = 0;
			apps[i].pc = 3;
			memset( apps[i].binary, 0, sizeof( uint8_t ) * MAX_APP_SIZE );
			memset( apps[i].registers, 0, sizeof( int8_t ) * NUM_REGISTER );

			results[i].id = -1;
			results[i].data = 0;

			timers[i].id = -1;
			timers[i].duration = 0;
			timers[i].period = 0;
		}

	}

	void deleteApp( int8_t appID )
	{
		int i;

		for ( i = 0; i < MAX_APPS; i++ )
		{
			if ( apps[i].id == appID )
			{
				apps[i].status = APP_WAIT; // TERMINATE
				memset( apps[i].registers, 0, sizeof( int8_t ) * NUM_REGISTER );
				memset( apps[i].binary, 0, sizeof( uint8_t ) * MAX_APP_SIZE );
				apps[i].pc = 3;
				apps[i].id = -1;
				apps[i].getResults = FALSE;
				apps[i].timerCnt = 0;
				apps[i].hasTimer = FALSE;

				switch ( i )
				{
					case 0:
						call Leds.led0Off();
						break;
					case 1:
						call Leds.led1Off();
						break;
					case 2:
						call Leds.led2Off();
						break;
				}


				break;
			}
		}

		for ( i = 0; i < MAX_APPS; i++ )
		{
			if ( results[i].id == appID )
			{
				results[i].id = -1;
				results[i].data = 0;

				break;
			}
		}

		for ( i = 0; i < MAX_APPS; i++ )
		{
			if ( timers[i].id == appID )
			{
				timers[i].id = -1;
				timers[i].duration = 0;
				timers[i].period = 0;

				break;
			}
		}
		
	}

	/* Searches the app array and returns the index of the appID in the array if the id is found, else returns -1 */
	int8_t getAppIndex( int8_t appID )
	{
		int i;

		for ( i = 0; i < MAX_APPS; i++ )
		{
			if ( apps[i].id == appID )
			{
				return i;
			}
		}

		return -1;
	}

	void sendSerial( app_t app, uint8_t instr )
	{
		debug_t *debug = ( debug_t * ) call SerialPacket.getPayload( &packet, sizeof( debug_t ) );

		if ( debug == NULL )
		{
			return;
		}

		debug->id = app.id;
		debug->instr = instr;
		memcpy( debug->registers, app.registers, sizeof( int8_t ) * NUM_REGISTER );

		if ( call SerialSend.send( AM_BROADCAST_ADDR, &packet, sizeof( debug_t ) ) == SUCCESS ) 
		{
			serialBusy = TRUE;
		}

	}

	task void interpret()
	{
		int i, j;
		uint8_t cmd;
		uint8_t arg1, arg2;
		int16_t pc;
		uint8_t idxP;

		if ( apps[ appRunning ].status == APP_TERMINATE )
		{
			deleteApp( apps[ appRunning ].id );
			appRunning = ( appRunning + 1 ) % MAX_APPS;
			post interpret();
			return;
		}

		if ( apps[ appRunning ].status == APP_WAIT )
		{
			appRunning = ( appRunning + 1 ) % MAX_APPS;
			post interpret();
			return;
		}

		pc = apps[ appRunning ].pc;

		dbg( "VM2", "AppID: %d got the processor\n", apps[ appRunning ].id );

		for ( i = 0; i < 2; i++ )
		{
			if ( serialBusy )
			{
				apps[ appRunning ].pc = pc;
				post interpret();
				return;
			}

			cmd = apps[ appRunning ].binary[ pc ] >> 4;
			
			switch ( cmd )
			{
				case ret_app:
					dbg( "VM", "RET\n" );
					
					for ( j = 0; j < NUM_REGISTER; j++ )
					{
						dbg( "VM", "%d: reg[%d] = %d\n",apps[ appRunning ].id, j+1, apps[ appRunning ].registers[j] );
					}
					
					if ( apps[ appRunning ].hasTimer == TRUE )
					{
						if ( apps[ appRunning ].binary[1] + 4 > pc ) // if pc is in init, then pc++
						{
							if ( apps[ appRunning ].timerCnt != 0 )
							{
								dbg( "VM2", "In return timerCnt != 0\n" );
								pc++;
								apps[ appRunning ].timerCnt--;
								apps[ appRunning ].hasTimer = FALSE;
								break;
							}
							else // Has found tmr in init, but timer has not yet fired
							{
								dbg( "VM2", "In return timerCnt == 0\n" );
								apps[ appRunning ].status = APP_WAIT;
								apps[ appRunning ].pc = pc;
								appRunning = ( appRunning + 1 ) % MAX_APPS;

								post interpret();
								return;
							}
						}
						else // else pc is in tmr handler, then pc = binary[1]+3
						{
							dbg( "VM2", "In timer return\n" );
							if ( apps[ appRunning ].timerCnt != 0 )
							{
								pc = apps[ appRunning ].binary[1] + 3;
								apps[ appRunning ].timerCnt--;
								apps[ appRunning ].hasTimer = FALSE;
								break;
							}
							else
							{
								apps[ appRunning ].status = APP_WAIT;
								apps[ appRunning ].pc = pc;
								appRunning = ( appRunning + 1 ) % MAX_APPS;

								post interpret();
								return;
							}
						}
					
						//apps[ appRunning ].hasTimer = FALSE;

					}

					// if it hasnt encountered any timers
					//apps[ appRunning ].status = TERMINATE;

					deleteApp( apps[ appRunning ].id );


					appRunning = ( appRunning + 1 ) % MAX_APPS;

					post interpret();
					return;
				case set_var:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "SET: R%d = %d\n", arg1, (int8_t) arg2 );

					//register[arg1] = val (val = arg2)
					apps[ appRunning ].registers[arg1 - 1] = (int8_t) arg2;
					pc++;

					break;
				case cpy:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "CPY: R%d = R%d\n", arg1, arg2 );

					//register[arg1] =register[arg2]
					apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg2 - 1];
					pc++;
					break;
				case add:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "ADD: R%d = R%d + R%d\n", arg1, arg1, arg2 );

					//register[arg1] +=register[arg2]
					apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg1 - 1] + apps[ appRunning ].registers[arg2 - 1];
					pc++;
					break;
				case sub:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "SUB: R%d = R%d - R%d\n", arg1, arg1, arg2 );

					//register[arg1] -=register[arg2]
					apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg1 - 1] - apps[ appRunning ].registers[arg2 - 1];
					pc++;
					break;
				case inc:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					dbg( "VM", "INC: R%d = R%d + 1\n", arg1, arg1 );

					//register[arg1] += 1
					apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg1 - 1] + 1;
					pc++;
					break;
				case dec:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					dbg( "VM", "DEC: R%d = R%d - 1\n", arg1, arg1 );

					//register[arg1] -= 1
					apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg1 - 1] - 1;
					pc++;
					break;
				case max:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "MAX: R%d = max( R%d, R%d )\n", arg1, arg1, arg2 );

					if(apps[ appRunning ].registers[arg2 - 1]>apps[ appRunning ].registers[arg1 - 1])
					{
						apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg2 - 1];
					}
					pc++;
					break;
				case min:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "MIN: R%d = min( R%d, R%d )\n", arg1, arg1, arg2 );

					if(apps[ appRunning ].registers[arg2 - 1]<apps[ appRunning ].registers[arg1 - 1])
					{
						apps[ appRunning ].registers[arg1 - 1] = apps[ appRunning ].registers[arg2 - 1];
					}

					pc++;
					break;
				case bgz:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "BGZ\n" );

					if ( apps[ appRunning ].registers[arg1 - 1] > 0 ) 
					{
						pc = pc + (int8_t) arg2; 
					}
					else
					{
						pc++;
					}

					break;
				case bez:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "BEZ\n" );

					if ( apps[ appRunning ].registers[arg1 - 1] == 0 ) 
					{
						pc = pc + (int8_t) arg2; 
					}
					else
					{
						pc++;
					}

					break;
				case bra:
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "BRA\n" );

					pc = pc + (int8_t) arg2; 

					break;
				case led:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;

					if ( arg1 == 0 )
					{
						switch ( appRunning )
						{
							case 0:
								call Leds.led0Off();
								break;
							case 1:
								call Leds.led1Off();
								break;
							case 2:
								call Leds.led2Off();
								break;
						}

						dbg( "VM", "LED: turn OFF\n" );
					}
					else
					{
						switch ( appRunning )
						{
							case 0:
								call Leds.led0On();
								break;
							case 1:
								call Leds.led1On();
								break;
							case 2:
								call Leds.led2On();
								break;
						}

						dbg( "VM", "LED: turn ON\n" );
					}

					pc++;
					break;
				case rdb:
					arg1 = apps[ appRunning ].binary[ pc ] & 0x0F;

					if ( !apps[ appRunning ].getResults )
					{
						dbg( "VM", "RDB %d\n", apps[ appRunning ].id );
						idxP = idx;
						apps[ appRunning ].status = APP_WAIT;

						for ( j = 0; j < MAX_APPS; j++ )
						{
							if ( results[idxP].id == -1 )
							{
								results[idxP].id = apps[ appRunning ].id;
								break;
							}
							else
							{
								idxP = ( idxP + 1 ) % MAX_APPS;
							}
						}


						if ( !readBusy ) // todo
						{
							call Read.read();
							readBusy = TRUE;
						}

						apps[ appRunning ].pc = pc;
						appRunning = ( appRunning + 1 ) % MAX_APPS;
						post interpret();
						return;
					}
					
					for ( j = 0; j < MAX_APPS; j++ )
					{
						if ( results[j].id == apps[ appRunning ].id )
						{
							apps[ appRunning ].registers[ arg1 - 1 ] = (int8_t) ( results[j].data%127 ); // todo
							results[j].id = -1;
							break;
						}
					}

					pc++;
					apps[ appRunning ].getResults = FALSE;
					
					break;
				case tmr:
					arg2 = apps[ appRunning ].binary[ ++pc ];
					dbg( "VM", "TMR: set every %d seconds\n", arg2 );

					if ( apps[ appRunning ].binary[1] + 4 > pc )
					{
						
					}
					//  TODO change
					apps[ appRunning ].hasTimer = TRUE;
					
					if ( arg2 == 0 )
					{
						timers[ appRunning ].id = -1;
					}
					else
					{
						timers[ appRunning ].id = apps[ appRunning ].id;
						timers[ appRunning ].duration = arg2;
						timers[ appRunning ].period = 0;

					}

					pc++;

					break;

				default:
					dbg( "VM", "UNKNOWN\n" );
					//call Leds.led2On();
					return;
					//break;
			}

			sendSerial( apps[ appRunning ], cmd );
		}

		apps[ appRunning ].pc = pc;

		appRunning = ( appRunning + 1 ) % MAX_APPS;

		post interpret();

	}

	event void VMTimer.fired()
  	{
  		int i;
  		int8_t indexP;

  		for ( i = 0; i < MAX_APPS; i++ )
  		{
  			if ( timers[i].id != -1 )
  			{
  				timers[i].period++;

  				if ( timers[i].period >= timers[i].duration )
  				{
  					indexP = getAppIndex( timers[i].id );

  					if ( indexP != -1 )
  					{
  						apps[ indexP ].timerCnt++;
	  					apps[ indexP ].status = APP_READY;

	  					timers[i].id = -1;
	  					timers[i].period = 0;
  					}
  					
  				}
  			}
  		}

  		dbg( "VM", "Timer fired\n");

  	}

	/* Adds an application to the app array */
	void addApp( app_msg_t *app )
	{
		int i;

		for ( i = 0; i < MAX_APPS; i++ )
		{
			if ( apps[i].id == -1 )
			{
				apps[i].status = APP_READY;
  				memcpy( apps[i].binary, app->binary, sizeof( uint8_t ) * MAX_PAYLOAD );
  				memset(apps[i].registers, 0, sizeof(int8_t) * NUM_REGISTER );
  				apps[i].pc = 3;
  				apps[i].id = app->id;
  				apps[i].getResults = FALSE;
  				apps[i].timerCnt = 0;
  				apps[i].hasTimer = FALSE;

  				return;
			}
		}
		
	}

	event void Boot.booted()
	{
		int i;
		//uint8_t binary[] = { 0x09, 0x04, 0x02, 0x11, 0x05, 0x25, 0x01, 0x65, 0x22, 0x05, 0x72, 0x01, 0x43, 0x02, 0x84, 0x03, 0x26, 0x04, 0x56, 0x00 };
		//uint8_t binary1[] = { 0x55, 0x04, 0x02, 0xD1, 0x12, 0x32, 0x42, 0x01, 0x91, 0x04, 0xC0, 0xB0, 0x02, 0xC1, 0x41, 0x05, 0x00 };
		//uint8_t binary[] = { 0x09, 0x04, 0x02, 0xD1, 0xD2, 0xD3, 0xD4, 0x00 };
		uint8_t app2[] = { 0x09, 0x04, 0x02, 0xC1, 0xE0, 0x03, 0x00, 0xC0, 0x00 };
		uint8_t app3[] = { 0x17, 0x06, 0x0E, 0xC1, 0x11, 0x01, 0xE0, 0x03, 0x00, 0xA1, 0x07, 0xC0, 0x11, 0x00, 0xE0, 0x07, 0x00, 0xC1, 0x11, 0x01, 0xE0, 0x03, 0x00 };
		uint8_t myapp[] = { 0x11, 0x05, 0x09, 0x11, 0x0A, 0xE0, 0x01, 0x00, 0x61, 0xA1, 0x05, 0xE0, 0x01, 0x00, 0xE0, 0x00, 0x00 };
		
		init();

		/*memset( apps[0].binary, 0, sizeof( uint8_t ) * 255 );
		memcpy( apps[0].binary, myapp, 18 * sizeof( uint8_t ) );
		memset( apps[0].registers, 0, sizeof( int8_t ) * NUM_REGISTER );
		apps[0].pc = 3;
		apps[0].id = 11;
		apps[0].status = APP_READY;
		apps[0].getResults = FALSE;
		apps[0].timerCnt = 0;
		apps[0].hasTimer = FALSE;

		memset( apps[1].binary, 0, sizeof( uint8_t ) * 255 );
		memcpy( apps[1].binary, app2, 10 * sizeof( uint8_t ) );
		memset( apps[1].registers, 0, sizeof( int8_t ) * NUM_REGISTER );
		apps[1].pc = 3;
		apps[1].id = 12;
		apps[1].status = APP_READY;
		apps[1].getResults = FALSE;
		apps[1].timerCnt = 0;
		apps[1].hasTimer = FALSE;

		memset( apps[2].binary, 0, sizeof( uint8_t ) * 255 );
		memcpy( apps[2].binary, app3, 24 * sizeof( uint8_t ) );
		memset( apps[2].registers, 0, sizeof( int8_t ) * NUM_REGISTER );
		apps[2].pc = 3;
		apps[2].id = 13;
		apps[2].status = APP_READY;
		apps[2].getResults = FALSE;
		apps[2].timerCnt = 0;
		apps[2].hasTimer = FALSE;*/

		call SerialAMControl.start();


	}

	event void SerialAMControl.startDone( error_t error ) 
	{
		if ( error != SUCCESS )
		{
			call SerialAMControl.start(); 
			return;
		}

		call VMTimer.startPeriodic( 1000 );
		post interpret();
	}

  	event void SerialAMControl.stopDone( error_t error ) {}

  	event void SerialSend.sendDone( message_t *msg, error_t error ) 
  	{
  		serialBusy = FALSE;
  	}

  	event message_t *SerialReceive.receive( message_t *msg, void *payload, uint8_t len )
  	{
  		//call Leds.led1On();

  		if ( len == sizeof( app_msg_t ) )
  		{
  			int appIndex, i;
  			app_msg_t* app = ( app_msg_t * ) payload;
  			appIndex = getAppIndex( app->id );
  			//call Leds.led2On();

  			if ( app->seqNum == APP_TERMINATE )
  			{
  				if ( appIndex != -1 )
  				{
  					deleteApp( app->id );
  					return msg;
  				}

  				return msg;
  			}

  			if ( appIndex != -1 )
  			{
				apps[ appIndex ].status = APP_READY;
				memcpy( apps[ appIndex ].binary, app->binary, sizeof( uint8_t )*MAX_PAYLOAD );
				memset(apps[ appIndex ].registers, 0, sizeof(int8_t) * NUM_REGISTER );
				apps[ appIndex ].pc = 3;
  				apps[ appIndex ].getResults = FALSE;
  				apps[ appIndex ].timerCnt = 0;
  				apps[ appIndex ].hasTimer = FALSE;

  				for ( i = 0; i < MAX_APPS; i++ )
  				{
  					if ( results[i].id == app->id )
  					{
  						results[i].data = 0;
  						break;
  					}
  				}

  				for ( i = 0; i < MAX_APPS; i++ )
  				{
  					if ( timers[i].id == app->id )
  					{
  						timers[i].duration = 0;
  						timers[i].period = 0;
  						break;
  					}
  				}
  				
  			}
  			else
  			{
  				addApp( app );
  			}
  			
  			
  		}

  		return msg;
  	}

  	event void Read.readDone( error_t result, uint16_t data ) 
  	{
  		int i;
  		int8_t indexP;

  		readBusy = FALSE;

  		for ( i = 0; i < MAX_APPS; i++ )
  		{
  			if ( results[ idx ].id != -1 )
  			{
  				indexP = getAppIndex( results[ idx ].id );

  				if ( indexP != 1 )
  				{
  					dbg( "VM", "Read done id = %d\n", apps[ indexP ].id );

  					results[ idx ].data = data; // TODO: change to data
	  				apps[ indexP ].getResults = TRUE;
	  				apps[ indexP ].status = APP_READY;
	  				idx = ( idx + 1 ) % MAX_APPS;
	  				break;
  				}

  				idx = ( idx + 1 ) % MAX_APPS; // todo:
  				
  			}
  			else
  			{
  				idx = ( idx + 1 ) % MAX_APPS;
  			}
  		}

  	}
}