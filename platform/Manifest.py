files = ["platform_generic_pkg.vhd"]

if action=="synthesis":
    if target=="xilinx":
        modules = {"local": "xilinx"}
    else:
        print ("WARNING: FPGA family not supported. Some functionality might be unavailable")
elif action=="simulation":
    modules = {"local": "simulation"}
else:
    print ("WARNING: action {} not supported".format(action))
