me = open("meyer-heavy.txt", 'r')
new = open("meyer-heavy-medium.txt", 'w')
counter = 0
for line in me:
	new.write(line)
	counter += 1
	if(counter == 20000):
		break

me.close()
new.close()
