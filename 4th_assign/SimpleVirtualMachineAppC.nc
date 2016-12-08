#include "SimpleVirtualMachine.h"


configuration SimpleVirtualMachineAppC
{}

implementation
{
	components MainC, SimpleVirtualMachineC as App, LedsC;

  components new TimerMilliC() as VMTimer;

	components SerialActiveMessageC;
	components new SerialAMSenderC( AM_ID );
  components new SerialAMReceiverC( AM_ID );

  //components new DemoSensorC();
  //App.Read -> DemoSensorC;
  components new HamamatsuS1087ParC();
  App.Read -> HamamatsuS1087ParC;

  App.Boot -> MainC.Boot;
	App.Leds -> LedsC;
  App.VMTimer -> VMTimer;
  
  App.SerialPacket -> SerialAMSenderC;
  App.SerialAMPacket -> SerialAMSenderC;
 	App.SerialSend -> SerialAMSenderC;
  App.SerialAMControl -> SerialActiveMessageC;
  App.SerialReceive -> SerialAMReceiverC;
}