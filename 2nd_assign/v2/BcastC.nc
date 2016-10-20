#include "Bcast.h"
#include "Timer.h"

module BcastC 
{
	uses interface Boot;
	uses interface Leds;
// 	uses interface Timer<TMilli> as Timer;
	
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
	uint16_t seq_num = 0;
	msg_t *rec_msg;
	msg_t cache[ MAX_ARRAY_SIZE ];
	uint16_t index = 0;
	
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
		
		dbg("Send", "send %d %d\n", rec_msg->nodeid, rec_msg->seq_num);
		
		cache[ index ] = *rec_msg;
		
		index = ( index + 1 ) % MAX_ARRAY_SIZE;
	}
	
	task void search()
	{
		int i;
		
		for ( i = 0; i < MAX_ARRAY_SIZE; i++ )
		{
			if ( ( cache[i].nodeid == rec_msg->nodeid ) && ( cache[i].seq_num >= rec_msg->seq_num ) )
			{
				return;
			}
		}
		
		post forward();
		
	}
	
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
		if ( error != SUCCESS )
		{
			call Control.start();
		}
		else 
		{
			node_id = TOS_NODE_ID;
// 			call Timer.startPeriodic( TIMER_PERIOD_MILLI );
			if( (!busy) && ((node_id == 1)||(node_id == 4)||(node_id == 10)))
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
				
				cache[ index ] = *bcast_msg;
			
				index = ( index + 1 ) % MAX_ARRAY_SIZE;
				
				dbg("Send", "send %d %d\n", bcast_msg->nodeid, bcast_msg->seq_num);
			}
		}
	}
	
	event void Control.stopDone( error_t error ) {}
	
// 	event void Timer.fired()
// 	{
// 		if( (!busy) && (node_id == 1))
// 		{
// 			msg_t *bcast_msg; 
// 			bcast_msg = ( msg_t* ) ( call Packet.getPayload( &packet, sizeof( msg_t) ) );
// 			
// 			if ( bcast_msg == NULL )
// 			{
// 				return;
// 			}
// 			seq_num++;
// 			bcast_msg->nodeid = node_id;
// 			bcast_msg->seq_num = seq_num;
// 			
// 			if( call AMSend.send( AM_BROADCAST_ADDR, &packet, sizeof( msg_t ) ) == SUCCESS)
// 			{
// 				
// 				busy = TRUE;
// 			}
// 			
// 			cache[ index ] = *bcast_msg;
// 		
// 			index = ( index + 1 ) % MAX_ARRAY_SIZE;
// 			
// 			dbg("Send", "send %d %d\n", bcast_msg->nodeid, bcast_msg->seq_num);
// 		}
// 	}
	
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
			dbg("Receive", "receive %d %d\n", rec_msg->nodeid, rec_msg->seq_num);
			
			post search();
		}
		return msg;
	}

}