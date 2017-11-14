vsim -l output.log -t 1ps -L unisim work.delay_gen_dyn_tb -voptargs="+acc"
assertion action -cond fail -exec exit
do wave.do
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
radix -hexadecimal
wave zoomfull
radix -hexadecimal

run 250us
