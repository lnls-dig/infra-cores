def __dirs():
	dirs = ["common"]

	if (target == "xilinx" and syn_device[0:4].upper()=="XC7A"):
		dirs.extend(["artix7"]);
	elif (target == "xilinx" and syn_device[0:4].upper()=="XC7K"):
		dirs.extend(["kintex7"]);
	#else: #add platform here and generate the corresponding ip cores
	return dirs

modules = {
    "local" : __dirs()
           }
