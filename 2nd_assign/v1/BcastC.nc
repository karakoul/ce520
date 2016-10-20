#include "Bcast.h"
#include "Timer.h"

module BcastC 
{
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as Timer;
	
	uses interface SplitControl as Control;
	uses interface AMSend;
	uses interface Packet;
	uses interface AMPacket;
	uses interface Receive;
}

implementation 
{
	message_t packet;
	bool busy = FALSE;
	uint16_t node_id = 0;
	uint16_t seq_num=0;
	msg_t *rec_msg;
	
	task void forward()
	{
		msg_t *bcast_msg; 
		bcast_msg = ( msg_t* ) ( call Packet.getPayload( &packet, sizeof( msg_t) ) );
		
		if ( bcast_msg == NULL )
		{
			return;
		}
		
		bcast_msg->nodeid = rec_msg->nodeid;
		bcast_msg->seq_num = rec_msg->seq_num;
		
		if( call AMSend.send( AM_BROADCAST_ADDR, &packet, sizeof( rec_msg ) ) == SUCCESS)
		{
			busy = TRUE;
		}
	}
	
	event void Boot.booted() 
	{
		call Control.start();
	}
	
	event void Control.startDone( error_t error )
	{
		if ( error != SUCCESS )
		{
			call Control.start();
		}
		else 
		{
			node_id = TOS_NODE_ID;
			call Timer.startPeriodic( TIMER_PERIOD_MILLI );
		}
	}
	
	event void Control.stopDone( error_t error ) {}
	
	event void Timer.fired()
	{
		if( (!busy) && (node_id == 1))
		{
			msg_t *bcast_msg; 
			bcast_msg = ( msg_t* ) ( call Packet.getPayload( &packet, sizeof( msg_t) ) );
			
			if ( bcast_msg == NULL )
			{
				return;
			}
			seq_num++;
			bcast_msg->nodeid = node_id;
			bcast_msg->seq_num = seq_num;
			
			if( call AMSend.send( AM_BROADCAST_ADDR, &packet, sizeof( msg_t ) ) == SUCCESS)
			{
				
				busy = TRUE;
			}
		}
	}
	
	event void AMSend.sendDone( message_t* msg, error_t error )
	{
		if( &packet == msg ) 
		{
			busy = FALSE;
		}
	}
	
	event message_t* Receive.receive( message_t* msg, void* payload, uint8_t len )
	{
		if ( len == sizeof( msg_t ) )
		{
			rec_msg = ( msg_t* ) payload;
			dbg("bcast_test", "%d %d\n", rec_msg->nodeid, rec_msg->seq_num);
			
			post forward();
		}
		return msg;
	}

}