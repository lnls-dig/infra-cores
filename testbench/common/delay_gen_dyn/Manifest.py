action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "delay_gen_dyn_tb"
sim_top = "delay_gen_dyn_tb"

files = ["delay_gen_dyn_tb.vhd"]

modules = {"local" : ["../../../modules/common"]}
