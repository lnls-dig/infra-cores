-- Title      : Trigger receiver test top
-- Project    :
-------------------------------------------------------------------------------
-- File       : test_trigger_rcv.vhd
-- Author     : aylons  <aylons@LNLS190>
-- Company    :
-- Created    : 2015-11-11
-- Last update: 2016-04-25
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Top design for testing the trigger receiver in the AFCv3.1
-------------------------------------------------------------------------------
-- Copyright (c) 2015

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
-- 2015-11-11  1.0      aylons          Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Custom common cores
use work.ifc_common_pkg.all;
use work.gencores_pkg.all;


library UNISIM;
use UNISIM.vcomponents.all;

entity test_trigger_rcv is
  port(
    sys_clk_p_i : in  std_logic;
    sys_clk_n_i : in  std_logic;
    trigger_i   : in  std_logic_vector(7 downto 0);
    direction_o : out std_logic_vector(7 downto 0);
    pulse_o     : out std_logic_vector(7 downto 0)
    );
end test_trigger_rcv;

architecture structural of test_trigger_rcv is

  constant c_glitch_len_width : positive := 8;
  constant c_count_width      : positive := 128;
  constant c_num_clk          : positive := 1;

  signal direction    : std_logic_vector(7 downto 0);
  signal length       : std_logic_vector(c_glitch_len_width-1 downto 0) := "11111111";
  signal pulse        : std_logic_vector(7 downto 0);

  type count_array is array(7 downto 0) of std_logic_vector(c_count_width-1 downto 0);
  signal count_success, count_fail, count_repeated, count_others : count_array;

  constant filler : std_logic_vector(31 downto 0) := (others => '0');

  component trigger_rcv is
    generic (
      g_glitch_len_width : positive;
      g_sync_edge        : string);
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      len_i   : in  std_logic_vector(g_glitch_len_width-1 downto 0);
      data_i  : in  std_logic;
      pulse_o : out std_logic);
  end component trigger_rcv;

-------------------------------------------------------------------------------
-- Chipscope
-------------------------------------------------------------------------------

  signal CONTROL0, CONTROL1, CONTROL2, CONTROL3 : std_logic_vector(35 downto 0);

  component chipscope_icon_2_port is
    port (
      CONTROL0 : inout std_logic_vector(35 downto 0);
      CONTROL1 : inout std_logic_vector(35 downto 0));
  end component chipscope_icon_2_port;

  component chipscope_ila_rcv is
    port (
      CONTROL : inout std_logic_vector(35 downto 0);
      CLK     : in    std_logic;
      TRIG0   : in    std_logic_vector(127 downto 0);
      TRIG1   : in    std_logic_vector(127 downto 0);
      TRIG2   : in    std_logic_vector(31 downto 0);
      TRIG3   : in    std_logic_vector(31 downto 0);
      TRIG4   : in    std_logic_vector(127 downto 0);
      TRIG5   : in    std_logic_vector(127 downto 0));
  end component chipscope_ila_rcv;

  component chipscope_vio_16 is
    port (
      CONTROL  : inout std_logic_vector(35 downto 0);
      CLK      : in    std_logic;
      SYNC_OUT : out   std_logic_vector(15 downto 0));
  end component chipscope_vio_16;

  -----------------------------------------------------------------------------
  -- Clock and system
  -----------------------------------------------------------------------------

  component clk_gen is
    port (
      sys_clk_p_i    : in  std_logic;
      sys_clk_n_i    : in  std_logic;
      sys_clk_o      : out std_logic;
      sys_clk_bufg_o : out std_logic);
  end component clk_gen;

  component sys_pll is
    generic (
      g_clkin_period   : real;
      g_divclk_divide  : integer;
      g_clkbout_mult_f : integer;
      g_clk0_divide_f  : integer;
      g_clk1_divide    : integer);
    port (
      rst_i    : in  std_logic := '0';
      clk_i    : in  std_logic := '0';
      clk0_o   : out std_logic;
      clk1_o   : out std_logic;
      locked_o : out std_logic);
  end component sys_pll;

  -- Global Clock Single ended
  signal clk_100mhz, clk_200mhz : std_logic;
  signal sys_clk_gen_bufg       : std_logic;
  signal locked                 : std_logic;
  signal rst_n                  : std_logic;
  signal rst_n_v                : std_logic_vector(c_num_clk-1 downto 0);
  signal reset_clks             : std_logic_vector(c_num_clk-1 downto 0);

  -----------------------------------------------------------------------------
  -- State Machine Signals
  -----------------------------------------------------------------------------

  signal current_s : unsigned(2 downto 0) := to_unsigned(0, 3);  --current state declaration.

  component sm_states_rcv is
    generic (
      g_num_states : positive);
    port (
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      data_i      : in  std_logic_vector(g_num_states-1 downto 0);
      current_s_o : out unsigned(2 downto 0));
  end component sm_states_rcv;

  component sm_counter is
    generic (
      g_num_states : natural);
    port (
      clk_i            : in  std_logic;
      data_i           : in  std_logic_vector(g_num_states-1 downto 0);
      current_s_i      : in  unsigned(2 downto 0);
      count_success_o  : out count_array;
      count_fail_o     : out count_array;
      count_repeated_o : out count_array;
      count_others_o   : out count_array);
  end component sm_counter;

