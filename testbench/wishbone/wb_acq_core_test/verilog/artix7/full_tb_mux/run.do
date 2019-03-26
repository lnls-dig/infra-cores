vlog glbl.v +incdir+"."
vlog wb_acq_core_tb.v +incdir+"." +incdir+../../../../../../sim +incdir+../../../../../../sim/regs
-- make -f Makefile
-- output log file to file "output.log", set siulation resolution to "fs"
vsim -l output.log -voptargs="+acc" -t fs +notimingchecks -L unifast_ver -L unisims_ver -L unimacro_ver -L secureip -L xil_defaultlib -L fifo_generator_v13_2_3 \
-L axi_interconnect_v1_7_11 -L lib_pkg_v1_0_2 -L lib_fifo_v1_0_12 -L lib_srl_fifo_v1_0_2 -L lib_cdc_v1_0_2 -L axi_datamover_v5_1_20 \
-L unisims_ver -L unisim -L secureip work.wb_acq_core_tb work.glbl
do wave.do
log -r /*
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
radix -hexadecimal
-- run 250us
run 5000us
wave zoomfull
radix -hexadecimal
quit -sim
