#include "QueryPropagation.h"

configuration QueryPropagationAppC
{}

implementation
{
	components MainC, QueryPropagationC as App;
	components new TimerMilliC() as QueryTimer;
	components new TimerMilliC() as ForwardQueryTimer;
	components new TimerMilliC() as SensorTimer;
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 

	components new DemoSensorC();

	App.Boot -> MainC.Boot;

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