--------------------------------------------------------------------------------
-- Title      : Pseudo-Random Binary Sequence (PRBS) generator testbench
--------------------------------------------------------------------------------
-- File       : prbs_gen_for_sys_id_tb.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
--------------------------------------------------------------------------------
-- Description: This testbench asserts the generation of PRBS7-5 and PRBS8-10
--              (the '-n' suffix is the step duration).
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-03-29   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.env.finish;
use std.textio.all;

library work;
use work.ifc_common_pkg.all;

entity prbs_gen_for_sys_id_tb is
end entity prbs_gen_for_sys_id_tb;

architecture sim of prbs_gen_for_sys_id_tb is

  -- functions
  function f_calc_prbs_duration(length : natural range 2 to 32;
                                step_duration : natural range 1 to 1024)
                                return natural is
  begin
    return (2**length - 1)*step_duration;
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
  signal lfsr_length : natural range 2 to 32 := 32;
  signal step_duration : natural range 1 to 1024 := 1;
  signal valid : std_logic := '0';
  signal busy : std_logic := '0';
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
    -- setting prbs length to 7
    report "setting prbs length to 7" severity note;

    lfsr_length <= 7;
    f_wait_cycles(clk, 1);

    -- setting prbs step duration to 5
    report "setting prbs step duration to 5" severity note;

    step_duration <= 5;
    f_wait_cycles(clk, 1);

    -- resetting cores
    report "resetting cores" severity note;

    rst_n <= '0';
    f_wait_cycles(clk, 1);
    rst_n <= '1';
    f_wait_cycles(clk, 1);

    file_open(fd_prbs_seq, "../prbs_" & natural'image(lfsr_length) & "_" &
              natural'image(step_duration) & ".dat", read_mode);

    v_count := 0;
    while v_count < f_calc_prbs_duration(lfsr_length, step_duration) loop
      f_wait_clocked_signal(clk, busy, '0');
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

    lfsr_length <= 8;
    f_wait_cycles(clk, 1);

    -- setting prbs step duration to 10
    report "setting prbs step duration to 10" severity note;

    step_duration <= 10;
    f_wait_cycles(clk, 1);

    -- resetting cores
    report "resetting cores" severity note;

    rst_n <= '0';
    f_wait_cycles(clk, 1);
    rst_n <= '1';
    f_wait_cycles(clk, 1);

    file_open(fd_prbs_seq, "../prbs_" & natural'image(lfsr_length) & "_" &
              natural'image(step_duration) & ".dat", read_mode);

    v_count := 0;
    while v_count < f_calc_prbs_duration(lfsr_length, step_duration) loop
      f_wait_clocked_signal(clk, busy, '0');
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
  uut : prbs_gen_for_sys_id
    port map (
      clk_i           => clk,
      rst_n_i         => rst_n,
      en_i            => '1',
      step_duration_i => step_duration,
      lfsr_length_i   => lfsr_length,
      valid_i         => valid,
      busy_o          => busy,
      prbs_o          => prbs,
      valid_o         => valid_prbs_gen
    );

end architecture sim;
