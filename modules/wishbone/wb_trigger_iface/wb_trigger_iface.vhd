------------------------------------------------------------------------
-- Title      : Wishbone Trigger Interface
-- Project    :
-------------------------------------------------------------------------------
-- File       : wb_trigger_iface.vhd
-- Author     : Vitor Finotti Ferreira  <vfinotti@finotti-Inspiron-7520>
-- Company    : Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-- Created    : 2016-01-22
-- Last update: 2016-05-10
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top module for the Wishbone Trigger AFC board interface
-------------------------------------------------------------------------------
-- Copyright (c) 2016 Brazilian Synchrotron Light Laboratory, LNLS/CNPEM

-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public License
-- as published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this program. If not, see
-- <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2016-01-22  1.0      vfinotti        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- Custom Wishbone Modules
use work.ifc_wishbone_pkg.all;
-- Wishbone Register Interface
use work.wb_trig_iface_wbgen2_pkg.all;
-- Reset Synch
use work.ifc_common_pkg.all;
-- f_log2_size
use work.genram_pkg.all;
-- General common cores
use work.gencores_pkg.all;
-- Trigger definitions
use work.trigger_common_pkg.all;

-- For Xilinx primitives
library unisim;
use unisim.vcomponents.all;

entity wb_trigger_iface is
  generic (
    g_interface_mode       : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity  : t_wishbone_address_granularity := WORD;
    g_sync_edge            : string                         := "positive";
    g_trig_num             : natural range 1 to 24          := 8 -- channels facing outside the FPGA. Limit defined by wb_slave_trigger.vhd
    );

  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    ref_clk_i   : in std_logic;
    ref_rst_n_i : in std_logic;

    -------------------------------
    ---- Wishbone Control Interface signals
    -------------------------------

    wb_adr_i   : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := (others => '0');
    wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0)  := (others => '0');
    wb_we_i    : in  std_logic                                             := '0';
    wb_cyc_i   : in  std_logic                                             := '0';
    wb_stb_i   : in  std_logic                                             := '0';
    wb_ack_o   : out std_logic;
    wb_err_o   : out std_logic;
    wb_rty_o   : out std_logic;
    wb_stall_o : out std_logic;

    -------------------------------
    ---- External ports
    -------------------------------

    trig_b      : inout std_logic_vector(g_trig_num-1 downto 0);
    trig_dir_o  : out   std_logic_vector(g_trig_num-1 downto 0);

    -------------------------------
    ---- Internal ports
    -------------------------------

    trig_out_o : out t_trig_channel_array(g_trig_num-1 downto 0);
    trig_in_i  : in  t_trig_channel_array(g_trig_num-1 downto 0);

    -------------------------------
    ---- Debug ports
    -------------------------------
    trig_dbg_o             : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_sync_o        : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_degliteched_o : out std_logic_vector(g_trig_num-1 downto 0)
    );

end entity wb_trigger_iface;

architecture rtl of wb_trigger_iface is


  --------------------------
  --Component Declarations--
  --------------------------

  component wb_trigger_iface_regs is
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(6 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    fs_clk_i                                 : in     std_logic;
    wb_clk_i                                 : in     std_logic;
    regs_i                                   : in     t_wb_trig_iface_in_registers;
    regs_o                                   : out    t_wb_trig_iface_out_registers
  );
  end component wb_trigger_iface_regs;

  constant c_periph_addr_size : natural := 7+2;

  constant c_rcv_pulse_len      : positive := 8;  -- Defined according to the wb_slave_trigger.vhd
  constant c_transm_pulse_len   : positive := 8;  -- Defined according to the wb_slave_trigger.vhd
  constant c_counter_width      : positive := 16; -- Defined according to the wb_slave_trigger.vhd

  constant c_max_num_channels   : natural := 24;

  -- Trigger direction constants
  constant c_trig_dir_fpga_input  : std_logic := '1';
  constant c_trig_dir_fpga_output : std_logic := not (c_trig_dir_fpga_input);

  -----------
  --Signals--
  -----------

  signal regs_in  : t_wb_trig_iface_in_registers;
  signal regs_out : t_wb_trig_iface_out_registers;

  type t_wb_trig_out_channel is record
    ch_ctl_dir                : std_logic;
    ch_ctl_dir_pol            : std_logic;
    ch_ctl_rcv_count_rst_n    : std_logic;
    ch_ctl_transm_count_rst_n : std_logic;
    ch_cfg_rcv_len            : std_logic_vector(c_rcv_pulse_len-1 downto 0);
    ch_cfg_transm_len         : std_logic_vector(c_transm_pulse_len-1 downto 0);
  end record;

  type t_wb_trig_out_array is array(natural range <>) of t_wb_trig_out_channel;

  type t_wb_trig_in_channel is record
    ch_count_rcv    : std_logic_vector(15 downto 0);
    ch_count_transm : std_logic_vector(15 downto 0);
  end record;

  type t_wb_trig_in_array is array(natural range <>) of t_wb_trig_in_channel;

  signal ch_regs_out : t_wb_trig_out_array(c_max_num_channels-1 downto 0);
  signal ch_regs_in  : t_wb_trig_in_array(c_max_num_channels-1 downto 0);

  signal extended_rcv      : std_logic_vector(g_trig_num-1 downto 0);
  signal extended_rcv_buff : std_logic_vector(g_trig_num-1 downto 0);
  signal extended_transm   : std_logic_vector(g_trig_num-1 downto 0);

  signal rcv_pulse_bus    : t_trig_channel_array(g_trig_num-1 downto 0);  -- rcv pulses
  signal transm_pulse_bus : t_trig_channel_array(g_trig_num-1 downto 0);    -- transm pulses

  signal trig_dir_int           : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_pol_int           : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_data_int          : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_dir_polarized     : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_data_polarized    : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_dir_ext           : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_data_ext          : std_logic_vector(g_trig_num-1 downto 0);
  signal trig_dir_int_buff      : std_logic_vector(g_trig_num-1 downto 0);
