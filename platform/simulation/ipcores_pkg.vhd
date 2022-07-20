-- Constant definitions for simulation on an unspecified target

package ipcores_pkg is

constant c_pcielanes : positive := 4;
--***************************************************************************
-- Necessary parameters for DDR core support
-- (dependent on memory chip connected to FPGA, not to be modified at will)
--***************************************************************************
constant C_DDR_DQ_WIDTH      : positive := 32;
constant C_DDR_PAYLOAD_WIDTH : positive := 256;
constant C_DDR_DQS_WIDTH     : positive := 4;
constant C_DDR_DM_WIDTH      : positive := 4;
constant C_DDR_ROW_WIDTH     : positive := 16;
constant C_DDR_BANK_WIDTH    : positive := 3;
constant C_DDR_CK_WIDTH      : positive := 1;
constant C_DDR_CKE_WIDTH     : positive := 1;
constant C_DDR_ODT_WIDTH     : positive := 1;
constant C_DDR_ADDR_WIDTH    : positive := 31;

constant C_DDR_TID_WIDTH : positive := 8;
constant C_AXI_SLAVE_TID_WIDTH : positive := 4;
--***************************************************************************
-- Necessary parameters for AXI BPM Data Mover core support
-- (dependent on generated core, not to be modified at will)
--***************************************************************************
constant C_DDR_DATAMOVER_BPM_BURST_SIZE : positive := 4;
end package;
