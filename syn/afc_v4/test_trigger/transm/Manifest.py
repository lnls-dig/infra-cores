target = "xilinx"
action = "synthesis"

syn_device = "xc7a200t"
syn_grade = "-2"
syn_package = "ffg1156"
syn_top = "test_trigger_transm"
syn_project = "test_trigger_transm"
syn_tool = "vivado"

board = "afcv4"

modules = { "local" : [ "../../../../top/afc_v4/test_trigger/transm" ] }
