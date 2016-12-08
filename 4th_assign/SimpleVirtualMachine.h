#ifndef SIMPLE_VIRTUAL_MACHINE_H
#define SIMPLE_VIRTUAL_MACHINE_H

enum
{
	AM_ID = 20, // 20-29
	MAX_PAYLOAD = 30, // todo: find real max payload length
	NUM_REGISTER = 6, // todo: maybe change to 7??
	MAX_APPS = 3,
	MAX_APP_SIZE = 255,
	APP_TERMINATE = -1,
	APP_READY = 1,
	APP_WAIT = 0,
};

typedef nx_struct
{
	nx_uint8_t id;
	nx_uint8_t instr;
	nx_int8_t registers[ NUM_REGISTER ];

} debug_t;

typedef nx_struct 
{
	nx_int16_t id;				/* */
	nx_int16_t seqNum;					/* -1 for quit/terminate */
	nx_uint8_t binary[ MAX_PAYLOAD ];	/* */

} app_msg_t;

typedef struct
{
	int8_t appID;						/* The virtual id assigned by the VM for a specific application */
	int8_t id;							/* The id assigned by the user when sending the binary through serial */
	uint8_t binary[ MAX_APP_SIZE ];		/* Binary code of the application */
	int8_t registers[ NUM_REGISTER ];	/* Registers for each application, R1 - R6 */
	int16_t pc;							/* Program counter, points at the next instruction for execution */
	int8_t status;						/* READY, WAIT, TERMINATE */
	bool getResults;					/* Waits for brightness results */
	int16_t timerCnt;
	bool hasTimer;
	
} app_t;

typedef struct
{
	int8_t id;
	uint16_t data;

} data_t;

typedef struct
{
	int8_t id;
	uint16_t duration;
	uint16_t period;

} timers_t;

#endif