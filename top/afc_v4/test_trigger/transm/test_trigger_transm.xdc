#######################################################################
##                           Clocks  	                             ##
#######################################################################

create_clock -period 8.000 -name sys_clk_p_i [get_ports sys_clk_p_i]


# From clock OSC3 125MHz. Fixed
# FPGA_CLK1_P
set_property IOSTANDARD DIFF_SSTL15     [get_ports sys_clk_p_i]
set_property IN_TERM UNTUNED_SPLIT_50   [get_ports sys_clk_p_i]
# FPGA_CLK1_N
set_property PACKAGE_PIN AL7            [get_ports sys_clk_n_i]
set_property IOSTANDARD DIFF_SSTL15     [get_ports sys_clk_n_i]
set_property IN_TERM UNTUNED_SPLIT_50   [get_ports sys_clk_n_i]

#######################################################################
##                           Trigger	                             ##
#######################################################################

# FPGA MLVDS_O_8_C: To MLVDS_O_8. Drives Rx17_P/N, Backplane trigger channel 0
set_property PACKAGE_PIN AN8      [get_ports {trig_o[0]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[0]}]

# FPGA MLVDS_O_7_C: To MLVDS_O_7. Drives Tx17_P/N, Backplane trigger channel 1
set_property PACKAGE_PIN AP9      [get_ports {trig_o[1]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[1]}]

# FPGA MLVDS_O_6_C: To MLVDS_O_6. Drives Rx18_P/N, Backplane trigger channel 2
set_property PACKAGE_PIN AN9      [get_ports {trig_o[2]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[2]}]

# FPGA MLVDS_O_5_C: To MLVDS_O_5. Drives Tx18_P/N, Backplane trigger channel 3
set_property PACKAGE_PIN AP10     [get_ports {trig_o[3]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[3]}]

# FPGA MLVDS_O_4_C: To MLVDS_O_4. Drives Rx19_P/N, Backplane trigger channel 4
set_property PACKAGE_PIN AM9      [get_ports {trig_o[4]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[4]}]

# FPGA MLVDS_O_3_C: To MLVDS_O_3. Drives Tx19_P/N, Backplane trigger channel 5
set_property PACKAGE_PIN AP11     [get_ports {trig_o[5]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[5]}]

# FPGA MLVDS_O_2_C: To MLVDS_O_2. Drives Rx20_P/N, Backplane trigger channel 6
set_property PACKAGE_PIN AN11     [get_ports {trig_o[6]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[6]}]

# FPGA MLVDS_O_1_C: To MLVDS_O_1. Drives Rx20_P/N, Backplane trigger channel 7
set_property PACKAGE_PIN AM10     [get_ports {trig_o[7]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_o[7]}]

# FPGA MLVDS_I_8_C: From MLVDS_I_8. Receives Rx17_P/N, Backplane trigger channel 0
set_property PACKAGE_PIN AL9      [get_ports {trig_i[0]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[0]}]

# FPGA MLVDS_I_7_C: From MLVDS_I_7. Receives Tx17_P/N, Backplane trigger channel 1
set_property PACKAGE_PIN AL8      [get_ports {trig_i[1]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[1]}]

# FPGA MLVDS_I_6_C: From MLVDS_I_6. Receives Rx18_P/N, Backplane trigger channel 2
set_property PACKAGE_PIN AP8      [get_ports {trig_i[2]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[2]}]

# FPGA MLVDS_I_5_C: From MLVDS_I_5. Receives Tx18_P/N, Backplane trigger channel 3
set_property PACKAGE_PIN AM11     [get_ports {trig_i[3]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[3]}]

# FPGA MLVDS_I_4_C: From MLVDS_I_4. Receives Rx19_P/N, Backplane trigger channel 4
set_property PACKAGE_PIN AL10     [get_ports {trig_i[4]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[4]}]

# FPGA MLVDS_I_3_C: From MLVDS_I_3. Receives Tx19_P/N, Backplane trigger channel 5
set_property PACKAGE_PIN AK11     [get_ports {trig_i[5]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[5]}]

# FPGA MLVDS_I_2_C: From MLVDS_I_2. Receives Rx20_P/N, Backplane trigger channel 6
set_property PACKAGE_PIN AJ11     [get_ports {trig_i[6]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[6]}]

# FPGA MLVDS_I_1_C: From MLVDS_I_1. Receives Rx20_P/N, Backplane trigger channel 7
set_property PACKAGE_PIN AJ10     [get_ports {trig_i[7]}]
set_property IOSTANDARD LVCMOS15  [get_ports {trig_i[7]}]

# FPGA MLVDS_DE_8_C: To MLVDS_DE_8. Controls DIR Rx17_P/N, Backplane trigger channel 0
set_property PACKAGE_PIN L7       [get_ports {trig_dir_o[0]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[0]}]

# FPGA MLVDS_DE_7_C: To MLVDS_DE_7. Controls DIR Tx17_P/N, Backplane trigger channel 1
set_property PACKAGE_PIN J8       [get_ports {trig_dir_o[1]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[1]}]

# FPGA MLVDS_DE_6_C: To MLVDS_DE_6. Controls DIR Rx18_P/N, Backplane trigger channel 2
set_property PACKAGE_PIN J9       [get_ports {trig_dir_o[2]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[2]}]

# FPGA MLVDS_DE_5_C: To MLVDS_DE_5. Controls DIR Tx18_P/N, Backplane trigger channel 3
set_property PACKAGE_PIN K10      [get_ports {trig_dir_o[3]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[3]}]

# FPGA MLVDS_DE_4_C: To MLVDS_DE_4. Controls DIR Rx19_P/N, Backplane trigger channel 4
set_property PACKAGE_PIN H7       [get_ports {trig_dir_o[4]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[4]}]

# FPGA MLVDS_DE_3_C: To MLVDS_DE_3. Controls DIR Tx19_P/N, Backplane trigger channel 5
set_property PACKAGE_PIN K12      [get_ports {trig_dir_o[5]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[5]}]

# FPGA MLVDS_DE_2_C: To MLVDS_DE_2. Controls DIR Rx20_P/N, Backplane trigger channel 6
set_property PACKAGE_PIN L12      [get_ports {trig_dir_o[6]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[6]}]

# FPGA MLVDS_DE_1_C: To MLVDS_DE_1. Controls DIR Tx20_P/N, Backplane trigger channel 7
set_property PACKAGE_PIN H12      [get_ports {trig_dir_o[7]}]
set_property IOSTANDARD LVCMOS25  [get_ports {trig_dir_o[7]}]
