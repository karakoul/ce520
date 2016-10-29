from random import randint
import random


topo_type = raw_input("Please press (1) for tree, (2) for chain, (3) for random graph ")
num_nodes = raw_input("Please enter the number of nodes ")
gain_low = raw_input("Please enter the lowest gain ")
gain_max = raw_input("Please enter the maximum gain ")

num_nodes = int(num_nodes)
gain_low = float(gain_low)
gain_max = float(gain_max)

nodes = {}
for i in range(1,num_nodes+1):
	nodes[i] = []

# tree
if(topo_type == '1'):
	cur = 0
	for i in range(1,num_nodes+1):
		if(cur<(num_nodes)):
			nodes[i].append(cur+1)
			nodes[cur+1].append(i)
			cur += 1

			if(cur<(num_nodes-1)):
				nodes[i].append(cur+1)
				nodes[cur+1].append(i)
				cur += 1

# chain
if(topo_type == '2'):
	for i in range(1,num_nodes):
		nodes[i].append(i+1)
		nodes[i+1].append(i)

#graph
if(topo_type == '3'):
	for i in range(1,num_nodes+1):
		num_of_neighbors = randint(1,num_nodes+1)
		for j in range(num_of_neighbors):
			neighbor = i
			while neighbor==i:
				neighbor = randint(1,num_nodes)
			if(neighbor not in nodes[i]):
				nodes[i].append(neighbor)
				nodes[neighbor].append(i)

gain = 0.0
fd = open("topo.txt",'w') 
for i in nodes.keys():
	for j in nodes[i]:
		gain = round(random.uniform(gain_low,gain_max),1)
		if(gain != 0.0):
			gain = "-" + str(gain)
		else:
			gain = str(gain)
		fd.write(str(i) + " " + str(j) + " " + gain)
		fd.write("\n")

fd.close()