-------------------------------------------------------------------------------
-- Title      : Trigger I/O
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_io.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-11-14
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Send/Receives trigger to/from a hardware line. It supports,
-- debouncing, extension, polarity, direction control and controllable delay.
--
-- It implements the wired-OR logic with trigger lines, as described
-- in www.ti.com/lit/pdf/snla113, page 11. It works as follows:
--
-- If we want to output data, we use the direction pin as data and
-- drive the actual output to HI. This would only drive the line
-- when we send data.
--
-- If we want to input data, we use the pins as usual: data as data and
-- direction as direction.
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
use work.trigger_io_pkg.all;

entity trigger_io is
generic
(
  -- "true" to use external bidirectional trigger (*_b port) or "false"
  -- to use separate ports for external trigger input/output
  g_with_bidirectional_trigger             : boolean := true;
  -- IOBUF instantiation type if g_with_bidirectional_trigger = true.
  -- Possible values are: "native" or "inferred"
  g_iobuf_instantiation_type               : string := "native";
  -- Sync pulse on "positive" or "negative" edge of incoming pulse
  g_sync_edge                              : string  := "positive";
  -- Length of receive debounce counters
  g_rx_debounce_width                      : natural := 8;
  -- Length of transmitter extensor counters
  g_tx_extensor_width                      : natural := 8;
  -- Length of receive counters
  g_rx_counter_width                       : natural := 8;
  -- Length of transmitter counters
  g_tx_counter_width                       : natural := 8;
  -- Length of receiving delay counters
  g_rx_delay_width                 : natural := 32;
  -- Length of transmitter delay counters
  g_tx_delay_width                 : natural := 32
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -------------------------------
  -- Trigger configuration
  -------------------------------
  -- Trigger direction. Set to '1' to 1 will set the FPGA
  -- to output and set to '0' will set the
  -- FPGA to input
  trig_dir_i                               : in std_logic;
  -- External direction polarity. This affects the behavior
  -- of trig_data_o and trig_ext_dir_o. Set to '1' to use
  -- reverse polarity between the internal FPGA IO buffer and
  -- a possibly external IO buffer. Set to '0' to use the same
  -- polarity. If not using an external buffer, just leave it
  -- to '0'
  trig_ext_dir_pol_i                       : in std_logic;
  -- Output trigger polarity. Set to '1' to use reverse polarity
  -- ('1' to '0' output pulse). Set to '0' to use regular polarity
  -- ('0' to '1' output pulse)
  trig_pol_i                               : in std_logic;
  -- Receive debounce clocks
  trig_rx_debounce_length_i                : in unsigned(g_rx_debounce_width-1 downto 0);
  -- Transmitter extensor clocks
  trig_tx_extensor_length_i                : in unsigned(g_tx_extensor_width-1 downto 0);
  -- Number of clocks to delay an incoming trigger pulse
  trig_rx_delay_length_i                   : in unsigned(g_rx_delay_width-1 downto 0);
  -- Number of detected transmitted triggers to external module
  trig_tx_delay_length_i                   : in unsigned(g_tx_delay_width-1 downto 0);

  -------------------------------
  -- Counters
  -------------------------------
  -- Reset receiving counter
  trig_rx_rst_n_i                          : in std_logic;
  -- Reset transmitte counter
  trig_tx_rst_n_i                          : in std_logic;
  -- Number of detected received triggers from external module
  trig_rx_cnt_o                            : out unsigned(g_rx_counter_width-1 downto 0);
  -- Number of detected transmitted triggers to external module
  trig_tx_cnt_o                            : out unsigned(g_tx_counter_width-1 downto 0);

  -------------------------------
  ---- External ports
  -------------------------------
  trig_dir_o                               : out std_logic;
  -- If using g_with_bidirectional_trigger = true
  trig_b                                   : inout std_logic := '0';
  -- If using g_with_bidirectional_trigger = false
  trig_i                                   : in std_logic := '0';
  trig_o                                   : out std_logic;

  -------------------------------
  -- Trigger input/output ports
  -------------------------------
  -- Trigger data input from FPGA
  trig_in_i                                : in std_logic;
  -- Trigger data output from FPGA
  trig_out_o                               : out std_logic;

  -------------------------------
  -- Debug ports
  -------------------------------
  trig_dbg_o                               : out std_logic
);
end entity trigger_io;

