------------------------------------------------------------------------------
-- Title      : Anti-windup accumulator simulation
------------------------------------------------------------------------------
-- Author     : Guilherme Ricioli
-- Company    : CNPEM LNLS-GCA
-- Created    : 2022-05-02
-- Platform   : Simulation
-------------------------------------------------------------------------------
-- Description: Tests the accumulator core by adding up arithmetic progressions
--              (both positive and negative). Anti-windup limits can be set
--              using c_ANTI_WINDUP_{LOWER,UPPER}_LIMIT constants.
-------------------------------------------------------------------------------
-- Copyright (c) 2022 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author            Description
-- 2022-05-20  1.0      guilherme.ricioli Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.env.finish;
use std.textio.all;

library work;
use work.ifc_common_pkg.all;

entity anti_windup_accumulator_tb is
end entity anti_windup_accumulator_tb;

architecture anti_windup_accumulator_tb_arch of anti_windup_accumulator_tb is
  -- procedures
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

  -- constants
  constant c_SYS_CLOCK_FREQ           : natural                       := 100000000;

  constant c_A_WIDTH                  : natural                       := 16;
  constant c_Q_WIDTH                  : natural                       := 16;
  constant c_ANTI_WINDUP_UPPER_LIMIT  : signed(31 downto 0)           := to_signed(4000, 32);
  constant c_ANTI_WINDUP_LOWER_LIMIT  : signed(31 downto 0)           := to_signed(-3000, 32);

  constant c_N                        : natural                       := 100;

  -- signals
  signal clk_s                        : std_logic                     := '0';
  signal rst_n_s                      : std_logic                     := '0';

  signal a_s                          : signed(c_A_WIDTH-1 downto 0)  := (others => '0');
  signal clear_s                      : std_logic                     := '0';
  signal sum_s                        : std_logic                     := '0';
  signal q_s                          : signed(c_Q_WIDTH-1 downto 0)  := (others => '0');
  signal valid_s                      : std_logic                     := '0';

begin
  f_gen_clk(c_SYS_CLOCK_FREQ, clk_s);

  -- main process
  process
    -- process variables
    variable count                    : signed(c_A_WIDTH-1 downto 0)  := (others => '0');
    variable accumulated              : signed(c_Q_WIDTH-1 downto 0)  := (others => '0');

  begin
    -- resetting cores
    report "resetting cores" severity note;

    f_wait_cycles(clk_s, 1);
    rst_n_s <= '1';
    f_wait_cycles(clk_s, 10);

    -- arithmetic progression sum (r = 1)
    report "arithmetic progression sum (r = 1)" severity note;

    count := (others => '0');
    accumulated := (others => '0');
    while (count <= c_N-1)
    loop
      f_wait_cycles(clk_s, 1);
      count := count + 1;
      accumulated := accumulated + count;

      a_s <= count;
      sum_s <= '1';

      f_wait_cycles(clk_s, 1);
      sum_s <= '0';
    end loop;
    f_wait_cycles(clk_s, 10);

    -- assertion
    if (accumulated < c_ANTI_WINDUP_UPPER_LIMIT) then
      assert (q_s = accumulated)
        report
          "Wrong accumulated value: " & integer'image(to_integer(q_s)) &
          " (expected " & integer'image(to_integer(accumulated)) & ")"
        severity failure;
    else
      assert (q_s = c_ANTI_WINDUP_UPPER_LIMIT)
        report
          "Wrong accumulated value: " & integer'image(to_integer(q_s)) &
          " (expected to be clamped at " &
          integer'image(to_integer(c_ANTI_WINDUP_UPPER_LIMIT)) & ")"
        severity failure;
    end if;

    -- clearing accumulator
    report "clearing accumulator" severity note;

    f_wait_cycles(clk_s, 1);
    clear_s <= '1';
    f_wait_cycles(clk_s, 1);
    clear_s <= '0';
    f_wait_cycles(clk_s, 10);

    -- assertion
    assert (q_s = to_signed(0, q_s'length))
      report "Accumulator not cleared" severity failure;

    -- arithmetic progression sum (r = -1)
    report "arithmetic progression sum (r = -1)" severity note;

    count := (others => '0');
    accumulated := (others => '0');
    while (count <= c_N-1)
    loop
      f_wait_cycles(clk_s, 1);
      a_s <= -count;
      sum_s <= '1';

      accumulated := accumulated - count;
      count := count + 1;

      f_wait_cycles(clk_s, 1);
      sum_s <= '0';
    end loop;

    -- assertion
    if (accumulated > c_ANTI_WINDUP_LOWER_LIMIT) then
      assert (q_s = accumulated)
        report
          "Wrong accumulated value: " & integer'image(to_integer(q_s)) &
          " (expected " & integer'image(to_integer(accumulated)) & ")"
        severity failure;
    else
      assert (q_s = c_ANTI_WINDUP_LOWER_LIMIT)
        report
          "Wrong accumulated value: " & integer'image(to_integer(q_s)) &
          " (expected to be clamped at " &
          integer'image(to_integer(c_ANTI_WINDUP_LOWER_LIMIT)) & ")"
        severity failure;
    end if;

    finish;
  end process;

  -- components
  cmp_anti_windup_accumulator : entity work.anti_windup_accumulator
    generic map
    (
      g_A_WIDTH                       => c_A_WIDTH,                 -- input width
      g_Q_WIDTH                       => c_Q_WIDTH,                 -- output width
      g_ANTI_WINDUP_UPPER_LIMIT       => c_ANTI_WINDUP_UPPER_LIMIT, -- anti-windup upper limit
      g_ANTI_WINDUP_LOWER_LIMIT       => c_ANTI_WINDUP_LOWER_LIMIT  -- anti-windup lower limit
    )
    port map
    (
      clk_i                           => clk_s,                     -- clock
      rst_n_i                         => rst_n_s,                   -- reset

      a_i                             => a_s,                       -- input a
      clear_i                         => clear_s,                   -- clear
      sum_i                           => sum_s,                     -- sum
      q_o                             => q_s,                       -- output q
      valid_o                         => valid_s                    -- valid
    );

end architecture anti_windup_accumulator_tb_arch;
