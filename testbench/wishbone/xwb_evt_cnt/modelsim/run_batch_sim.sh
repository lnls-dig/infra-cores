#!/bin/sh

set -euo pipefail

# Run simulation
hdlmake makefile
make
vsim -c -do run.do
wlf2vcd -o xwb_evt_cnt_tb.vcd vsim.wlf