architecture rtl of trigger_io is

  signal trig_in_phys                      : std_logic;
  signal trig_out_phys                     : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Physical connection
  ----------------------------------------------------------------------------
  cmp_trigger_io_physical : trigger_io_physical
  generic map (
    g_with_bidirectional_trigger           => g_with_bidirectional_trigger,
    g_iobuf_instantiation_type             => g_iobuf_instantiation_type
  )
  port map (
    clk_i                                  => clk_i,
    rst_n_i                                => rst_n_i,

    -------------------------------
    -- Trigger configuration
    -------------------------------
    trig_dir_i                             => trig_dir_i,
    trig_ext_dir_pol_i                     => trig_ext_dir_pol_i,
    trig_pol_i                             => trig_pol_i,

    -------------------------------
    ---- External ports
    -------------------------------
    trig_dir_o                             => trig_dir_o,
    trig_b                                 => trig_b,
    trig_i                                 => trig_i,
    trig_o                                 => trig_o,

    -------------------------------
    -- Trigger input/output ports
    -------------------------------
    trig_in_i                              => trig_in_phys,
    trig_out_o                             => trig_out_phys
  );

  trig_dbg_o <= trig_out_phys;

  -----------------------------------------------------------------------------
  -- RX datapath
  ----------------------------------------------------------------------------
  cmp_trigger_io_rx_datapath : trigger_io_rx_datapath
  generic map (
    g_sync_edge                              => g_sync_edge,
    g_rx_debounce_width                      => g_rx_debounce_width,
    g_rx_counter_width                       => g_rx_counter_width,
    g_rx_delay_width                         => g_rx_delay_width
  )
  port map (
    -- Clock/Resets
    clk_i                                    => clk_i,
    rst_n_i                                  => rst_n_i,

    -------------------------------
    -- Trigger RX configuration
    -------------------------------
    trig_rx_debounce_length_i                => trig_rx_debounce_length_i,
    trig_rx_delay_length_i                   => trig_rx_delay_length_i,

    -------------------------------
    -- Counters
    -------------------------------
    trig_rx_rst_n_i                          => trig_rx_rst_n_i,
    trig_rx_cnt_o                            => trig_rx_cnt_o,

    -------------------------------
    -- External ports
    -------------------------------
    trig_i                                   => trig_out_phys,

    -------------------------------
    -- Trigger output ports
    -------------------------------
    trig_out_o                               => trig_out_o
  );

  -----------------------------------------------------------------------------
  -- TX datapath
  ----------------------------------------------------------------------------
  cmp_trigger_io_tx_datapath : trigger_io_tx_datapath
  generic map (
    g_tx_extensor_width                      => g_tx_extensor_width,
    g_tx_counter_width                       => g_tx_counter_width,
    g_tx_delay_width                         => g_tx_delay_width
  )
  port map (
    -- Clock/Resets
    clk_i                                    => clk_i,
    rst_n_i                                  => rst_n_i,

    -------------------------------
    -- Trigger TX configuration
    -------------------------------
    trig_tx_extensor_length_i                => trig_tx_extensor_length_i,
    trig_tx_delay_length_i                   => trig_tx_delay_length_i,

    -------------------------------
    -- Counters
    -------------------------------
    trig_tx_rst_n_i                          => trig_tx_rst_n_i,
    trig_tx_cnt_o                            => trig_tx_cnt_o,

    -------------------------------
    -- External ports
    -------------------------------
    trig_o                                   => trig_in_phys,

    -------------------------------
    -- Trigger input ports
    -------------------------------
    trig_in_i                                => trig_in_i
  );

end rtl;
