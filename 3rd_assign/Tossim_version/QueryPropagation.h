#ifndef QUERY_PROPAGATION_H
#define QUERY_PROPAGATION_H
 
#define MAX_CACHE_SIZE 20
#define BROADCAST_PERIOD_MILLI 2
#define PAYLOAD_LENGTH 10

#define DEBUG_INFO
#define SIMULATION

enum
{
	AM_ID = 20,			// 20-29
	BRIGHTNESS = 0,
	HUMIDITY = 1,
	TEMPERATURE = 2,
	NONE = 0,
	PIGGYBACK = 1,
	STATS = 2
};

typedef nx_struct
{
	nx_uint16_t originatorID;
	nx_uint16_t sensorT;			// type 0: brightness, type 1: humidity, type 2: temperature 
	nx_uint16_t samplingPeriod;		// measured in seconds
	nx_uint16_t lifeTime;			// measured in seconds
	nx_uint16_t aggregationMode;	// type 1: none, type 2: piggyback, type 3: stats
	nx_uint16_t currentPeriod;		// indicates the current period
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
	nx_uint16_t sensorValue[ PAYLOAD_LENGTH ];
	nx_uint16_t period;
	nx_uint16_t depth;

} piggyback_t;

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t minValue;
	nx_uint16_t avgValue;
	nx_uint16_t maxValue;
	nx_uint16_t period;
	nx_uint16_t depth;
	nx_uint16_t numOfResults;
	nx_uint16_t foo;
	
} stats_t;

typedef struct
{
	int16_t period;
	uint16_t sensorValue;
} cacheP_t;

typedef struct
{
	int16_t period;
	uint16_t maxValue;
	uint16_t avgValue;
	uint16_t minValue;
	uint16_t numOfResults;

} cacheS_t;

typedef nx_struct
{
	nx_uint16_t sensorID;

} join_t;


#endif