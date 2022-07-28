vcom -2008 ../xwb_evt_cnt_tb.vhd
-- make -f Makefile
-- output log file to file "output.log", set simulation resolution to "fs"
vsim -l output.log \
    +vcd \
    -voptargs="+acc" \
    -t 1ns \
    work.xwb_evt_cnt_tb
do wave.do
log -r /*
-- run sim
radix -hexadecimal
run -all
wave zoomfull
radix -hexadecimal
quit
