import re
nodes = {}
# file_name = raw_input("Give the file_name ")
file_name = 'results.txt'
fd = open(file_name)


for line in fd:
	reg = re.compile(r'.*([(]\d+[)])')
	reg_res = reg.search(line)
	if(reg_res):
		node = reg_res.group(1)
		node = node[1:len(node)-1]
		if (node not in nodes.keys()):
			nodes[node] = 0
		reg_send = re.compile(r'.*([s][e][n][d])')
		reg_res_send = reg_send.search(line)
		if( reg_res_send):
			nodes[node] += 1

transmissions = 0
for node in nodes.values():
	transmissions += node

average_transmission = transmissions/float(len(nodes))	

print nodes
print "Transmissions " + str(transmissions)
print "Avg_transmission per node " + str(average_transmission)

message = ''
while message!='q':
	fd.seek(0,0)
	message = raw_input("type the message you want ")
	reg_message = "[r][e][c][e][i][v][e][ ]"
	for i in message:
		reg_message += "[" + i + "]"
		
	counter = 0
	for line in fd:
		reg = re.compile(reg_message)
		reg_res = reg.search(line)
		if(reg_res):
			counter += 1
	print counter




