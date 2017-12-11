-------------------------------------------------------------------------------
-- Title      : Testbench for design "trigger_io"
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_io_tb.vhd
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

entity trigger_io_tb is
end entity trigger_io_tb;

architecture test of trigger_io_tb is

  -- constants
  constant c_rx_debounce_width               : natural := 8;
  constant c_tx_extensor_width               : natural := 8;
  constant c_rx_delay_width                  : natural := 32;
  constant c_tx_delay_width                  : natural := 32;
  constant c_rx_counter_width                : natural := 32;
  constant c_tx_counter_width                : natural := 32;

  -- component ports
  signal clk                                 : std_logic := '1';
  signal rst_n                               : std_logic := '0';

  signal trig_dir                            : std_logic := '1'; -- FPGA is input
  signal trig_ext_dir_pol                    : std_logic := '1'; -- reverse polarity to external
  signal trig_rx_debounce_length             : unsigned(c_rx_debounce_width-1 downto 0) := to_unsigned(10, c_rx_debounce_width);
  signal trig_tx_extensor_length             : unsigned(c_tx_extensor_width-1 downto 0) := to_unsigned(10, c_tx_extensor_width);
  signal trig_rx_delay_length                : unsigned(c_rx_delay_width-1 downto 0) := to_unsigned(0, c_rx_delay_width);
  signal trig_tx_delay_length                : unsigned(c_tx_delay_width-1 downto 0) := to_unsigned(0, c_tx_delay_width);
  signal trig_rx_rst_n                       : std_logic := '1';
  signal trig_tx_rst_n                       : std_logic := '1';
  signal trig_rx_cnt                         : unsigned(c_rx_counter_width-1 downto 0);
  signal trig_tx_cnt                         : unsigned(c_tx_counter_width-1 downto 0);

  signal trig_pad_dir                        : std_logic;
  signal trig_pad_inout                      : std_logic;
  signal trig_pad_in                         : std_logic;
  signal trig_pad_out                        : std_logic;

  signal trig_in                             : std_logic := '0';
  signal trig_out                            : std_logic;
  signal trig_dbg                            : std_logic;

  -- test signal
  signal pulse_from_fpga                     : std_logic := '0';
  signal pulse_from_pad                      : std_logic := '0';
  signal test_begin_pulse                    : std_logic := '0';
  signal test_end                            : std_logic := '0';

