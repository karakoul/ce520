import TOSSIM
import sys
import random

from TOSSIM import *

t = TOSSIM.Tossim([])
t.addChannel( "VM2", sys.stdout);
t.addChannel( "VM",sys.stdout );

m = t.getNode(0)
m.bootAtTime(0)

time = t.time()
lastTime = -1
while (time + 3 * t.ticksPerSecond() > t.time()):
    timeTemp = int(t.time()/(t.ticksPerSecond()*100))
    if( timeTemp > lastTime ): #stampa un segnale ogni 10 secondi... per leggere meglio il log
        lastTime = timeTemp
        print "----------------------------------SIMULATION: ~", lastTime*10, " s ----------------------"
    t.runNextEvent()
print "----------------------------------END OF SIMULATION-------------------------------------"


# for i in xrange(100000000):
#   t.runNextEvent()

