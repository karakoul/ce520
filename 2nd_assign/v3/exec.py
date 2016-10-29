import subprocess
from subprocess import Popen, PIPE

topo = raw_input("if you want to generate a topo press 1, if topo already exists press 2 ")
num_of_nodes = raw_input("Give me the number of nodes ")

if(topo == "1"):
	# subprocess.call(("python topo_gen.py " + str(num_of_nodes)), shell = True)
	topo_type = raw_input("Please press (1) for tree, (2) for chain, (3) for random graph ")
	gain_low = raw_input("Please enter the lowest gain ")
	gain_max = raw_input("Please enter the maximum gain ")
	cmd = ["python topo_gen.py " + str(num_of_nodes) + " " + str(topo_type) + " " + str(gain_low) + " " + str(gain_max)]
	result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
	out = result.stdout.read()
	print out


# subprocess.call(("python run2.py " + str(num_of_nodes)), shell = True)
cmd = ["python run2.py " + str(num_of_nodes)]
result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
out = result.stdout.read()
print out


# subprocess.call(("python extract_results.py"), shell = True)
cmd = ["python extract_results.py"]
result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
out = result.stdout.read()
print out



# noise = open( "./meyer-heavy.txt", "r" )
# new = open("meyer-heavy-medium.txt", 'w')
# i = 0
# for line in noise:
# 	new.write(line)
# 	i += 1
# 	if(i == 10000):
# 		break
# new.close()
# noise.close()