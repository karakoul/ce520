#include "QueryPropagation.h"

configuration QueryPropagationAppC
{}

implementation
{
	components MainC, QueryPropagationC as App;
	components new TimerMilliC() as QueryTimer;
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 

	App.Boot -> MainC.Boot;

	App.QueryTimer -> QueryTimer;
	App.AMSend -> AMSenderC;
	App.Receive -> AMReceiverC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
}