action = "simulation"
sim_tool = "ghdl"
top_module = "xwb_evt_cnt_tb"

modules = {"local" : ["../"]}

ghdl_opt = "--std=08"

sim_post_cmd = "ghdl -r --std=08 xwb_evt_cnt_tb --wave=xwb_evt_cnt_tb.ghw --assert-level=error"
