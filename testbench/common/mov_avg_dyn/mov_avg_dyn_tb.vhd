--------------------------------------------------------------------------------
-- Title      : Dynamic moving average filter testbench
--------------------------------------------------------------------------------
-- File       : mov_avg_dyn_tb.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
---------------------------------------------------------------------------------
-- Description: Testbench for mov_avg_dyn core.
---------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-05-12   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.finish;
use std.textio.all;

library work;
use work.ifc_common_pkg.all;

entity mov_avg_dyn_tb is
end entity mov_avg_dyn_tb;

architecture test of mov_avg_dyn_tb is
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

  constant c_CLOCK_FREQ     : natural := 48193182;
  constant c_DATA_WIDTH     : natural := 16;
  constant c_MAX_ORDER_SEL  : natural := 5;

  signal clk                : std_logic := '0';
  signal rst_n              : std_logic := '0';
  signal order_sel          : natural range 0 to c_MAX_ORDER_SEL := 0;
  signal data               : signed(c_DATA_WIDTH-1 downto 0) := (others => '0');
  signal valid              : std_logic := '0';
  signal avgd_data          : signed(c_DATA_WIDTH-1 downto 0);
  signal avgd_data_valid    : std_logic;

begin
  f_gen_clk(c_CLOCK_FREQ, clk);

  process
    file fin : text;
    variable lin : line;
    variable v_data : integer := 0;
    variable v_avgd_data : integer := 0;
    variable v_avgd_data_err : real := 0.0;
    variable v_space : character;
  begin
    rst_n <= '0';
    f_wait_cycles(clk, 10);
    rst_n <= '1';
    f_wait_cycles(clk, 1);

    for opt in 0 to c_MAX_ORDER_SEL loop
      order_sel <= opt;
      f_wait_cycles(clk, 1);
      -- Changing the order resets the internal state of the filter, which is
      -- the expected initial state of the test files.

      file_open(fin, "../mov_avg_order_sel_" & integer'image(opt) & ".dat",
        read_mode);
      while not endfile(fin) loop
        readline(fin, lin);

        read(lin, v_data);
        data <= to_signed(v_data, data'length);
        valid <= '1';
        f_wait_cycles(clk, 1);

        valid <= '0';
        f_wait_clocked_signal(clk, avgd_data_valid, '1');

        read(lin, v_space); -- skipping space

        read(lin, v_avgd_data);
        v_avgd_data_err := abs(real(to_integer(avgd_data) - v_avgd_data));
        assert v_avgd_data_err <= 1.0
          report
            "Truncation error can't be higher than 1 (got: " &
            integer'image(to_integer(avgd_data)) & ", expected: " &
            integer'image(v_avgd_data) & ", opt: " & integer'image(opt) & ")"
          severity error;
      end loop;

      file_close(fin);
    end loop;

    report "all good!" severity note;

    finish;
  end process;

  uut : mov_avg_dyn
    generic map (
      g_MAX_ORDER_SEL => c_MAX_ORDER_SEL,
      g_DATA_WIDTH    => c_DATA_WIDTH
    )
    port map (
      clk_i           => clk,
      rst_n_i         => rst_n,
      order_sel_i     => order_sel,
      data_i          => data,
      valid_i         => valid,
      avgd_data_o     => avgd_data,
      valid_o         => avgd_data_valid
    );
end architecture test;
