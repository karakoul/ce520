configuration BrightnessSensorAppC {}

implementation {

  components MainC, BrightnessSensorC, LedsC;
  components new TimerMilliC() as Timer;
  //components new DemoSensorC();
  components new HamamatsuS1087ParC();
  
  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_BRIGHTNESS);
  components new SerialAMReceiverC(AM_BRIGHTNESS);
  

  BrightnessSensorC -> MainC.Boot;
  BrightnessSensorC.Timer -> Timer;
  BrightnessSensorC.Leds  -> LedsC;
  //BrightnessSensorC.Read -> DemoSensorC;
  BrightnessSensorC.Read -> HamamatsuS1087ParC;
  
  BrightnessSensorC.Packet -> SerialAMSenderC;
  BrightnessSensorC.AMPacket -> SerialAMSenderC;
  BrightnessSensorC.AMSend -> SerialAMSenderC;
  BrightnessSensorC.Control -> SerialActiveMessageC;
  BrightnessSensorC.Receive -> SerialAMReceiverC;
}