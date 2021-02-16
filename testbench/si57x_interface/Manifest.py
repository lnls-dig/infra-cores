action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "si57x_interface_tb"

modules = {
    "local" : [
        "../../modules/generic/si57x_interface",
    ]
}

files = [
    "clk_rst.v",
    "si57x_interface_tb.v"
]
