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
                    "../../../../../../sim/ddr_model",
                    "../../../../../../platform"]}

files = ["wb_acq_core_tb.v", "axi_interconnect_wrapper.vhd", "ddr_core_wrapper.vhd",
			"clk_rst.v", "../../../../../../sim/wishbone_test_master.v",
            "glbl.v"]

include_dirs = ["../../../../../../sim", "../../../../../../sim/regs", "../../../../../../sim/ddr_model/artix7",
            ".", "../../../../../../ip_cores/general-cores/modules/wishbone/wb_lm32/src",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_lm32/platform/generic",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_spi_bidir",
                "../../../../../../modules/wishbone/wb_ethmac",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_spi"]

vlog_opt = "+incdir+../../../../../../sim/regs +incdir+../../../../../../sim +incdir+../../../../../../sim/ddr_model/artix7  +incdir+."
