proc create_ila_ip {ip_name probe_width num_samples} {
    # Create the ILA IP with the given name
    create_ip -name ila -vendor xilinx.com -library ip -module_name $ip_name

    # Set the number of probes to 1
    # Set the probe width
    # Set the buffer depth
    set_property -dict [list CONFIG.C_NUM_OF_PROBES {2} \
        CONFIG.C_PROBE0_WIDTH $probe_width \
        CONFIG.C_PROBE1_WIDTH 8 \
        CONFIG.ALL_PROBE_SAME_MU {TRUE} \
        CONFIG.ALL_PROBE_SAME_MU_CNT {8} \
        CONFIG.C_EN_STRG_QUAL {1} \
        CONFIG.C_DATA_DEPTH $num_samples] [get_ips $ip_name]
}

create_ila_ip ila_t8_d256_s4096_cap 256 4096
create_ila_ip ila_t8_d256_s8192_cap 256 8192
