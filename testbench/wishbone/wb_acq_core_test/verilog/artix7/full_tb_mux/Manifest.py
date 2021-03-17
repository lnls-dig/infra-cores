action = "simulation"
target = "xilinx"
syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "wb_acq_core_tb"
sim_top = "wb_acq_core_tb"

modules = {"local" : [
                    "../../../../../../modules/wishbone/wb_stream",
                    "../../../../../../modules/wishbone/wb_trigger_iface",
                    "../../../../../../modules/wishbone/wb_trigger_mux",
                    "../../../../../../modules/wishbone/wb_trigger",
                    "../../../../../../modules/wishbone/wb_afc_diag",
                    "../../../../../../modules/wishbone/wb_acq_core",
                    "../../../../../../modules/wishbone/wb_acq_core_mux",
                    "../../../../../../modules/wishbone/wb_facq_core",
                    "../../../../../../modules/wishbone/wb_facq_core_mux",
                    "../../../../../../modules/wishbone/wb_pcie_cntr",
                    "../../../../../../modules/common",
                    "../../../../../../modules/generic",
                    "../../../../../../ip_cores/general-cores",
                    "../../../../../../sim/ddr_model",
                    "../../../../../../platform/xilinx/common",
                    "../../../../../../platform/xilinx/artix7/afc_v3/ddr_core",
                    "../../../../../../platform/xilinx/artix7/afc_v3/pcie_core"]}

files = ["wb_acq_core_tb.v", "axi_interconnect_wrapper.vhd", "ddr_core_wrapper.vhd",
            "acq_core_wrapper.vhd", "clk_rst.v", "../../../../../../sim/wishbone_test_master.v",
            "glbl.v", "../../../../../../modules/wishbone/ifc_wishbone_pkg.vhd",
            "../../../../../../platform/xilinx/artix7/afc_v3/ipcores_pkg.vhd",
         ]

include_dirs = ["../../../../../../sim", "../../../../../../sim/regs", "../../../../../../sim/ddr_model/artix7",
            ".", "../../../../../../ip_cores/general-cores/modules/wishbone/wb_lm32/src",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_lm32/platform/generic",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_spi_bidir",
                "../../../../../../modules/wishbone/wb_ethmac",
                "../../../../../../ip_cores/general-cores/modules/wishbone/wb_spi"]

vlog_opt = "+incdir+../../../../../../sim/regs +incdir+../../../../../../sim +incdir+../../../../../../sim/ddr_model/artix7  +incdir+."