begin

  -- Clock generation
  cmp_clk_gen : clk_gen
    port map (
      sys_clk_p_i    => sys_clk_p_i,
      sys_clk_n_i    => sys_clk_n_i,
      sys_clk_o      => open,
      sys_clk_bufg_o => sys_clk_gen_bufg
      );

  -- Obtain core locking and generate necessary clocks
  cmp_sys_pll_inst : sys_pll
    generic map (
      -- 125 MHz input clock
      g_clkin_period   => 8.000,
      g_divclk_divide  => 5,
      g_clkbout_mult_f => 32,

      -- 100 MHz output clock
      g_clk0_divide_f => 8,
      -- 200 MHz output clock
      g_clk1_divide   => 4
      )
    port map (
      rst_i    => '0',
      clk_i    => sys_clk_gen_bufg,
      clk0_o   => clk_100mhz,           -- 100MHz locked clock
      clk1_o   => clk_200mhz,           -- 200MHz locked clock
      locked_o => locked                -- '1' when the PLL has locked
      );

  cmp_reset : gc_reset
    generic map(
      g_clocks => c_num_clk             -- clk_100mhz
      )
    port map(
      free_clk_i => sys_clk_gen_bufg,
      locked_i   => locked,
      clks_i     => reset_clks,
      rstn_o     => rst_n_v
      );

  reset_clks(0) <= clk_100mhz;
  --reset_clks(1) <= ckl_200mhz;

  rst_n <= rst_n_v(0);

  gen_trigger : for i in 0 to 7 generate

    cmp_trigger_rcv : trigger_rcv
      generic map (
        g_glitch_len_width => c_glitch_len_width,
        g_sync_edge        => "positive")
      port map (
        clk_i   => clk_100mhz,
        rst_n_i => rst_n,
        len_i   => length,
        data_i  => trigger_i(i),
        pulse_o => pulse(i));

  end generate gen_trigger;

  -- Connect pulses signals to the output
  pulse_o <= pulse;

  -----------------------------------------------------------------------------
  -- State Machine
  -----------------------------------------------------------------------------

  sm_states_rcv_1 : sm_states_rcv
    generic map (
      g_num_states => 8)
    port map (
      clk_i       => clk_100mhz,
      rst_n_i     => rst_n,
      data_i      => pulse,
      current_s_o => current_s);

  sm_counter_1 : sm_counter
    generic map (
      g_num_states => 8)
    port map (
      clk_i            => clk_100mhz,
      data_i           => pulse,
      current_s_i      => current_s,
      count_success_o  => count_success,
      count_fail_o     => count_fail,
      count_repeated_o => count_repeated,
      count_others_o   => count_others);

  cmp_chipscope_icon_gen : chipscope_icon_2_port
    port map (
      CONTROL0 => CONTROL0,
      CONTROL1 => CONTROL1);

  cmp_chipscope_ila_0 : chipscope_ila_rcv
    port map (
      CONTROL             => CONTROL0,
      CLK                 => clk_100mhz,
      TRIG0               => count_success(7),
      TRIG1               => count_fail(7),
      TRIG2(7 downto 0)   => trigger_i,
      TRIG2(15 downto 8)  => pulse,
      TRIG2(18 downto 16) => std_logic_vector(current_s),
      TRIG2(31 downto 19) => filler(31 downto 19),
      TRIG3               => filler,
      TRIG4               => count_repeated(0),
      TRIG5               => count_others(0));

  cmp_chipscope_vio : chipscope_vio_16
    port map (
      CONTROL               => CONTROL1,
      CLK                   => clk_100mhz,
      SYNC_OUT(7 downto 0)  => length,
      SYNC_OUT(15 downto 8) => direction_o);

end architecture structural;
