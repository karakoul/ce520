#include "Timer.h"
#include "BrightnessSensor.h"

#define B 40

module BrightnessSensorC 
{
	uses interface Timer<TMilli> as Timer;
	uses interface Leds;
	uses interface Boot;
	uses interface Read<uint16_t>;
	
	uses interface SplitControl as Control;
	uses interface AMSend;
	uses interface Packet;
	uses interface AMPacket;
	uses interface Receive;
}

implementation 
{
	uint16_t brightness;
	bool ledIsOn = FALSE;
	message_t packet;
	bool busy = FALSE;
	uint16_t T = 1000;
	
	task void CheckBrightness() 
	{	
		if ( brightness < B ) 
		{
			if ( !ledIsOn )
			{
				call Leds.led2On();
				ledIsOn = TRUE;
			}
 		}
		else 
		{
			if ( ledIsOn ) 
			{
				call Leds.led2Off();
				ledIsOn = FALSE;
			}
		}
	}
	
	event void Boot.booted() 
	{
		call Control.start();	
	}
	
	task void SendMessage() 
	{
		if( !busy )
		{
			brightness_t *brightness_msg; 
			brightness_msg = ( brightness_t* ) ( call Packet.getPayload( &packet, sizeof( brightness_t ) ) );
			
			if ( brightness_msg == NULL )
			{
				return;
			}
			
			brightness_msg->brightness = brightness;
			
			if ( call AMSend.send( AM_BROADCAST_ADDR, &packet, sizeof( brightness_t ) ) == SUCCESS )
			{
				busy = TRUE;
			}
		}
	}
	
	
/*********************************************************************/
	event void Control.startDone( error_t error )
	{
		if ( error != SUCCESS )
		{
			call Control.start();
		}
		else 
		{
			call Timer.startPeriodic( T );
		}
	}
	
	event void Control.stopDone( error_t error ) {}
/*********************************************************************/



	event void Timer.fired() 
	{
// 		dbg("BrightnessSensor", "Check %s \n", sim_time_string());
		call Read.read();
	}
	
	
	event void Read.readDone(error_t result, uint16_t data) 
	{
// 		dbg("Brightness", "Check %d \n", data);
		if(result == SUCCESS) 
		{
			brightness = data;
			post CheckBrightness();
			
			post SendMessage();
		}
		else 
		{
			return;
		}
		
		
	}
	
	event void AMSend.sendDone(message_t* msg, error_t error)
	{
		if(&packet == msg) 
		{
			busy = FALSE;
		}
	}
	
	event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
	{
		if(len == sizeof(period_t)){
			period_t *period;
			period = (period_t*)payload;
			T = period->sampling_period;
			call Timer.startPeriodic( T );
		}
		return msg;
	}
	
}