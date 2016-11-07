#ifndef QUERY_PROPAGATION_H
#define QUERY_PROPAGATION_H

#define MAX_BROADCASTS 5
#define MAX_CACHE_SIZE 5
#define BROADCAST_PERIOD_MILLI 5 

enum
{
	AM_ID = 20, // 20-29
	BRIGHTNESS = 1,
	HUMIDITY = 2,
	TEMPERATURE = 3,
};

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t seqNo;
	nx_uint8_t sensorT;			// type 1: brightness, type 2: humidity, type 3: temperature 
	nx_uint16_t samplingPeriod;	// measured in seconds
	nx_uint16_t lifeTime;		// measured in seconds
	nx_uint8_t aggregationMode;	// type 1: none, type 2: piggyback, type 3: stats

} query_t;

typedef nx_struct
{
	nx_uint16_t sensorID;
	nx_uint16_t sensorValue;
	nx_uint16_t iterPeriod;

} aggregation_none_t;

typedef nx_struct
{

} aggregation_piggyback_t;

typedef nx_struct
{

} aggregation_stats_t;

#endif