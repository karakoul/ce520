/**
 * Assignment 2
 *
 * Develop an algorithm/mechanism for a best-effort network-wide broadcast.
 * The approach is to propagate a packet to nodes using simple flooding. 
 * For each broadcast, the system should, eventually, reach a steady silent state where nodes stop transmitting packets. 
 * To achieve this, duplicate packets should be handled appropriately.
 * Your mechanism should also try to avoid collisions that might occur 
 * if two or more nodes that are in range of each other attempt to transmit a packet simultaneously. 
 * This is especially important given that the radio support of the sensor nodes is rather simple 
 * (there are no sophisticated collision detection/avoidance schemes).
 *
 * Evaluate your algorithm in TOSSIM for different network topologies (chain, tree, grid), different number of nodes, 
 * and different number of concurrent sources. Use an application issues a broadcast periodically. 
 * For each case, record (i) the actual per-node transmissions, (ii) the total number of transmissions, 
 * (iii) the average per-node transmissions, (iv) the coverage (number of nodes that received a given message), 
 * and (v) the minimum, average and maximum message latency.
 * 
 * Develop a simple application that uses the mechanism to propagate to the network every message it receives over the serial port
 * 
 * Staging
 *
 * 1. Develop and test your flooding mechanism using TOSSIM
 * 2. Develop code that receives a packet from the serial port
 * 3. Add code to transmit the received packet via the broadcast mechanism
 * 4. Add your flooding algorithm 
 *
 * Hints
 *
 * Read carefully the radio communication tutorial
 * Think how to use the LEDs of the nodes in order to visualize the state of the system during real trials, 
 * in a practical way that is easy to observe.
 * Try to see how well randomness works vs more deterministic back-off algorithms.
 * Note that when using TOSSIM all nodes will run the same code/firmware. 
 * Node-specific behavior in the simulations can be achieved by introducing branches in the code, based on the local node identifier.
 * 
 * @author Apostolos Tsaousis
 * @author Katerina Karakoula
 * @date   October 28 2016
 */
#define SIMPLE_FLOODING_BUTTON

#include "SimpleFlooding.h"

configuration SimpleFloodingAppC
{}

implementation
{
	components MainC, SimpleFloodingC as App, LedsC;
	components new TimerMilliC() as Forward;
	components new AMSenderC( AM_ID );
	components new AMReceiverC( AM_ID );
	components ActiveMessageC; 
	
	#ifdef SIMPLE_FLOODING_BUTTON
	components UserButtonC;
	App.Get -> UserButtonC;
	App.Notify -> UserButtonC;
	
	components SerialActiveMessageC;
  	components new SerialAMSenderC( AM_ID );
  	components new SerialAMReceiverC( AM_ID );
	App.Packet -> SerialAMSenderC;
  	App.AMPacket -> SerialAMSenderC;
 	App.AMSend -> SerialAMSenderC;
  	App.AMControl -> SerialActiveMessageC;
  	App.SerialRec -> SerialAMReceiverC;
	#endif
	
	#ifndef SIMPLE_FLOODING_BUTTON
	components new TimerMilliC() as Broadcast;
	App.Broadcast -> Broadcast;
	#endif
	
	App.Boot -> MainC.Boot;

	App.Forward -> Forward;
	App.Leds -> LedsC;
	App.Rec -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.AMControl -> ActiveMessageC;
	App.Packet -> AMSenderC;
	
}