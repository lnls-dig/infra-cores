vlog si57x_interface_tb.v \
    +incdir+"."
-- output log file to file "output.log", set simulation resolution to "ns"
vsim -l output.log \
    -voptargs="+acc" \
    -t ns \
    +notimingchecks \
    -L unifast_ver \
    -L unisims_ver \
    -L unimacro_ver \
    work.si57x_interface_tb

do wave.do
log -r /*

set StdArithNoWarnings 1
set NumericStdNoWarnings 1
radix -hexadecimal

run -all
wave zoomfull
radix -hexadecimal
