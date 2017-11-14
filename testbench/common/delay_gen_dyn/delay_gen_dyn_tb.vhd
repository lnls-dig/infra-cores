-------------------------------------------------------------------------------
-- Title      : Testbench for design "delay_gen_dyn"
-- Project    :
-------------------------------------------------------------------------------
-- File       : delay_gen_dyn_tb.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    : Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-- Created    : 2017-11-14
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2017 Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-11-14  1.0      vfinotti        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;
use std.textio.all;

library work;
use work.ifc_common_pkg.all;

entity delay_gen_dyn_tb is
end entity delay_gen_dyn_tb;

architecture test of delay_gen_dyn_tb is

  -- constants
  constant c_delay_cnt_initial               : natural := 100;
  constant c_delay_cnt_width                 : natural := 32;

  -- component ports
  signal clk                                 : std_logic := '1';
  signal rst_n                               : std_logic := '0';
  signal pulse                               : std_logic := '0';
  signal delay_cnt                           : unsigned(c_delay_cnt_width-1 downto 0) :=
                                                to_unsigned(c_delay_cnt_initial, c_delay_cnt_width);

  -- component declaration
  component delay_gen_dyn
  generic
  (
    -- delay counter width
    g_delay_cnt_width                        : natural := 32
  );
  port
  (
    -- Clock/Resets
    clk_i                                    : in std_logic;
    rst_n_i                                  : in std_logic;

    -- Incoming pulse
    pulse_i                                  : in std_logic;
    -- '1' when the module is ready to receive another the pulse
    rdy_o                                    : out std_logic;
    -- Number of clock cycles to delay the incoming pulse
    delay_cnt_i                              : in unsigned(g_delay_cnt_width-1 downto 0);

    -- Output pulse
    pulse_o                                  : out std_logic
  );
  end component;

begin  -- architecture test

  -- clock generation
  clk <= not clk after 10 ns;
  -- reset generation
  rst_n <= '1' after 40 ns;

  -- Main testbench
  p_pulse_gen : process
  begin
    wait until rising_edge(clk) and rst_n = '1';

    -- Test delay 0

    delay_cnt <= to_unsigned(0, delay_cnt'length);
    wait until rising_edge(clk);

    pulse <= '1';
    wait until rising_edge(clk);
    pulse <= '0';

    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;

    -- Test delay 10

    delay_cnt <= to_unsigned(10, delay_cnt'length);
    wait until rising_edge(clk);

    pulse <= '1';
    wait until rising_edge(clk);
    pulse <= '0';

    for i in 0 to 19 loop
      wait until rising_edge(clk);
    end loop;

    -- Test delay 25

    delay_cnt <= to_unsigned(25, delay_cnt'length);
    wait until rising_edge(clk);

    pulse <= '1';
    wait until rising_edge(clk);
    pulse <= '0';

    for i in 0 to 29 loop
      wait until rising_edge(clk);
    end loop;

    wait;

  end process;

  -- component instantiation
  DUT : delay_gen_dyn
  port map (
    clk_i                                    => clk,
    rst_n_i                                  => rst_n,

    pulse_i                                  => pulse,
    rdy_o                                    => open,
    delay_cnt_i                              => delay_cnt,

    pulse_o                                  => open
  );

end architecture test;
