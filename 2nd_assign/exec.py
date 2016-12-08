import subprocess
from subprocess import Popen, PIPE

num_of_nodes = raw_input("Give me the number of nodes ")
topo = raw_input("if you want to generate a topo press 1, if topo already exists press 2 ")
print ( "\n\n========================== num_of_nodes = " + str(num_of_nodes) + " type = " + str(topo) + " =============\n" )


if(topo == "1"):
	topo_type = raw_input("Please press (1) for tree, (2) for chain, (3) for random graph ")
	gain_low = raw_input("Please enter the lowest gain ")
	gain_max = raw_input("Please enter the maximum gain ")
	cmd = ["python topo_gen.py " + str(num_of_nodes) + " " + str(topo_type) + " " + str(gain_low) + " " + str(gain_max)]
	result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
	out = result.stdout.read()
	print out


cmd = ["python run.py " + str(num_of_nodes)]
result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
out = result.stdout.read()
print out

cmd = ["python extract_results.py"]
result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
out = result.stdout.read()
print out

