#!/bin/bash

wbgen2 -V afc_mgmt_regs.vhd -H record -p afc_mgmt_regs_pkg.vhd -K ../../../../sim/regs/afc_mgmt_regs.vh -s defines -C afc_mgmt_regs.h -f html -D doc/afc_mgmt_regs_wb.html afc_mgmt_regs.wb
