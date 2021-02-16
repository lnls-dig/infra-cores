action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "rtm8sfp_ohwr_serial_regs_tb"

files = [
    "../../modules/generic/rtm8sfp_ohwr/rtm8sfp_ohwr_serial_regs.vhd",
    "clk_rst.v",
    "rtm8sfp_ohwr_serial_regs_tb.v"
]
