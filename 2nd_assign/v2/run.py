#! /usr/bin/python
from TOSSIM import *
import sys
import os.path

t = Tossim([])
r = t.radio()
f = open("topo.txt", "r")

if(os.path.exists("results.txt")):
  os.remove("results.txt")

fd = open("results.txt", 'w')

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

t.addChannel("Receive", fd)
t.addChannel("Send", fd)

noise = open("./meyer-heavy.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, 11):
      t.getNode(i).addNoiseTraceReading(val)

for i in range(1, 11):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()
for i in range(1,11):
  t.getNode(i).bootAtTime(0);
# t.getNode(2).bootAtTime(0);
# t.getNode(3).bootAtTime(0);
# t.getNode(4).bootAtTime(0);
# t.getNode(5).bootAtTime(0);
# t.getNode(6).bootAtTime(0);
# t.getNode(7).bootAtTime(0);
# t.getNode(8).bootAtTime(0);
# t.getNode(9).bootAtTime(0);
# t.getNode(10).bootAtTime(0);

for i in range(10000):
  t.runNextEvent()
