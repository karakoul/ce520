//http://www.btnode.ethz.ch/static_docs/tinyos-2.x/pdf/tep116.pdf, http://www.cse.wustl.edu/~lu/cse521s/Slides/tutorial

#ifndef QUERY_PROPAGATION_H
#define QUERY_PROPAGATION_H
 
#define MAX_CACHE_SIZE 20
#define BROADCAST_PERIOD_MILLI 1 
#define PAYLOAD_LENGTH 10

#define NONE 1
#define PIGGYBACK 2
#define STATS 3

enum
{
	AM_ID = 20, // 20-29
	BRIGHTNESS = 0,
	HUMIDITY = 1,
	TEMPERATURE = 2,
};

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t seqNo;
	nx_uint16_t sensorT;			// type 0: brightness, type 1: humidity, type 2: temperature 
	nx_uint16_t samplingPeriod;	// measured in seconds
	nx_uint16_t lifeTime;		// measured in seconds
	nx_uint16_t aggregationMode;	// type 1: none, type 2: piggyback, type 3: stats
	nx_uint16_t currentPeriod; // indicates the current period
	nx_uint16_t address;
	nx_uint16_t depth;

} query_t;

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t sensorValue;
	nx_uint16_t iterPeriod;

} none_t;

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t sensorValue[PAYLOAD_LENGTH];
	nx_uint16_t iterPeriod;
	nx_uint16_t depth;

} piggyback_t;

typedef nx_struct
{

} stats_t;

typedef struct
{
	uint16_t iter;
	uint16_t sensorValue[ PAYLOAD_LENGTH ];
	bool check;

} cacheP_t;

#endif