files = ["ddr_core/user_design/rtl/ddr_core.v",
         "ddr_core/user_design/rtl/axi/",
         "ddr_core/user_design/rtl/clocking/",
         "ddr_core/user_design/rtl/controller/",
         "ddr_core/user_design/rtl/ecc/",
         "ddr_core/user_design/rtl/ip_top/",
         "ddr_core/user_design/rtl/phy/",
         "ddr_core/user_design/rtl/ui/"]

if (action == "synthesis"):
    files.extend(["ddr_core/user_design/rtl/ddr_core_mig.v"])
elif (action == "simulation"):
    files.extend(["ddr_core/user_design/rtl/ddr_core_mig_sim.v"])
else:
    import sys
    sys.exit("ERROR: DDR_CORE: Action not recognized: {}".format(action))
