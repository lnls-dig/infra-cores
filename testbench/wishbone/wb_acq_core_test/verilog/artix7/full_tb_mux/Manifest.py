action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "wb_acq_core_tb"
sim_top = "wb_acq_core_tb"

modules = {"local" : [
                    "../../../../../../modules/wishbone",
                    "../../../../../../modules/common",
                    "../../../../../../modules/generic",
                    "../../../../../../ip_cores/general-cores",
                    "../../../../../../platform",
                    "../../../../../../sim/ddr_model",
                    "../../../../../../platform"]}

files = ["wb_acq_core_tb.v", "axi_interconnect_wrapper.vhd", "ddr_core_wrapper.vhd",
			"clk_rst.v", "../../../../../../sim/wishbone_test_master.v",
            "glbl.v"]

include_dirs = ["../../../../../../sim", "../../../../../../sim/regs", "../../../../../../sim/ddr_model/artix7",
            "../../../../../../platform/artix7/ip_cores/axis_mux_2_to_1/hdl/verilog", "."]

vlog_opt = "+incdir+../../../../../../sim/regs +incdir+../../../../../../sim +incdir+../../../../../../sim/ddr_model/artix7 +incdir+../../../../../../platform/artix7/ip_cores/axis_mux_2_to_1/hdl/verilog +incdir+."
