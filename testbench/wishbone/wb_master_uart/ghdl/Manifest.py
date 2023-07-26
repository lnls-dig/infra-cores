action = "simulation"
sim_tool = "ghdl"
top_module = "wb_master_uart_tb"

modules = {"local" : ["../"]}

ghdl_opt = "--std=08"

sim_post_cmd = "ghdl -r --std=08 wb_master_uart_tb --wave=wb_master_uart_tb.ghw --assert-level=error"
