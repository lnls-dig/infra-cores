--------------------------------------------------------------------------------
-- Title      : Pseudo-Random Binary Sequence (PRBS) generator testbench
--------------------------------------------------------------------------------
-- File       : prbs_gen_tb.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
---------------------------------------------------------------------------------
-- Description: This testbench asserts the generation of PRBS7 and PRBS8.
---------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-03-15   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.finish;
use std.textio.all;

entity prbs_gen_tb is
end entity prbs_gen_tb;

architecture sim of prbs_gen_tb is

  -- functions
  function f_calc_prbs_duration(length : natural range 2 to 32) return natural is
  begin
    return 2**length - 1;
  end function;

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

  -- constants
  constant c_SYS_CLOCK_FREQ : natural := 48193182;

  -- signals
  signal clk : std_logic := '0';
  signal rst_n : std_logic := '0';
  signal length : natural range 2 to 32 := 32;
  signal valid : std_logic := '0';
  signal prbs : std_logic := '0';
  signal valid_prbs_gen : std_logic := '0';

begin
  f_gen_clk(c_SYS_CLOCK_FREQ, clk);

  -- processes
  process
    file fd_prbs_seq : text;
    variable lin : line;
    variable v_prbs : std_logic;
    variable v_count : natural := 0;
  begin
    -- resetting core
    report "resetting core" severity note;

    rst_n <= '0';
    f_wait_cycles(clk, 10);
    rst_n <= '1';
    f_wait_cycles(clk, 1);

    -- setting prbs length to 7
    report "setting prbs length to 7" severity note;

    length <= 7;
    f_wait_cycles(clk, 1);

    file_open(fd_prbs_seq, "../prbs_7.dat", read_mode);

    v_count := 0;
    while v_count < f_calc_prbs_duration(length) loop
      valid <= '1';
      f_wait_cycles(clk, 1);
      valid <= '0';
      f_wait_clocked_signal(clk, valid_prbs_gen, '1');

      readline(fd_prbs_seq, lin);
      read(lin, v_prbs);
      if prbs /= v_prbs then
        report "got " & std_logic'image(prbs) & ", "
                & "expected " & std_logic'image(v_prbs)
        severity failure;
      end if;

      v_count := v_count + 1;
    end loop;

    file_close(fd_prbs_seq);

    -- setting prbs length to 8
    report "setting prbs length to 8" severity note;

    length <= 8;
    f_wait_cycles(clk, 1);

    file_open(fd_prbs_seq, "../prbs_8.dat", read_mode);

    v_count := 0;
    while v_count < f_calc_prbs_duration(length) loop
      valid <= '1';
      f_wait_cycles(clk, 1);
      valid <= '0';
      f_wait_clocked_signal(clk, valid_prbs_gen, '1');

      readline(fd_prbs_seq, lin);
      read(lin, v_prbs);
      if prbs /= v_prbs then
        report "got " & std_logic'image(prbs) & ", "
                & "expected " & std_logic'image(v_prbs)
        severity failure;
      end if;

      v_count := v_count + 1;
    end loop;

    file_close(fd_prbs_seq);

    report "all good!" severity note;


    finish;
  end process;

  -- components
  uut: entity work.prbs_gen
    port map (
      clk_i     => clk,
      rst_n_i   => rst_n,
      length_i  => length,
      valid_i   => valid,
      prbs_o    => prbs,
      valid_o   => valid_prbs_gen
    );

end architecture sim;