begin  -- architecture test

  -- clock generation
  clk <= not clk after 10 ns;
  -- reset generation
  rst_n <= '1' after 40 ns;
  -- Pulldown resistor for MLVDS bus
  trig_pad_inout <= 'L';

  -- Main testbench
  p_stimulus : process
  begin
    wait until rising_edge(clk) and rst_n = '1';

    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;

    ---------------------------------------------------------------------------
    -- Test #1
    -- Receiving trigger from pad, 10 clock cycles
    ---------------------------------------------------------------------------
    report "Test #1 starting";
    trig_dir <= '1'; -- FPGA is input
    test_begin_pulse <= '1';
    wait until rising_edge(clk);
    test_begin_pulse <= '0';
    wait until rising_edge(clk);

    -- Test trigger from pad, 10 clock cycles
    trig_pad_inout <= '1';
    for i in 0 to 9 loop
      wait until rising_edge(clk);
    end loop;
    trig_pad_inout <= 'Z';
    wait until rising_edge(clk);

    report "Waiting for verification on test #1";
    if test_end /= '1' then
      wait until test_end = '1';
    end if;
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #2
    -- Receiving trigger from pad, 1 clock cycles
    ---------------------------------------------------------------------------
    report "Test #2 starting";
    trig_dir <= '1'; -- FPGA is input
    test_begin_pulse <= '1';
    wait until rising_edge(clk);
    test_begin_pulse <= '0';
    wait until rising_edge(clk);

    -- Test trigger from pad, 1 clock cycle
    trig_pad_inout <= '1';
    wait until rising_edge(clk);
    trig_pad_inout <= 'Z';
    wait until rising_edge(clk);

    report "Waiting for verification on test #2";
    if test_end /= '1' then
      wait until test_end = '1';
    end if;
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #3
    -- Sending trigger to pad, 10 clock cycles
    ---------------------------------------------------------------------------
    report "Test #3 starting";
    trig_dir <= '0'; -- FPGA is output
    trig_tx_extensor_length <= to_unsigned(10, trig_tx_extensor_length'length);
    test_begin_pulse <= '1';
    wait until rising_edge(clk);
    test_begin_pulse <= '0';
    wait until rising_edge(clk);

    -- Test trigger from FPGA, 1 clock cycles, but extend to 10
    trig_in <= '1';
    wait until rising_edge(clk);
    trig_in <= '0';
    wait until rising_edge(clk);

    report "Waiting for verification on test #3";
    if test_end /= '1' then
      wait until test_end = '1';
    end if;
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #4
    -- Sending trigger to pad, 1 clock cycles (don't extend pulse)
    ---------------------------------------------------------------------------
    report "Test #4 starting";
    trig_dir <= '0'; -- FPGA is output
    trig_tx_extensor_length <= to_unsigned(0, trig_tx_extensor_length'length);
    test_begin_pulse <= '1';
    wait until rising_edge(clk);
    test_begin_pulse <= '0';
    wait until rising_edge(clk);

    -- Test trigger from FPGA, 1 clock cycle
    trig_in <= '1';
    wait until rising_edge(clk);
    trig_in <= '0';
    wait until rising_edge(clk);

    report "Waiting for verification on test #4";
    if test_end /= '1' then
      wait until test_end = '1';
    end if;
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #5
    -- Sending trigger to pad, 2 clock cycles (extend 1 clock)
    ---------------------------------------------------------------------------
    report "Test #5 starting";
    trig_dir <= '0'; -- FPGA is output
    trig_tx_extensor_length <= to_unsigned(1, trig_tx_extensor_length'length);
    test_begin_pulse <= '1';
    wait until rising_edge(clk);
    test_begin_pulse <= '0';
    wait until rising_edge(clk);

    -- Test trigger from FPGA, 1 clock cycle
    trig_in <= '1';
    wait until rising_edge(clk);
    trig_in <= '0';
    wait until rising_edge(clk);

    report "Waiting for verification on test #5";
    if test_end /= '1' then
      wait until test_end = '1';
    end if;
    wait until rising_edge(clk);

    wait;

  end process;

  -- Verification
  p_verification : process
  begin
    ---------------------------------------------------------------------------
    -- Test #1
    ---------------------------------------------------------------------------
    wait until test_begin_pulse = '1';
    -- Trigger should arrive
    wait until trig_out = '1';
    report "Test #1 succeeded";

    test_end <= '1';
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #2
    ---------------------------------------------------------------------------
    wait until test_begin_pulse = '1';
    test_end <= '0';
    -- Trigger should not arrive as debounce is larger than 1 clock cycle
    for i in 0 to 49 loop
      wait until rising_edge(clk);
      if trig_out = '1' then
        report "Test #2 failed" severity failure;
      end if;
    end loop;

    report "Test #2 succeeded";

    test_end <= '1';
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #3
    ---------------------------------------------------------------------------
    wait until test_begin_pulse = '1';
    test_end <= '0';
    -- Trigger should arrive at pad with 10 clock cycles
    wait until trig_pad_inout = '1';
    for i in 0 to 9 loop
      wait until rising_edge(clk);
      if trig_pad_inout = '0' then
        report "Test #3 failed at pulse high iteration" & Integer'Image(i) severity failure;
      end if;
    end loop;

    for i in 0 to 9 loop
      wait until rising_edge(clk);
      if trig_pad_inout = '1' then
        report "Test #3 failed at pulse low iteration " & Integer'Image(i) severity failure;
      end if;
    end loop;

    report "Test #3 succeeded";

    test_end <= '1';
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #4
    ---------------------------------------------------------------------------
    wait until test_begin_pulse = '1';
    test_end <= '0';
    -- Trigger should arrive as 1 clock cycle
    wait until trig_pad_inout = '1';
    wait until rising_edge(clk);
    for i in 0 to 9 loop
      wait until rising_edge(clk);
      if trig_pad_inout = '1' then
        report "Test #4 failed at iteration " & Integer'Image(i) severity failure;
      end if;
    end loop;

    report "Test #4 succeeded";

    test_end <= '1';
    wait until rising_edge(clk);

    ---------------------------------------------------------------------------
    -- Test #5
    ---------------------------------------------------------------------------
    wait until test_begin_pulse = '1';
    test_end <= '0';
    -- Trigger should arrive as 2 clock cycle
    wait until trig_pad_inout = '1';
    for i in 0 to 0 loop
      wait until rising_edge(clk);
      if trig_pad_inout = '0' then
        report "Test #5 failed, as pulse is not a 2 clock cycle pulse, at iteration " & Integer'Image(i) severity failure;
      end if;
    end loop;

    wait until rising_edge(clk);
    for i in 0 to 9 loop
      wait until rising_edge(clk);
      if trig_pad_inout = '1' then
        report "Test #5 failed, as pulse is glitchy at iteration " & Integer'Image(i) severity failure;
      end if;
    end loop;

    report "Test #5 succeeded";

    test_end <= '1';
    wait until rising_edge(clk);

    wait;

  end process;

  -- component instantiation
  DUT : trigger_io
  generic map (
    --g_with_bidirectional_trigger             : boolean := true;
    --g_iobuf_instantiation_type               : string  := "native"
    --g_sync_edge                              : string  := "positive";
    g_rx_debounce_width                      => c_rx_debounce_width,
    g_tx_extensor_width                      => c_tx_extensor_width,
    g_rx_counter_width                       => c_rx_counter_width,
    g_tx_counter_width                       => c_tx_counter_width,
    g_rx_delay_width                         => c_rx_delay_width,
    g_tx_delay_width                         => c_tx_delay_width
  )
  port map (
    -- Clock/Resets
    clk_i                                    => clk,
    rst_n_i                                  => rst_n,

    -------------------------------
    -- Trigger configuration
    -------------------------------
    trig_dir_i                               => trig_dir,
    trig_ext_dir_pol_i                       => trig_ext_dir_pol,
    trig_rx_debounce_length_i                => trig_rx_debounce_length,
    trig_tx_extensor_length_i                => trig_tx_extensor_length,
    trig_rx_delay_length_i                   => trig_rx_delay_length,
    trig_tx_delay_length_i                   => trig_tx_delay_length,

    -------------------------------
    -- Counters
    -------------------------------
    trig_rx_rst_n_i                          => trig_rx_rst_n,
    trig_tx_rst_n_i                          => trig_tx_rst_n,
    trig_rx_cnt_o                            => trig_rx_cnt,
    trig_tx_cnt_o                            => trig_tx_cnt,

    -------------------------------
    -- External ports
    -------------------------------
    trig_dir_o                               => trig_pad_dir,
    trig_b                                   => trig_pad_inout,
    trig_i                                   => trig_pad_in,
    trig_o                                   => trig_pad_out,

    -------------------------------
    -- Trigger input/output ports
    -------------------------------
    trig_in_i                                => trig_in,
    trig_out_o                               => trig_out,

    -------------------------------
    -- Debug ports
    -------------------------------
    trig_dbg_o                               => trig_dbg
  );

end architecture test;
