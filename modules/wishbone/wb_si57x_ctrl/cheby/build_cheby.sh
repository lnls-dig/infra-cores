#!/bin/bash

cheby -i wb_si57x_ctrl_regs.cheby --hdl vhdl --gen-hdl wb_si57x_ctrl_regs.vhd --doc html --gen-doc doc/wb_si57x_ctrl_regs.html --gen-c wb_si57x_ctrl_regs.h --consts-style verilog --gen-consts ../../../../sim/regs/wb_si57x_ctrl_regs.vh --consts-style vhdl-ohwr --gen-consts ../../../../sim/regs/wb_si57x_ctrl_reg_consts.vhd