-- signal trig_data_int_buff     : std_logic_vector(g_trig_num-1 downto 0);

--  signal transm_mux_bus : std_logic_vector(g_intern_num-1 downto 0);  -- input of transm multiplexers
--  signal rcv_mux_out    : std_logic_vector(g_intern_num-1 downto 0);

  -----------------------------
  -- Wishbone slave adapter signals/structures
  -----------------------------
  signal wb_slv_adp_out : t_wishbone_master_out;
  signal wb_slv_adp_in  : t_wishbone_master_in;
  signal resized_addr   : std_logic_vector(c_wishbone_address_width-1 downto 0);

begin  -- architecture rtl

  -- Test for maximum number of interfaces defined in wb_slave_trigger.vhd
  assert (g_trig_num <= 24) -- number of wb_slave_trigger.vhd registers
  report "[wb_trigger_iface] Only g_trig_num less or equal 24 is supported!"
  severity failure;

  -- Test for maximum width of multiplexor selector wb_slave_trigger.vhd
  assert (f_log2_size(g_trig_num) <= 8) -- sel width
  report "[wb_trigger_iface] log2(g_trig_num) must be less than the selector width (8)!"
  severity failure;

  -----------------------------
  -- Slave adapter for Wishbone Register Interface
  -----------------------------
  cmp_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                     => true,
    g_master_mode                           => PIPELINED,
    g_master_granularity                    => WORD,
    g_slave_use_struct                      => false,
    g_slave_mode                            => g_interface_mode,
    g_slave_granularity                     => g_address_granularity
  )
  port map (
    clk_sys_i                               => clk_i,
    rst_n_i                                 => rst_n_i,
    master_i                                => wb_slv_adp_in,
    master_o                                => wb_slv_adp_out,
    sl_adr_i                                => resized_addr,
    sl_dat_i                                => wb_dat_i,
    sl_sel_i                                => wb_sel_i,
    sl_cyc_i                                => wb_cyc_i,
    sl_stb_i                                => wb_stb_i,
    sl_we_i                                 => wb_we_i,
    sl_dat_o                                => wb_dat_o,
    sl_ack_o                                => wb_ack_o,
    sl_rty_o                                => open,
    sl_err_o                                => open,
    sl_int_o                                => open,
    sl_stall_o                              => wb_stall_o
  );

  resized_addr(c_periph_addr_size-1 downto 0) <= wb_adr_i(c_periph_addr_size-1 downto 0);
  resized_addr(c_wishbone_address_width-1 downto c_periph_addr_size) <= (others => '0');


  wb_trigger_iface : wb_trigger_iface_regs
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_i,
      fs_clk_i   => ref_clk_i,
      wb_clk_i   => clk_i,
      wb_adr_i   => wb_slv_adp_out.adr(6 downto 0),
      wb_dat_i   => wb_slv_adp_out.dat,
      wb_dat_o   => wb_slv_adp_in.dat,
      wb_cyc_i   => wb_slv_adp_out.cyc,
      wb_sel_i   => wb_slv_adp_out.sel,
      wb_stb_i   => wb_slv_adp_out.stb,
      wb_we_i    => wb_slv_adp_out.we,
      wb_ack_o   => wb_slv_adp_in.ack,
      wb_stall_o => wb_slv_adp_in.stall,
      regs_i     => regs_in,
      regs_o     => regs_out);

  -----------------------------------------------------------------
  -- Connecting slave ports to signals
  -----------------------------------------------------------------

  ch_regs_out(0).ch_ctl_dir                <= regs_out.ch0_ctl_dir_o;
  ch_regs_out(0).ch_ctl_dir_pol            <= regs_out.ch0_ctl_dir_pol_o;
  ch_regs_out(0).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch0_ctl_rcv_count_rst_o);
  ch_regs_out(0).ch_ctl_transm_count_rst_n <= not(regs_out.ch0_ctl_transm_count_rst_o);
  ch_regs_out(0).ch_cfg_rcv_len            <= regs_out.ch0_cfg_rcv_len_o;
  ch_regs_out(0).ch_cfg_transm_len         <= regs_out.ch0_cfg_transm_len_o;

  ch_regs_out(1).ch_ctl_dir                <= regs_out.ch1_ctl_dir_o;
  ch_regs_out(1).ch_ctl_dir_pol            <= regs_out.ch1_ctl_dir_pol_o;
  ch_regs_out(1).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch1_ctl_rcv_count_rst_o);
  ch_regs_out(1).ch_ctl_transm_count_rst_n <= not(regs_out.ch1_ctl_transm_count_rst_o);
  ch_regs_out(1).ch_cfg_rcv_len            <= regs_out.ch1_cfg_rcv_len_o;
  ch_regs_out(1).ch_cfg_transm_len         <= regs_out.ch1_cfg_transm_len_o;

  ch_regs_out(2).ch_ctl_dir                <= regs_out.ch2_ctl_dir_o;
  ch_regs_out(2).ch_ctl_dir_pol            <= regs_out.ch2_ctl_dir_pol_o;
  ch_regs_out(2).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch2_ctl_rcv_count_rst_o);
  ch_regs_out(2).ch_ctl_transm_count_rst_n <= not(regs_out.ch2_ctl_transm_count_rst_o);
  ch_regs_out(2).ch_cfg_rcv_len            <= regs_out.ch2_cfg_rcv_len_o;
  ch_regs_out(2).ch_cfg_transm_len         <= regs_out.ch2_cfg_transm_len_o;

  ch_regs_out(3).ch_ctl_dir                <= regs_out.ch3_ctl_dir_o;
  ch_regs_out(3).ch_ctl_dir_pol            <= regs_out.ch3_ctl_dir_pol_o;
  ch_regs_out(3).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch3_ctl_rcv_count_rst_o);
  ch_regs_out(3).ch_ctl_transm_count_rst_n <= not(regs_out.ch3_ctl_transm_count_rst_o);
  ch_regs_out(3).ch_cfg_rcv_len            <= regs_out.ch3_cfg_rcv_len_o;
  ch_regs_out(3).ch_cfg_transm_len         <= regs_out.ch3_cfg_transm_len_o;

  ch_regs_out(4).ch_ctl_dir                <= regs_out.ch4_ctl_dir_o;
  ch_regs_out(4).ch_ctl_dir_pol            <= regs_out.ch4_ctl_dir_pol_o;
  ch_regs_out(4).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch4_ctl_rcv_count_rst_o);
  ch_regs_out(4).ch_ctl_transm_count_rst_n <= not(regs_out.ch4_ctl_transm_count_rst_o);
  ch_regs_out(4).ch_cfg_rcv_len            <= regs_out.ch4_cfg_rcv_len_o;
  ch_regs_out(4).ch_cfg_transm_len         <= regs_out.ch4_cfg_transm_len_o;

  ch_regs_out(5).ch_ctl_dir                <= regs_out.ch5_ctl_dir_o;
  ch_regs_out(5).ch_ctl_dir_pol            <= regs_out.ch5_ctl_dir_pol_o;
  ch_regs_out(5).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch5_ctl_rcv_count_rst_o);
  ch_regs_out(5).ch_ctl_transm_count_rst_n <= not(regs_out.ch5_ctl_transm_count_rst_o);
  ch_regs_out(5).ch_cfg_rcv_len            <= regs_out.ch5_cfg_rcv_len_o;
  ch_regs_out(5).ch_cfg_transm_len         <= regs_out.ch5_cfg_transm_len_o;

  ch_regs_out(6).ch_ctl_dir                <= regs_out.ch6_ctl_dir_o;
  ch_regs_out(6).ch_ctl_dir_pol            <= regs_out.ch6_ctl_dir_pol_o;
  ch_regs_out(6).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch6_ctl_rcv_count_rst_o);
  ch_regs_out(6).ch_ctl_transm_count_rst_n <= not(regs_out.ch6_ctl_transm_count_rst_o);
  ch_regs_out(6).ch_cfg_rcv_len            <= regs_out.ch6_cfg_rcv_len_o;
  ch_regs_out(6).ch_cfg_transm_len         <= regs_out.ch6_cfg_transm_len_o;

  ch_regs_out(7).ch_ctl_dir                <= regs_out.ch7_ctl_dir_o;
  ch_regs_out(7).ch_ctl_dir_pol            <= regs_out.ch7_ctl_dir_pol_o;
  ch_regs_out(7).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch7_ctl_rcv_count_rst_o);
  ch_regs_out(7).ch_ctl_transm_count_rst_n <= not(regs_out.ch7_ctl_transm_count_rst_o);
  ch_regs_out(7).ch_cfg_rcv_len            <= regs_out.ch7_cfg_rcv_len_o;
  ch_regs_out(7).ch_cfg_transm_len         <= regs_out.ch7_cfg_transm_len_o;

  ch_regs_out(8).ch_ctl_dir                <= regs_out.ch8_ctl_dir_o;
  ch_regs_out(8).ch_ctl_dir_pol            <= regs_out.ch8_ctl_dir_pol_o;
  ch_regs_out(8).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch8_ctl_rcv_count_rst_o);
  ch_regs_out(8).ch_ctl_transm_count_rst_n <= not(regs_out.ch8_ctl_transm_count_rst_o);
  ch_regs_out(8).ch_cfg_rcv_len            <= regs_out.ch8_cfg_rcv_len_o;
  ch_regs_out(8).ch_cfg_transm_len         <= regs_out.ch8_cfg_transm_len_o;

  ch_regs_out(9).ch_ctl_dir                <= regs_out.ch9_ctl_dir_o;
  ch_regs_out(9).ch_ctl_dir_pol            <= regs_out.ch9_ctl_dir_pol_o;
  ch_regs_out(9).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch9_ctl_rcv_count_rst_o);
  ch_regs_out(9).ch_ctl_transm_count_rst_n <= not(regs_out.ch9_ctl_transm_count_rst_o);
  ch_regs_out(9).ch_cfg_rcv_len            <= regs_out.ch9_cfg_rcv_len_o;
  ch_regs_out(9).ch_cfg_transm_len         <= regs_out.ch9_cfg_transm_len_o;

  ch_regs_out(10).ch_ctl_dir                <= regs_out.ch10_ctl_dir_o;
  ch_regs_out(10).ch_ctl_dir_pol            <= regs_out.ch10_ctl_dir_pol_o;
  ch_regs_out(10).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch10_ctl_rcv_count_rst_o);
  ch_regs_out(10).ch_ctl_transm_count_rst_n <= not(regs_out.ch10_ctl_transm_count_rst_o);
  ch_regs_out(10).ch_cfg_rcv_len            <= regs_out.ch10_cfg_rcv_len_o;
  ch_regs_out(10).ch_cfg_transm_len         <= regs_out.ch10_cfg_transm_len_o;

  ch_regs_out(11).ch_ctl_dir                <= regs_out.ch11_ctl_dir_o;
  ch_regs_out(11).ch_ctl_dir_pol            <= regs_out.ch11_ctl_dir_pol_o;
  ch_regs_out(11).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch11_ctl_rcv_count_rst_o);
  ch_regs_out(11).ch_ctl_transm_count_rst_n <= not(regs_out.ch11_ctl_transm_count_rst_o);
  ch_regs_out(11).ch_cfg_rcv_len            <= regs_out.ch11_cfg_rcv_len_o;
  ch_regs_out(11).ch_cfg_transm_len         <= regs_out.ch11_cfg_transm_len_o;

  ch_regs_out(12).ch_ctl_dir                <= regs_out.ch12_ctl_dir_o;
  ch_regs_out(12).ch_ctl_dir_pol            <= regs_out.ch12_ctl_dir_pol_o;
  ch_regs_out(12).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch12_ctl_rcv_count_rst_o);
  ch_regs_out(12).ch_ctl_transm_count_rst_n <= not(regs_out.ch12_ctl_transm_count_rst_o);
  ch_regs_out(12).ch_cfg_rcv_len            <= regs_out.ch12_cfg_rcv_len_o;
  ch_regs_out(12).ch_cfg_transm_len         <= regs_out.ch12_cfg_transm_len_o;

  ch_regs_out(13).ch_ctl_dir                <= regs_out.ch13_ctl_dir_o;
  ch_regs_out(13).ch_ctl_dir_pol            <= regs_out.ch13_ctl_dir_pol_o;
  ch_regs_out(13).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch13_ctl_rcv_count_rst_o);
  ch_regs_out(13).ch_ctl_transm_count_rst_n <= not(regs_out.ch13_ctl_transm_count_rst_o);
  ch_regs_out(13).ch_cfg_rcv_len            <= regs_out.ch13_cfg_rcv_len_o;
  ch_regs_out(13).ch_cfg_transm_len         <= regs_out.ch13_cfg_transm_len_o;

  ch_regs_out(14).ch_ctl_dir                <= regs_out.ch14_ctl_dir_o;
  ch_regs_out(14).ch_ctl_dir_pol            <= regs_out.ch14_ctl_dir_pol_o;
  ch_regs_out(14).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch14_ctl_rcv_count_rst_o);
  ch_regs_out(14).ch_ctl_transm_count_rst_n <= not(regs_out.ch14_ctl_transm_count_rst_o);
  ch_regs_out(14).ch_cfg_rcv_len            <= regs_out.ch14_cfg_rcv_len_o;
  ch_regs_out(14).ch_cfg_transm_len         <= regs_out.ch14_cfg_transm_len_o;

  ch_regs_out(15).ch_ctl_dir                <= regs_out.ch15_ctl_dir_o;
  ch_regs_out(15).ch_ctl_dir_pol            <= regs_out.ch15_ctl_dir_pol_o;
  ch_regs_out(15).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch15_ctl_rcv_count_rst_o);
  ch_regs_out(15).ch_ctl_transm_count_rst_n <= not(regs_out.ch15_ctl_transm_count_rst_o);
  ch_regs_out(15).ch_cfg_rcv_len            <= regs_out.ch15_cfg_rcv_len_o;
  ch_regs_out(15).ch_cfg_transm_len         <= regs_out.ch15_cfg_transm_len_o;

  ch_regs_out(16).ch_ctl_dir                <= regs_out.ch16_ctl_dir_o;
  ch_regs_out(16).ch_ctl_dir_pol            <= regs_out.ch16_ctl_dir_pol_o;
  ch_regs_out(16).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch16_ctl_rcv_count_rst_o);
  ch_regs_out(16).ch_ctl_transm_count_rst_n <= not(regs_out.ch16_ctl_transm_count_rst_o);
  ch_regs_out(16).ch_cfg_rcv_len            <= regs_out.ch16_cfg_rcv_len_o;
  ch_regs_out(16).ch_cfg_transm_len         <= regs_out.ch16_cfg_transm_len_o;

  ch_regs_out(17).ch_ctl_dir                <= regs_out.ch17_ctl_dir_o;
  ch_regs_out(17).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch17_ctl_rcv_count_rst_o);
  ch_regs_out(17).ch_ctl_dir_pol            <= regs_out.ch17_ctl_dir_pol_o;
  ch_regs_out(17).ch_ctl_transm_count_rst_n <= not(regs_out.ch17_ctl_transm_count_rst_o);
  ch_regs_out(17).ch_cfg_rcv_len            <= regs_out.ch17_cfg_rcv_len_o;
  ch_regs_out(17).ch_cfg_transm_len         <= regs_out.ch17_cfg_transm_len_o;

  ch_regs_out(18).ch_ctl_dir                <= regs_out.ch18_ctl_dir_o;
  ch_regs_out(18).ch_ctl_dir_pol            <= regs_out.ch18_ctl_dir_pol_o;
  ch_regs_out(18).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch18_ctl_rcv_count_rst_o);
  ch_regs_out(18).ch_ctl_transm_count_rst_n <= not(regs_out.ch18_ctl_transm_count_rst_o);
  ch_regs_out(18).ch_cfg_rcv_len            <= regs_out.ch18_cfg_rcv_len_o;
  ch_regs_out(18).ch_cfg_transm_len         <= regs_out.ch18_cfg_transm_len_o;

  ch_regs_out(19).ch_ctl_dir                <= regs_out.ch19_ctl_dir_o;
  ch_regs_out(19).ch_ctl_dir_pol            <= regs_out.ch19_ctl_dir_pol_o;
  ch_regs_out(19).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch19_ctl_rcv_count_rst_o);
  ch_regs_out(19).ch_ctl_transm_count_rst_n <= not(regs_out.ch19_ctl_transm_count_rst_o);
  ch_regs_out(19).ch_cfg_rcv_len            <= regs_out.ch19_cfg_rcv_len_o;
  ch_regs_out(19).ch_cfg_transm_len         <= regs_out.ch19_cfg_transm_len_o;

  ch_regs_out(20).ch_ctl_dir                <= regs_out.ch20_ctl_dir_o;
  ch_regs_out(20).ch_ctl_dir_pol            <= regs_out.ch20_ctl_dir_pol_o;
  ch_regs_out(20).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch20_ctl_rcv_count_rst_o);
  ch_regs_out(20).ch_ctl_transm_count_rst_n <= not(regs_out.ch20_ctl_transm_count_rst_o);
  ch_regs_out(20).ch_cfg_rcv_len            <= regs_out.ch20_cfg_rcv_len_o;
  ch_regs_out(20).ch_cfg_transm_len         <= regs_out.ch20_cfg_transm_len_o;

  ch_regs_out(21).ch_ctl_dir                <= regs_out.ch21_ctl_dir_o;
  ch_regs_out(21).ch_ctl_dir_pol            <= regs_out.ch21_ctl_dir_pol_o;
  ch_regs_out(21).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch21_ctl_rcv_count_rst_o);
  ch_regs_out(21).ch_ctl_transm_count_rst_n <= not(regs_out.ch21_ctl_transm_count_rst_o);
  ch_regs_out(21).ch_cfg_rcv_len            <= regs_out.ch21_cfg_rcv_len_o;
  ch_regs_out(21).ch_cfg_transm_len         <= regs_out.ch21_cfg_transm_len_o;

  ch_regs_out(22).ch_ctl_dir                <= regs_out.ch22_ctl_dir_o;
  ch_regs_out(22).ch_ctl_dir_pol            <= regs_out.ch22_ctl_dir_pol_o;
  ch_regs_out(22).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch22_ctl_rcv_count_rst_o);
  ch_regs_out(22).ch_ctl_transm_count_rst_n <= not(regs_out.ch22_ctl_transm_count_rst_o);
  ch_regs_out(22).ch_cfg_rcv_len            <= regs_out.ch22_cfg_rcv_len_o;
  ch_regs_out(22).ch_cfg_transm_len         <= regs_out.ch22_cfg_transm_len_o;

  ch_regs_out(23).ch_ctl_dir                <= regs_out.ch23_ctl_dir_o;
  ch_regs_out(23).ch_ctl_dir_pol            <= regs_out.ch23_ctl_dir_pol_o;
  ch_regs_out(23).ch_ctl_rcv_count_rst_n    <= not(regs_out.ch23_ctl_rcv_count_rst_o);
  ch_regs_out(23).ch_ctl_transm_count_rst_n <= not(regs_out.ch23_ctl_transm_count_rst_o);
  ch_regs_out(23).ch_cfg_rcv_len            <= regs_out.ch23_cfg_rcv_len_o;
  ch_regs_out(23).ch_cfg_transm_len         <= regs_out.ch23_cfg_transm_len_o;



  regs_in.ch0_count_rcv_i    <= ch_regs_in(0).ch_count_rcv;
  regs_in.ch0_count_transm_i <= ch_regs_in(0).ch_count_transm;

  regs_in.ch1_count_rcv_i    <= ch_regs_in(1).ch_count_rcv;
  regs_in.ch1_count_transm_i <= ch_regs_in(1).ch_count_transm;

  regs_in.ch2_count_rcv_i    <= ch_regs_in(2).ch_count_rcv;
  regs_in.ch2_count_transm_i <= ch_regs_in(2).ch_count_transm;

  regs_in.ch3_count_rcv_i    <= ch_regs_in(3).ch_count_rcv;
  regs_in.ch3_count_transm_i <= ch_regs_in(3).ch_count_transm;

  regs_in.ch4_count_rcv_i    <= ch_regs_in(4).ch_count_rcv;
  regs_in.ch4_count_transm_i <= ch_regs_in(4).ch_count_transm;

  regs_in.ch5_count_rcv_i    <= ch_regs_in(5).ch_count_rcv;
  regs_in.ch5_count_transm_i <= ch_regs_in(5).ch_count_transm;

  regs_in.ch6_count_rcv_i    <= ch_regs_in(6).ch_count_rcv;
  regs_in.ch6_count_transm_i <= ch_regs_in(6).ch_count_transm;

  regs_in.ch7_count_rcv_i    <= ch_regs_in(7).ch_count_rcv;
  regs_in.ch7_count_transm_i <= ch_regs_in(7).ch_count_transm;

  regs_in.ch8_count_rcv_i    <= ch_regs_in(8).ch_count_rcv;
  regs_in.ch8_count_transm_i <= ch_regs_in(8).ch_count_transm;

  regs_in.ch9_count_rcv_i    <= ch_regs_in(9).ch_count_rcv;
  regs_in.ch9_count_transm_i <= ch_regs_in(9).ch_count_transm;

  regs_in.ch10_count_rcv_i    <= ch_regs_in(10).ch_count_rcv;
  regs_in.ch10_count_transm_i <= ch_regs_in(10).ch_count_transm;

  regs_in.ch11_count_rcv_i    <= ch_regs_in(11).ch_count_rcv;
  regs_in.ch11_count_transm_i <= ch_regs_in(11).ch_count_transm;

  regs_in.ch12_count_rcv_i    <= ch_regs_in(12).ch_count_rcv;
  regs_in.ch12_count_transm_i <= ch_regs_in(12).ch_count_transm;

  regs_in.ch13_count_rcv_i    <= ch_regs_in(13).ch_count_rcv;
  regs_in.ch13_count_transm_i <= ch_regs_in(13).ch_count_transm;

  regs_in.ch14_count_rcv_i    <= ch_regs_in(14).ch_count_rcv;
  regs_in.ch14_count_transm_i <= ch_regs_in(14).ch_count_transm;

  regs_in.ch15_count_rcv_i    <= ch_regs_in(15).ch_count_rcv;
  regs_in.ch15_count_transm_i <= ch_regs_in(15).ch_count_transm;

  regs_in.ch16_count_rcv_i    <= ch_regs_in(16).ch_count_rcv;
  regs_in.ch16_count_transm_i <= ch_regs_in(16).ch_count_transm;

  regs_in.ch17_count_rcv_i    <= ch_regs_in(17).ch_count_rcv;
  regs_in.ch17_count_transm_i <= ch_regs_in(17).ch_count_transm;

  regs_in.ch18_count_rcv_i    <= ch_regs_in(18).ch_count_rcv;
  regs_in.ch18_count_transm_i <= ch_regs_in(18).ch_count_transm;

  regs_in.ch19_count_rcv_i    <= ch_regs_in(19).ch_count_rcv;
  regs_in.ch19_count_transm_i <= ch_regs_in(19).ch_count_transm;

  regs_in.ch20_count_rcv_i    <= ch_regs_in(20).ch_count_rcv;
  regs_in.ch20_count_transm_i <= ch_regs_in(20).ch_count_transm;

  regs_in.ch21_count_rcv_i    <= ch_regs_in(21).ch_count_rcv;
  regs_in.ch21_count_transm_i <= ch_regs_in(21).ch_count_transm;

  regs_in.ch22_count_rcv_i    <= ch_regs_in(22).ch_count_rcv;
  regs_in.ch22_count_transm_i <= ch_regs_in(22).ch_count_transm;

  regs_in.ch23_count_rcv_i    <= ch_regs_in(23).ch_count_rcv;
  regs_in.ch23_count_transm_i <= ch_regs_in(23).ch_count_transm;

  ---------------------------
  -- Instantiation Process --
  ---------------------------

  transm_pulse_bus <= trig_in_i;

  trigger_generate : for i in g_trig_num-1 downto 0 generate

    --------------------------------
    -- Connecting signals
    --------------------------------

    -- Implementation of wired-OR logic with trigger lines, as described
    -- in www.ti.com/lit/pdf/snla113, page 11. It works as follows:
    --
    -- If we want to output data, we use the direction pin as data and
    -- drive the actual output to HI. This would only drive the line
    -- when we send data.
    --
    -- If we want to input data, we use the pins as usual: data as data and
    -- direction as direction.
    --
    -- Notice that for FPGA output:
    --   Direction pin 0 = Input to FPGA
    --   Direction pin 1 = Output to FPGA
    --
    -- So, we must negate the data pin so, sending 1 will set the FPGA
    -- to output ('0' in iobuf) and sending 0 will set the FPGA to input
    -- ('1' in iobuf)
    trig_dir_int(i)  <= ch_regs_out(i).ch_ctl_dir;
    trig_pol_int(i)  <= ch_regs_out(i).ch_ctl_dir_pol;
    trig_data_int(i) <= not (extended_transm(i));

    -- Regular data/direction driving with polarity inversion
    trig_dir_polarized(i)  <= trig_dir_int(i) when trig_pol_int(i) = '0' else
                               not (trig_dir_int(i));
    trig_data_polarized(i) <= trig_data_int(i) when trig_pol_int(i) = '0' else
                                not (trig_data_int(i));

    -- Use data/direction pin as data depending if we are input or output.
    -- If it's input, we just need to use the direction according to the
    -- polarity ('0' means same polarity, '1' means reversed polarity).
    --
    -- We could have used just "not (trig_dir_int(i))" instead of trig_dir_polarized(i)
    -- here, but we opted for clarity in the hope the tools will optimize this
    trig_dir_ext(i)  <= trig_data_polarized(i) when trig_dir_int(i) = c_trig_dir_fpga_output else
                       trig_dir_polarized(i);
    trig_data_ext(i) <= '1' when trig_dir_int(i) = c_trig_dir_fpga_output else '0';

    -- Internal buffer direction/data
    trig_dir_int_buff(i)  <= trig_data_int(i) when trig_dir_int(i) = c_trig_dir_fpga_output else
                              trig_dir_int(i);
    --trig_data_int_buff(i) <= '1' when trig_dir_int(i) = c_trig_dir_fpga_output else '0';

    -- Trigger direction external output
    trig_dir_o(i) <= trig_dir_ext(i);

    --------------------------------
    -- Transmitter and Receiver Cores
    --------------------------------

    trigger_transm : extend_pulse_dyn
      generic map (
        g_width_bus_size => c_transm_pulse_len)
      port map (
        clk_i         => ref_clk_i,
        rst_n_i       => ref_rst_n_i,
        pulse_i       => transm_pulse_bus(i).pulse,
        pulse_width_i => unsigned(ch_regs_out(i).ch_cfg_transm_len),
        extended_o    => extended_transm(i));

    trigger_rcv_1 : trigger_rcv
      generic map (
        g_glitch_len_width => c_rcv_pulse_len,
        g_sync_edge        => g_sync_edge)
      port map (
        clk_i   => ref_clk_i,
        rst_n_i => ref_rst_n_i,
        len_i   => ch_regs_out(i).ch_cfg_rcv_len,
        data_i  => extended_rcv(i),
        pulse_o => rcv_pulse_bus(i).pulse,
        dbg_data_sync_o        => dbg_data_sync_o(i) ,
        dbg_data_degliteched_o => dbg_data_degliteched_o(i)
        );

    --------------------------------
    -- Connects cores to backplane
    --------------------------------

    cmp_iobuf : iobuf
      port map (
        o  => extended_rcv_buff(i),     -- Buffer output for further use
        io => trig_b(i),                -- inout (connect directly to top-level port)
        i  => trig_data_ext(i),         -- Buffer input
        t  => trig_dir_int_buff(i)      -- 3-state enable input, high=input, low=output
        );

    trig_dbg_o(i) <= extended_rcv_buff(i);
    extended_rcv(i) <= extended_rcv_buff(i) when trig_dir_int(i) = c_trig_dir_fpga_input
                       else '0'; -- FPGA is output

    --------------------------------
    -- Pulse counters
    --------------------------------

    counter_rcv : counter_simple
      generic map (
        g_output_width => c_counter_width)
      port map (
        clk_i   => ref_clk_i,
        rst_n_i => ch_regs_out(i).ch_ctl_rcv_count_rst_n,
        ce_i    => '1',
        up_i    => rcv_pulse_bus(i).pulse,
        down_i  => '0',
        count_o => ch_regs_in(i).ch_count_rcv);

    counter_transm : counter_simple
      generic map (
        g_output_width => c_counter_width)
      port map (
        clk_i   => ref_clk_i,
        rst_n_i => ch_regs_out(i).ch_ctl_transm_count_rst_n,
        ce_i    => '1',
        up_i    => transm_pulse_bus(i).pulse,
        down_i  => '0',
        count_o => ch_regs_in(i).ch_count_transm);

  end generate;

  trig_out_o <=  rcv_pulse_bus;

end architecture rtl;
