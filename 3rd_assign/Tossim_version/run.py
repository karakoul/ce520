from TOSSIM import *
import sys
import os.path
import re

t = Tossim([])
r = t.radio()

num_of_nodes = int(sys.argv[1])

f = open("topo.txt", "r")


if(os.path.exists("results.txt")):
	os.remove("results.txt")
fd = open("results.txt", 'w')


for line in f:
  s = line.split()
  if s:
    # print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))


# t.addChannel( "Originator", sys.stdout )
#t.addChannel( "Depth", sys.stdout )
t.addChannel( "Join", sys.stdout )

#t.addChannel( "Send", sys.stdout )
#t.addChannel( "Send1", sys.stdout )

# t.addChannel( "Piggyback", sys.stdout );
t.addChannel( "Move", sys.stdout );
# t.addChannel( "Cache", sys.stdout );
# t.addChannel( "Stats1", sys.stdout );
# t.addChannel( "Debug", sys.stdout );
# t.addChannel( "None", sys.stdout );

# metrhseis
# t.addChannel( "transmissions", sys.stdout );
# t.addChannel( "Coverage", sys.stdout );
# t.addChannel( "Delay", sys.stdout );


noise = open( "meyer-short.txt", "r" )


for line in noise:
	str1 = line.strip()
	if str1:
		val = int(str1)

		for i in range(1, num_of_nodes+1):
			t.getNode(i).addNoiseTraceReading(val)

for i in range(1,  num_of_nodes+1):
	# print( "Creating noise model for "+str(i) +"\n")
	t.getNode(i).createNoiseModel()


for i in range (1, num_of_nodes):
    time=i * t.ticksPerSecond() / 100
    m=t.getNode(i)
    m.bootAtTime(0)
    m.createNoiseModel()
    # print "Booting ", i, " at ~ ", time*1000/t.ticksPerSecond(), "ms"

time=5 * t.ticksPerSecond() / 100
m=t.getNode(5)
m.bootAtTime(time*100)
m.createNoiseModel()
print "Booting ", 5, " at ~ ", time*1000*100/t.ticksPerSecond(), "ms"
 
time = t.time()
lastTime = -1
while (time*10000 + 300 * t.ticksPerSecond() > t.time()):
    timeTemp = int(t.time()/(t.ticksPerSecond()*10))
    if(timeTemp == 10):
        for i in range(num_of_nodes+1):
            m = t.getNode(5)
            m.turnOff()
    
        r.remove(4,5)
        r.remove(5,4)
        

        r.add(1,5,0)
        r.add(5,1,0)


        for i in range(num_of_nodes+1):
            m = t.getNode(i)
            m.turnOn()

    if( timeTemp > lastTime ): #stampa un segnale ogni 10 secondi... per leggere meglio il log
        lastTime = timeTemp
        # print "----------------------------------SIMULATION: ~", lastTime*10, " s ----------------------"
    t.runNextEvent()
# print "----------------------------------END OF SIMULATION-------------------------------------"


fd.close()
fd = open("results.txt", 'r')
for line in fd:
	print re.sub("DEBUG..\d..","",line)

fd.close()