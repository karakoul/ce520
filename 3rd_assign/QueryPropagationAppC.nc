#include "QueryPropagation.h"

configuration QueryPropagationAppC
{}

implementation
{
	components MainC, QueryPropagationC as App, LedsC;
	components new TimerMilliC() as QueryTimer;
	components new TimerMilliC() as ForwardQueryTimer;
	components new TimerMilliC() as SensorTimer;
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 

	components new DemoSensorC();

#ifdef QUERY_SERIAL
	components SerialActiveMessageC;
  	components new SerialAMSenderC( AM_ID );
  	components new SerialAMReceiverC( AM_ID );
	
	App.Packet -> SerialAMSenderC;
  	App.AMPacket -> SerialAMSenderC;
 	App.AMSend -> SerialAMSenderC;
  	App.AMControl -> SerialActiveMessageC;
  	App.SerialRec -> SerialAMReceiverC;
#endif

	App.Boot -> MainC.Boot;
	App.Leds -> LedsC;
	App.QueryTimer -> QueryTimer;
	App.ForwardQueryTimer -> ForwardQueryTimer;
	App.SensorTimer -> SensorTimer;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	App.AMPacket -> AMSenderC;

	App.Read -> DemoSensorC;

}