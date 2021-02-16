------------------------------------------------------------------------------
-- Title      : FMC 4 SFP Board Controller
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2020-12-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: FMC 4SFP CAEN board controller.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2020-12-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fmc4sfp_caen is
port (
  ---------------------------------------------------------------------------
  -- FMC board pins
  ---------------------------------------------------------------------------
  sfp_rx_p_i                                 : in    std_logic_vector(3 downto 0);
  sfp_rx_n_i                                 : in    std_logic_vector(3 downto 0);
  sfp_tx_p_o                                 : out   std_logic_vector(3 downto 0);
  sfp_tx_n_o                                 : out   std_logic_vector(3 downto 0);
  sfp_scl_b                                  : inout std_logic_vector(3 downto 0);
  sfp_sda_b                                  : inout std_logic_vector(3 downto 0);
  sfp_mod_abs_i                              : in    std_logic_vector(3 downto 0);
  sfp_rx_los_i                               : in    std_logic_vector(3 downto 0);
  sfp_tx_disable_o                           : out   std_logic_vector(3 downto 0);
  sfp_tx_fault_i                             : in    std_logic_vector(3 downto 0);
  sfp_rs0_o                                  : out   std_logic_vector(3 downto 0);
  sfp_rs1_o                                  : out   std_logic_vector(3 downto 0);

  si570_clk_p_i                              : in    std_logic;
  si570_clk_n_i                              : in    std_logic;
  si570_scl_b                                : inout std_logic;
  si570_sda_b                                : inout std_logic;

  ---------------------------------------------------------------------------
  -- FPGA side. Just a bypass for now
  ---------------------------------------------------------------------------
  fpga_sfp_rx_p_o                            : out    std_logic_vector(3 downto 0);
  fpga_sfp_rx_n_o                            : out    std_logic_vector(3 downto 0);
  fpga_sfp_tx_p_i                            : in     std_logic_vector(3 downto 0);
  fpga_sfp_tx_n_i                            : in     std_logic_vector(3 downto 0);
  fpga_sfp_mod_abs_o                         : out    std_logic_vector(3 downto 0);
  fpga_sfp_rx_los_o                          : out    std_logic_vector(3 downto 0);
  fpga_sfp_tx_disable_i                      : in     std_logic_vector(3 downto 0);
  fpga_sfp_tx_fault_o                        : out    std_logic_vector(3 downto 0);
  fpga_sfp_rs0_i                             : in     std_logic_vector(3 downto 0);
  fpga_sfp_rs1_i                             : in     std_logic_vector(3 downto 0);

  fpga_si570_clk_p_o                         : out    std_logic;
  fpga_si570_clk_n_o                         : out    std_logic
);
end fmc4sfp_caen;

architecture rtl of fmc4sfp_caen is

begin

  -- Simple bypass for now
  fpga_sfp_rx_p_o     <= sfp_rx_p_i;
  fpga_sfp_rx_n_o     <= sfp_rx_n_i;
  sfp_tx_p_o          <= fpga_sfp_tx_p_i;
  sfp_tx_n_o          <= fpga_sfp_tx_n_i;
  fpga_sfp_mod_abs_o  <= sfp_mod_abs_i;
  fpga_sfp_rx_los_o   <= sfp_rx_los_i;
  sfp_tx_disable_o    <= fpga_sfp_tx_disable_i ;
  fpga_sfp_tx_fault_o <= sfp_tx_fault_i;
  sfp_rs0_o           <= fpga_sfp_rs0_i;
  sfp_rs1_o           <= fpga_sfp_rs1_i;

  fpga_si570_clk_p_o  <= si570_clk_p_i;
  fpga_si570_clk_n_o  <= si570_clk_n_i;

  sfp_scl_b           <= (others => 'Z');
  sfp_sda_b           <= (others => 'Z');
  si570_scl_b         <= 'Z';
  si570_sda_b         <= 'Z';

end rtl;
