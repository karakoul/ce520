#include "QueryPropagation.h"

configuration QueryPropagationAppC
{}

implementation
{
	components MainC, QueryPropagationC as App, LedsC;
	components new TimerMilliC() as QueryTimer;
	components new TimerMilliC() as SensorTimer;
	components new TimerMilliC() as ResultTimer;
	components new TimerMilliC() as PiggybackTimer;
	components new TimerMilliC() as StatsTimer;
	components new TimerMilliC() as JoinTimer;
	components new HamamatsuS1087ParC();
	
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 

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
	App.Read -> HamamatsuS1087ParC;
	App.QueryTimer -> QueryTimer;
	App.SensorTimer -> SensorTimer;
	App.ResultTimer -> ResultTimer;
	App.PiggybackTimer -> PiggybackTimer;
	App.StatsTimer -> StatsTimer;
	App.JoinTimer -> JoinTimer;
}