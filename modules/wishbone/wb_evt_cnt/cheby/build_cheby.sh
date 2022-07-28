#!/bin/bash

cheby -i evt_cnt_regs.cheby --hdl vhdl --gen-hdl wb_evt_cnt_regs.vhd --doc html --gen-doc doc/wb_evt_cnt_regs_wb.html --gen-c wb_evt_cnt_regs.h --consts-style verilog --gen-consts ../../../../sim/regs/wb_evt_cnt_regs.vh --consts-style vhdl-ohwr --gen-consts ../../../../sim/regs/wb_evt_cnt_reg_consts.vhd
