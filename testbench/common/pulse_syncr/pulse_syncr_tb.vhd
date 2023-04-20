--------------------------------------------------------------------------------
-- Title      : Pulse synchronizer testbench
--------------------------------------------------------------------------------
-- File       : pulse_syncr_tb.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
---------------------------------------------------------------------------------
-- Description: Tests pulse_syncr core.
---------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-04-20   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.finish;
use std.textio.all;

library work;
use work.ifc_common_pkg.all;

entity pulse_syncr_tb is
end entity pulse_syncr_tb;

architecture test of pulse_syncr_tb is

  procedure f_gen_clk(constant freq : in    natural;
                      signal   clk  : inout std_logic) is
  begin
    loop
      wait for (0.5 / real(freq)) * 1 sec;
      clk <= not clk;
    end loop;
  end procedure f_gen_clk;

  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
  begin
    for i in 1 to cycles loop
      wait until rising_edge(clk);
    end loop;
  end procedure f_wait_cycles;


  procedure f_wait_clocked_signal(signal clk : in std_logic;
                                  signal sig : in std_logic;
                                  val        : in std_logic;
                                  timeout    : in natural := 2147483647) is
  variable cnt : natural := timeout;
  begin
    while sig /= val and cnt > 0 loop
      wait until rising_edge(clk);
      cnt := cnt - 1;
    end loop;
  end procedure f_wait_clocked_signal;

  constant c_SYS_CLOCK_FREQ : natural := 48193182;

  signal clk        : std_logic := '0';
  signal rst_n      : std_logic := '0';
  signal clr        : std_logic := '0';
  signal pulse      : std_logic := '0';
  signal sync       : std_logic := '0';
  signal sync_pulse : std_logic;

begin
  f_gen_clk(c_SYS_CLOCK_FREQ, clk);

  process
  begin
    rst_n <= '0';
    f_wait_cycles(clk, 10);
    rst_n <= '1';
    f_wait_cycles(clk, 1);

    -- Drives pulse
    pulse <= '1';
    f_wait_cycles(clk, 1);
    pulse <= '0';
    f_wait_clocked_signal(clk, sync_pulse, '1', 200);

    assert sync_pulse = '0'
      report "Synced pulse shouldn't be raised before syncing"
      severity error;

    -- Drives sync pulse
    sync <= '1';
    f_wait_cycles(clk, 1);
    sync <= '0';
    f_wait_cycles(clk, 1);

    assert sync_pulse = '1'
      report "Synced pulse should be raised right after syncing"
      severity error;

    -- Waits for synced pulse to fall
    f_wait_cycles(clk, 1);

    assert sync_pulse = '0'
      report "Synced pulse shouldn't last more than 1 clock cycle"
      severity error;

    -- Drives pulse
    pulse <= '1';
    f_wait_cycles(clk, 1);
    pulse <= '0';
    f_wait_clocked_signal(clk, sync_pulse, '1', 200);

    assert sync_pulse = '0'
      report "Synced pulse shouldn't be raised before syncing"
      severity error;

    -- Clears held pulse
    clr <= '1';
    f_wait_cycles(clk, 1);
    clr <= '0';
    f_wait_cycles(clk, 1);

    -- Drives sync pulse
    sync <= '1';
    f_wait_cycles(clk, 1);
    sync <= '0';
    f_wait_clocked_signal(clk, sync_pulse, '1', 200);

    assert sync_pulse = '0'
      report "There shouldn't be a synced pulse after clearing"
      severity error;

    finish;
  end process;

  uut : pulse_syncr
    port map (
      clk_i         => clk,
      rst_n_i       => rst_n,
      clr_i         => clr,
      pulse_i       => pulse,
      sync_i        => sync,
      sync_pulse_o  => sync_pulse
    );

end architecture test;
