action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "trigger_io_tb"
sim_top = "trigger_io_tb"

files = ["trigger_io_tb.vhd"]

modules = {"local" : ["../../../modules/common",
                      "../../../platform/xilinx/common",
                      "../../../ip_cores/general-cores"]}
