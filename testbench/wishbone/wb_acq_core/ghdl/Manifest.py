action = "simulation"
sim_tool = "ghdl"
top_module = "wb_acq_core_tb"
target = "xilinx"
syn_device = "xc7a200t"

modules = {"local" : ["../"]}
sim_pre_cmd = "cargo build --release --manifest-path ../../../../sim/wishbone_tcp_server/tcp_server/Cargo.toml"

ghdl_opt = "--std=08 -g -frelaxed -fsynopsys -Wl,../../../../sim/wishbone_tcp_server/tcp_server/target/release/libtcp_server.a -Wl,-lpthread"

sim_post_cmd = "ghdl -r --std=08 wb_acq_core_tb --wave=wb_acq_core_tb.ghw --assert-level=error --max-stack-alloc=512"
