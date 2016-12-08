import subprocess
from subprocess import Popen, PIPE
topo = { "2":[11,5], "1":[16,8] }

for topo_type in  topo.keys():
	for num_of_nodes in topo[topo_type]:
		gain_low = 0
		gain_max = 0
		cmd = ["python topo_gen.py " + str(num_of_nodes) + " " + str(topo_type) + " " + str(gain_low) + " " + str(gain_max)]
		result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
		out = result.stdout.read()
		print out


		for i in range(10):
			print "===================iter = "+str(i)+"======topo_type = "+str(topo_type)+"=========num_of_nodes="+str(num_of_nodes)+"================================"
			cmd = ["python run.py " + str(num_of_nodes)]
			result = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
			out = result.stdout.read()
			print out



