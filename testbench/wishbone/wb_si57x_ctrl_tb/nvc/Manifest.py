action = "simulation"
sim_tool = "nvc"
top_module = "xwb_si57x_ctrl_tb"

modules = {"local" : ["../"]}

nvc_opt = "--std=2008"
nvc_elab_opt = "--no-collapse"

sim_post_cmd = "nvc -r --dump-arrays --exit-severity=error %s --wave=%s.fst --format=fst"%(top_module, top_module)
