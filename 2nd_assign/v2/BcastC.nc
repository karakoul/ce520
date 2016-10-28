#include "Bcast.h"
#include "Timer.h"
#include <stdlib.h>

module BcastC 
{
	uses interface Boot;
	uses interface Leds;
 	uses interface Timer<TMilli> as Timer;
	uses interface Timer<TMilli> as Forward_timer;
	
	uses interface SplitControl as Control;
	uses interface AMSend;
	uses interface Packet;
	uses interface AMPacket;
	uses interface Receive;
}

implementation 
{
	message_t forward_packet;
	message_t source_packet;
	bool busy = FALSE;
	uint16_t node_id = 0;
	uint16_t seq_num = 0;
	msg_t *rec_msg;
	msg_t cache[ MAX_ARRAY_SIZE ];
	uint16_t index = 0;
	int counter = 0;
	
	
	task void init()
	{
		int i;
		
		for ( i = 0; i < MAX_ARRAY_SIZE; i++ )
		{
			cache[i].nodeid = 0;
			cache[i].seq_num = 0;
			
		}
	}
	
	event void Boot.booted() 
	{
		post init();
		
		call Control.start();
	}
	
	event void Control.startDone( error_t error )
	{
		int i = 0;
		
		if ( error != SUCCESS )
		{
			call Control.start();
		}
		else 
		{
			node_id = TOS_NODE_ID;
			i = rand()%5000;
			i++;
			call Timer.startPeriodic(i);
		}
	}
	
	event void Control.stopDone( error_t error ) {}
	
	event void Timer.fired()
	{
		
		if ( busy == TRUE )
		{
			return;
		}

		if( node_id%2 == 1 && counter<5)
		{
			msg_t *bcast_msg; 
			int i;

			bcast_msg = ( msg_t* ) ( call Packet.getPayload( &source_packet, sizeof( msg_t) ) );
			counter++;
			
			if ( bcast_msg == NULL )
			{
				return;
			}
			seq_num++;
			bcast_msg->nodeid = node_id;
			bcast_msg->seq_num = seq_num;
			
			if( call AMSend.send( AM_BROADCAST_ADDR, &source_packet, sizeof( msg_t ) ) == SUCCESS)
			{
				
				busy = TRUE;
			}

			dbg("Send", "send %d %d, time: %s\n", bcast_msg->nodeid, bcast_msg->seq_num, sim_time_string());
		}
		else if(counter == 5)
		{
			call Timer.stop();
			dbg( "Send", "Timer stopped\n");
		}
	}
	
	event void Forward_timer.fired() 
	{
		msg_t *bcast_msg; 

		if ( busy == TRUE )
		{
			call Forward_timer.startOneShot( node_id%10 );
			return;
		}

		bcast_msg = ( msg_t* ) ( call Packet.getPayload( &forward_packet, sizeof( msg_t) ) );
		
		
		if ( bcast_msg == NULL )
		{
			return;
		}
		
		bcast_msg->nodeid = rec_msg->nodeid;
		bcast_msg->seq_num = rec_msg->seq_num;
		
		
		if( call AMSend.send( AM_BROADCAST_ADDR, &forward_packet, sizeof( msg_t ) ) == SUCCESS)
		{
			busy = TRUE;
		}
		
		dbg("Send", "send %d %d\n", bcast_msg->nodeid, bcast_msg->seq_num);

			
		
	}
	event void AMSend.sendDone( message_t* msg, error_t error )
	{
		if( &source_packet == msg ) 
		{
			dbg("Send", "BUSY\n");
			busy = FALSE;
		}
		else if( &forward_packet == msg ) 
		{
			dbg("Send", "BUSY\n");
			busy = FALSE;
		}
	}
	
	event message_t* Receive.receive( message_t* msg, void* payload, uint8_t len )
	{
		int i;
		if ( len == sizeof( msg_t ) )
		{
			rec_msg = ( msg_t* ) payload;
			dbg("Receive", "receive %d %d, time: %s\n", rec_msg->nodeid, rec_msg->seq_num, sim_time_string());
			if(rec_msg->nodeid == node_id)
			{
				return msg;
			}
			for ( i = 0; i < MAX_ARRAY_SIZE; i++ )
			{
				if ( ( cache[i].nodeid == rec_msg->nodeid ) && ( cache[i].seq_num >= rec_msg->seq_num ) )
				{
					return msg;
				}
			}

			cache[ index ] = *rec_msg;
		
			index = ( index + 1 ) % MAX_ARRAY_SIZE;
			
			call Forward_timer.startOneShot(node_id%10);
			//post search();
			
		}

		return msg;
	}

}