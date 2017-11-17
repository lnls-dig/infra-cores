-------------------------------------------------------------------------------
-- Title      : Trigger receiver TX datapath
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_io_tx_datapath.vhd
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

entity trigger_io_tx_datapath is
generic
(
  -- Length of transmitter extensor counters
  g_tx_extensor_width                      : natural := 8;
  -- Length of transmitter counters
  g_tx_counter_width                       : natural := 8;
  -- Length of transmitter delay counters
  g_tx_delay_width                         : natural := 32
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -------------------------------
  -- Trigger TX configuration
  -------------------------------
  -- Transmitter extensor clocks
  trig_tx_extensor_length_i                : in unsigned(g_tx_extensor_width-1 downto 0);
  -- Number of detected transmitted triggers to external module
  trig_tx_delay_length_i                   : in unsigned(g_tx_delay_width-1 downto 0);

  -------------------------------
  -- Counters
  -------------------------------
  -- Reset transmitter counter
  trig_tx_rst_n_i                          : in std_logic;
  -- Number of detected transmitted triggers to external module
  trig_tx_cnt_o                            : out unsigned(g_tx_counter_width-1 downto 0);

  -------------------------------
  -- External ports
  -------------------------------
  -- Trigger output to external
  trig_o                                   : out std_logic;

  -------------------------------
  -- Trigger input ports
  -------------------------------
  -- Trigger input from FPGA
  trig_in_i                                : in std_logic
);
end entity trigger_io_tx_datapath;

architecture rtl of trigger_io_tx_datapath is

  -- Signals
  signal trig_tx                           : t_trig_channel;
  signal trig_tx_dly                       : t_trig_channel;
  signal trig_tx_dly_extended              : t_trig_channel;

  signal trig_tx_cnt_slv                   : std_logic_vector(g_tx_counter_width-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Trigger from external
  ----------------------------------------------------------------------------
  trig_tx.pulse <= trig_in_i;

  ----------------------------------------------------------------------------
  -- Transmitter dataflow: delay pulse, extend pulse
  ----------------------------------------------------------------------------

  cmp_tx_delay_gen_dyn : delay_gen_dyn
  generic map (
    -- delay counter width
    g_delay_cnt_width                      => g_tx_delay_width)
  port map (
    -- Clock/Resets
    clk_i                                   => clk_i,
    rst_n_i                                 => rst_n_i,
    pulse_i                                 => trig_tx.pulse,
    rdy_o                                   => open,
    delay_cnt_i                             => trig_tx_delay_length_i,
    pulse_o                                 => trig_tx_dly.pulse
  );

  cmp_tx_extend_pulse : extend_pulse_dyn
    generic map (
      g_width_bus_size                     => g_tx_extensor_width)
    port map (
      clk_i                                => clk_i,
      rst_n_i                              => rst_n_i,
      pulse_i                              => trig_tx_dly.pulse,
      pulse_width_i                        => trig_tx_extensor_length_i,
      extended_o                           => trig_tx_dly_extended.pulse
  );

  trig_o <= trig_tx_dly_extended.pulse;

  ----------------------------------------------------------------------------
  -- Pulse counters
  ----------------------------------------------------------------------------

  cmp_counter_tx : counter_simple
  generic map (
    g_output_width                         => g_tx_counter_width)
  port map (
    clk_i                                  => clk_i,
    rst_n_i                                => trig_tx_rst_n_i,
    ce_i                                   => '1',
    up_i                                   => trig_tx_dly.pulse,
    down_i                                 => '0',
    count_o                                => trig_tx_cnt_slv
  );

  trig_tx_cnt_o <= unsigned(trig_tx_cnt_slv);

end rtl;
