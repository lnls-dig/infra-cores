onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider TB
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sys_clk
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sys_rstn
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_sta_ctl_rw
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_status_reg_out
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_status_reg_clk_n
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_ctl_oe_n
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_ctl_din_n
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_ctl_str_n
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_status_reg_pl
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_led1_out
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_los
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_txfault
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_detect_n
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_txdisable
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_rs0
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_rs1
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_led1_in
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/sfp_led2_in
add wave -noupdate -divider DUT
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/g_SYS_CLOCK_FREQ
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/g_SERIAL_FREQ
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/c_NUM_TICKS_PER_CLOCK
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/c_SERIAL_DIV
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/clk_sys_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/rst_n_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_sta_ctl_rw_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_status_reg_clk_n_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_status_reg_out_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_status_reg_pl_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_ctl_reg_oe_n_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_ctl_reg_din_n_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_ctl_reg_str_n_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_led1_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_los_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_txfault_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_detect_n_o
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_txdisable_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_rs0_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_rs1_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_led1_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_led2_i
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/serial_tick
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/serial_divider
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/seq_count
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_reg_to_device
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/sfp_reg_from_device
add wave -noupdate /rtm8sfp_ohwr_serial_regs_tb/dut/state
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {851585 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {800640 ns} {1063140 ns}
