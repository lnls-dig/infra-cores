-------------------------------------------------------------------------------
-- Title      : Trigger receiver RX datapath
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_io_rx_datapath.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-11-14
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Receives trigger from a hardware line. It supports,
-- debouncing, polarity, direction control and controllable delay.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-11-14  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_common_pkg.all;
use work.trigger_common_pkg.all;

entity trigger_io_rx_datapath is
generic
(
  -- Sync pulse on "positive" or "negative" edge of incoming pulse
  g_sync_edge                              : string  := "positive";
  -- Length of receive debounce counters
  g_rx_debounce_width                      : natural := 8;
  -- Length of receive counters
  g_rx_counter_width                       : natural := 8;
  -- Length of receiving delay counters
  g_rx_delay_width                         : natural := 32
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -------------------------------
  -- Trigger RX configuration
  -------------------------------
  -- Receive debounce clocks
  trig_rx_debounce_length_i                : in unsigned(g_rx_debounce_width-1 downto 0);
  -- Number of clocks to delay an incoming trigger pulse
  trig_rx_delay_length_i                   : in unsigned(g_rx_delay_width-1 downto 0);

  -------------------------------
  -- Counters
  -------------------------------
  -- Reset receiving counter
  trig_rx_rst_n_i                          : in std_logic;
  -- Number of detected received triggers from external module
  trig_rx_cnt_o                            : out unsigned(g_rx_counter_width-1 downto 0);

  -------------------------------
  -- External ports
  -------------------------------
  -- Trigger input from external
  trig_i                                   : in std_logic;

  -------------------------------
  -- Trigger output ports
  -------------------------------
  -- Trigger data output to the FPGA
  trig_out_o                               : out std_logic
);
end entity trigger_io_rx_datapath;

architecture rtl of trigger_io_rx_datapath is

  -- Signals
  signal trig_rx                           : t_trig_channel;
  signal trig_rx_debounced                 : t_trig_channel;
  signal trig_rx_debounced_dly             : t_trig_channel;

  signal trig_rx_cnt_slv                   : std_logic_vector(g_rx_counter_width-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Trigger from external
  ----------------------------------------------------------------------------
  trig_rx.pulse <= trig_i;

  ----------------------------------------------------------------------------
  -- Receiver dataflow: generate pulse from external, delay pulse
  ----------------------------------------------------------------------------

  cmp_trigger_rx : trigger_rcv
    generic map (
      g_glitch_len_width                   => g_rx_debounce_width,
      g_sync_edge                          => g_sync_edge)
    port map (
      clk_i                                => clk_i,
      rst_n_i                              => rst_n_i,
      data_i                               => trig_rx.pulse,
      len_i                                => std_logic_vector(trig_rx_debounce_length_i),
      pulse_o                              => trig_rx_debounced.pulse
  );

  cmp_rx_delay_gen_dyn : delay_gen_dyn
  generic map (
    -- delay counter width
    g_delay_cnt_width                      => g_rx_delay_width)
  port map (
    -- Clock/Resets
    clk_i                                  => clk_i,
    rst_n_i                                => rst_n_i,
    pulse_i                                => trig_rx_debounced.pulse,
    rdy_o                                  => open,
    delay_cnt_i                            => trig_rx_delay_length_i,
    pulse_o                                => trig_rx_debounced_dly.pulse
  );

  trig_out_o <= trig_rx_debounced_dly.pulse;

  ----------------------------------------------------------------------------
  -- Pulse counters
  ----------------------------------------------------------------------------

  cmp_counter_rx : counter_simple
  generic map (
    g_output_width                         => g_rx_counter_width)
  port map (
    clk_i                                  => clk_i,
    rst_n_i                                => trig_rx_rst_n_i,
    ce_i                                   => '1',
    up_i                                   => trig_rx_debounced_dly.pulse,
    down_i                                 => '0',
    count_o                                => trig_rx_cnt_slv
  );

  trig_rx_cnt_o <= unsigned(trig_rx_cnt_slv);

end rtl;
