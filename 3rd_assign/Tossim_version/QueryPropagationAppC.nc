#include "QueryPropagation.h"

configuration QueryPropagationAppC
{}

implementation
{
	components MainC, QueryPropagationC as App, LedsC;
	components new TimerMilliC() as QueryTimer;
	components new TimerMilliC() as ForwardQueryTimer;
	components new TimerMilliC() as SensorTimer;
	components new TimerMilliC() as PiggybackTimer;
	components new TimerMilliC() as StatsTimer;
	components new TimerMilliC() as JoinTimer;
	components new TimerMilliC() as ResultTimer;
	
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 

	components new DemoSensorC(); // TODO: hamamatsu

	components SerialActiveMessageC;
  	components new SerialAMSenderC( AM_ID );
  	components new SerialAMReceiverC( AM_ID );
	
	App.SerialPacket -> SerialAMSenderC;
  	App.SerialAMPacket -> SerialAMSenderC;
 	App.SerialSend -> SerialAMSenderC;
  	App.SerialAMControl -> SerialActiveMessageC;
  	App.SerialReceive -> SerialAMReceiverC;

  	App.RadioSend -> AMSenderC;
	App.RadioReceive -> AMReceiverC;
	App.RadioAMControl -> ActiveMessageC;
	App.RadioPacket -> AMSenderC;
	App.RadioAMPacket -> AMSenderC;

	App.Boot -> MainC.Boot;
	App.Leds -> LedsC;
	App.QueryTimer -> QueryTimer;
	App.JoinTimer -> JoinTimer;
	App.ForwardQueryTimer -> ForwardQueryTimer;
	App.SensorTimer -> SensorTimer;
	App.PiggybackTimer -> PiggybackTimer;
	App.StatsTimer -> StatsTimer;
	App.ResultTimer -> ResultTimer;
	
	App.Read -> DemoSensorC;

}