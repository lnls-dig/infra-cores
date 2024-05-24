action = "simulation"
sim_tool = "ghdl"
top_module = "si57x_model_tb"

modules = {"local" : ["../"]}

ghdl_opt = "--std=08"

sim_post_cmd = "ghdl -r --std=08 %s --wave=%s.ghw"%(top_module, top_module)
