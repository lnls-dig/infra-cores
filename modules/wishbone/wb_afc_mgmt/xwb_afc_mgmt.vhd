------------------------------------------------------------------------------
-- Title      : AFC board management module
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2017-08-25
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: AFC module containing AFC specifities, like clocks, I2C muxes, etc
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2017-08-25  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_wishbone_pkg.all;
use work.wishbone_pkg.all;

entity xwb_afc_mgmt is
generic(
  g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
  g_address_granularity                     : t_wishbone_address_granularity := WORD
);
port(
  sys_clk_i                                 : in std_logic;
  sys_rst_n_i                               : in std_logic;

  -----------------------------
  -- Wishbone Control Interface signals
  -----------------------------
  wb_slv_i                                  : in t_wishbone_slave_in;
  wb_slv_o                                  : out t_wishbone_slave_out;

  -----------------------------
  -- External ports
  -----------------------------

  -- Si57x clock gen
  si57x_scl_pad_b                           : inout std_logic;
  si57x_sda_pad_b                           : inout std_logic;
  si57x_oe_o                                : out std_logic
);
end xwb_afc_mgmt;

architecture rtl of xwb_afc_mgmt is

begin

  cmp_wb_afc_mgmt : wb_afc_mgmt
  generic map (
    g_interface_mode                        => g_interface_mode,
    g_address_granularity                   => g_address_granularity
  )
  port map(
    sys_clk_i                               => sys_clk_i,
    sys_rst_n_i                             => sys_rst_n_i,

    -- Wishbone
    wb_adr_i                                => wb_slv_i.adr,
    wb_dat_i                                => wb_slv_i.dat,
    wb_dat_o                                => wb_slv_o.dat,
    wb_sel_i                                => wb_slv_i.sel,
    wb_we_i                                 => wb_slv_i.we,
    wb_cyc_i                                => wb_slv_i.cyc,
    wb_stb_i                                => wb_slv_i.stb,
    wb_ack_o                                => wb_slv_o.ack,
    wb_err_o                                => wb_slv_o.err,
    wb_rty_o                                => wb_slv_o.rty,
    wb_stall_o                              => wb_slv_o.stall,

    si57x_scl_pad_b                         => si57x_scl_pad_b,
    si57x_sda_pad_b                         => si57x_sda_pad_b,
    si57x_oe_o                              => si57x_oe_o
  );

end rtl;
