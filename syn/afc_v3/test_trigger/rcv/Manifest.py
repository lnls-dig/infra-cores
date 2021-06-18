target = "xilinx"
action = "synthesis"

language = "vhdl"

# Allow the user to override fetchto using:
#  hdlmake -p "fetchto='xxx'"
if locals().get('fetchto', None) is None:
    fetchto = "../../ip_cores"

syn_device = "xc7a200t"
syn_grade = "-1"
syn_package = "ffg1156"
syn_top = "test_trigger_rcv"
syn_project = "test_trigger_rcv"
syn_tool = "vivado"


modules = { "local" : [ "../../../../top/afc_v3/test_trigger/rcv" ] }
