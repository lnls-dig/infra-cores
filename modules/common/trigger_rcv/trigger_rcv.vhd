-------------------------------------------------------------------------------
-- Title      : Trigger receiver
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_rcv.vhd
-- Author     : aylons  <aylons@LNLS190>
-- Company    :
-- Created    : 2015-11-09
-- Last update: 2016-01-22
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Receives a signal from an FPGA port, debounces the signal and
-- outputs a pulse with a configurable clock width.
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
-- Date        Version  Author  Description
-- 2015-11-09  1.0      aylons  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;

entity trigger_rcv is
  generic (
    -- Number of glicth filter registers
    g_glitch_len_width : positive := 8;
    -- Width of the output pulse after edge detection
    g_sync_edge        : string   := "positive"
    );
  port(
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;
    len_i   : in  std_logic_vector(g_glitch_len_width-1 downto 0);
    data_i  : in  std_logic;
    pulse_o : out std_logic;
    dbg_data_sync_o        : out std_logic;
    dbg_data_degliteched_o : out std_logic
    );
end entity trigger_rcv;

architecture structural of trigger_rcv is

  signal deglitched : std_logic;
  signal data_sync  : std_logic := '0';

  component gc_dyn_glitch_filt is
    generic (
      g_len_width : natural);
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      len_i   : in  std_logic_vector(g_len_width-1 downto 0);
      dat_i   : in  std_logic;
      dat_o   : out std_logic);
  end component gc_dyn_glitch_filt;

  component gc_sync_ffs is
    generic (
      g_sync_edge : string);
    port (
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      data_i   : in  std_logic;
      synced_o : out std_logic;
      npulse_o : out std_logic;
      ppulse_o : out std_logic);
  end component gc_sync_ffs;

begin

    -- Prevent matastability problems
    cmp_input_sync : gc_sync_ffs
      generic map(
        g_sync_edge => "positive")
      port map(
        clk_i    => clk_i,
        rst_n_i  => rst_n_i,
        data_i   => data_i,
        synced_o => data_sync,
        npulse_o => open,
        ppulse_o => open);

    dbg_data_sync_o <= data_sync;

  cmp_deglitcher : gc_dyn_glitch_filt
    generic map (
      g_len_width => g_glitch_len_width)
    port map (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      len_i   => len_i,
      dat_i   => data_sync,
      dat_o   => deglitched);

    dbg_data_degliteched_o <= deglitched;

  cmp_edge_detector : gc_sync_ffs
    generic map(
      g_sync_edge => g_sync_edge)
    port map(
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      data_i   => deglitched,
      synced_o => open,
      npulse_o => open,
      ppulse_o => pulse_o);

end architecture structural;
