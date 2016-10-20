configuration BcastAppC {}

implementation 
{

  components MainC, LedsC, BcastC;
  components new TimerMilliC() as Timer;
  
  components ActiveMessageC;
  components new AMSenderC( AM_ID );
  components new AMReceiverC( AM_ID );
  
  
  BcastC -> MainC.Boot;
  BcastC.Leds  -> LedsC;
  BcastC.Timer -> Timer;
  
  BcastC.Packet -> AMSenderC;
  BcastC.AMPacket -> AMSenderC;
  BcastC.AMSend -> AMSenderC;
  BcastC.Control -> ActiveMessageC;
  BcastC.Receive -> AMReceiverC;
  
 }
