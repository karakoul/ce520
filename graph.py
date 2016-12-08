import networkx as nx
import matplotlib.pyplot as plt

f = open("topo.txt", "r")

G = nx.DiGraph()

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    G.add_edge( int(s[0]), int(s[1]) )

nx.draw(G,with_labels=True)

plt.grid()
plt.show()
