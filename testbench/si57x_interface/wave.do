onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider TB
add wave -noupdate /si57x_interface_tb/sys_clk
add wave -noupdate /si57x_interface_tb/sys_rstn
add wave -noupdate /si57x_interface_tb/ext_wr
add wave -noupdate /si57x_interface_tb/ext_rfreq_value
add wave -noupdate /si57x_interface_tb/ext_n1_value
add wave -noupdate /si57x_interface_tb/ext_hs_value
add wave -noupdate /si57x_interface_tb/scl_pad_oen
add wave -noupdate /si57x_interface_tb/sda_pad_oen
add wave -noupdate /si57x_interface_tb/si57x_oe_in
add wave -noupdate /si57x_interface_tb/si57x_addr
add wave -noupdate /si57x_interface_tb/si57x_oe_out
add wave -noupdate -divider DUT
add wave -noupdate /si57x_interface_tb/dut/g_SYS_CLOCK_FREQ
add wave -noupdate /si57x_interface_tb/dut/g_I2C_FREQ
add wave -noupdate /si57x_interface_tb/dut/g_INIT_OSC
add wave -noupdate /si57x_interface_tb/dut/g_INIT_RFREQ_VALUE
add wave -noupdate /si57x_interface_tb/dut/g_INIT_N1_VALUE
add wave -noupdate /si57x_interface_tb/dut/g_INIT_HS_VALUE
add wave -noupdate /si57x_interface_tb/dut/clk_sys_i
add wave -noupdate /si57x_interface_tb/dut/rst_n_i
add wave -noupdate /si57x_interface_tb/dut/ext_wr_i
add wave -noupdate /si57x_interface_tb/dut/ext_rfreq_value_i
add wave -noupdate /si57x_interface_tb/dut/ext_n1_value_i
add wave -noupdate /si57x_interface_tb/dut/ext_hs_value_i
add wave -noupdate /si57x_interface_tb/dut/scl_pad_oen_o
add wave -noupdate /si57x_interface_tb/dut/sda_pad_oen_o
add wave -noupdate /si57x_interface_tb/dut/si57x_oe_i
add wave -noupdate /si57x_interface_tb/dut/si57x_addr_i
add wave -noupdate /si57x_interface_tb/dut/si57x_oe_o
add wave -noupdate /si57x_interface_tb/dut/rfreq
add wave -noupdate /si57x_interface_tb/dut/n1
add wave -noupdate /si57x_interface_tb/dut/hs
add wave -noupdate /si57x_interface_tb/dut/ext_new_p
add wave -noupdate /si57x_interface_tb/dut/init_new_p
add wave -noupdate /si57x_interface_tb/dut/i2c_tick
add wave -noupdate /si57x_interface_tb/dut/i2c_divider
add wave -noupdate /si57x_interface_tb/dut/scl_out_fsm
add wave -noupdate /si57x_interface_tb/dut/sda_out_fsm
add wave -noupdate /si57x_interface_tb/dut/seq_count
add wave -noupdate /si57x_interface_tb/dut/state
add wave -noupdate /si57x_interface_tb/dut/c_I2C_DIV
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 fs} 0}
quietly wave cursor active 0
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
WaveRestoreZoom {0 fs} {262500 ns}
