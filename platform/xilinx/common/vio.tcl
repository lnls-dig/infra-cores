proc create_vio_ip {ip_name input_width output_width} {
    create_ip -name vio -vendor xilinx.com -library ip -module_name $ip_name

    set_property -dict [list CONFIG.C_NUM_PROBE_IN {2} \
        CONFIG.C_NUM_PROBE_OUT {2} \
        CONFIG.C_PROBE_OUT0_WIDTH $output_width \
        CONFIG.C_PROBE_OUT1_WIDTH $output_width \
        CONFIG.C_PROBE_IN0_WIDTH $input_width \
        CONFIG.C_PROBE_IN1_WIDTH $input_width \
	] [get_ips $ip_name]
}

create_vio_ip vio_din2_w64_dout2_w64 64 64
create_vio_ip vio_din2_w128_dout2_w128 128 128
