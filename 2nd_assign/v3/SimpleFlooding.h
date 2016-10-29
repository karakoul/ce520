#ifndef SIMPLE_FLOODING_H
#define SIMPLE_FLOODING_H

enum
{
	AM_ID = 20, // 20-29
};

#define MAX_BROADCASTS 5
#define MAX_CACHE_SIZE 5
#define BROADCAST_PERIOD_MILLI 5 


typedef nx_struct bcast_msg
{
	nx_uint16_t sourceID;
	nx_uint16_t seqNo;
} bcast_msg_t;

#endif