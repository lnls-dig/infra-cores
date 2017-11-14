onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /delay_gen_dyn_tb/c_delay_cnt_initial
add wave -noupdate /delay_gen_dyn_tb/c_delay_cnt_width
add wave -noupdate /delay_gen_dyn_tb/clk
add wave -noupdate /delay_gen_dyn_tb/delay_cnt
add wave -noupdate /delay_gen_dyn_tb/pulse
add wave -noupdate /delay_gen_dyn_tb/rst_n
add wave -noupdate -divider DUT
add wave -noupdate /delay_gen_dyn_tb/DUT/clk_i
add wave -noupdate /delay_gen_dyn_tb/DUT/delay_cnt_i
add wave -noupdate /delay_gen_dyn_tb/DUT/g_delay_cnt_width
add wave -noupdate /delay_gen_dyn_tb/DUT/pulse_i
add wave -noupdate /delay_gen_dyn_tb/DUT/rst_n_i
add wave -noupdate /delay_gen_dyn_tb/DUT/pulse_o
add wave -noupdate /delay_gen_dyn_tb/DUT/rdy_o
add wave -noupdate /delay_gen_dyn_tb/DUT/delay_cnt
add wave -noupdate /delay_gen_dyn_tb/DUT/delay_cnt_max
add wave -noupdate /delay_gen_dyn_tb/DUT/delay_fsm_current_state
add wave -noupdate /delay_gen_dyn_tb/DUT/pulse
add wave -noupdate /delay_gen_dyn_tb/DUT/rdy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
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
WaveRestoreZoom {4973269 ps} {4994245 ps}
