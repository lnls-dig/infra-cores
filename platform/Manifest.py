files = ["platform_generic_pkg.vhd"]

if target=="xilinx":
	modules = {"local" : "xilinx"}
else:
    print ("WARNING: FPGA family not supported. Some functionality might be unavailable")
