library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package trigger_io_pkg is

  -- Components
  component trigger_io_physical
  generic
  (
    -- "true" to use external bidirectional trigger (*_b port) or "false"
    -- to use separate ports for external trigger input/output
    g_with_bidirectional_trigger             : boolean := true;
    -- IOBUF instantiation type if g_with_bidirectional_trigger = true.
    -- Possible values are: "native" or "inferred"
    g_iobuf_instantiation_type               : string := "native";
    -- Wired-OR implementation if g_with_wired_or_driver = true.
    -- Possible values are: true or false
    g_with_wired_or_driver                   : boolean := true
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
    -- of trig_tx_o and trig_ext_dir_o. Set to '1' to use
    -- reverse polarity between the internal FPGA IO buffer and
    -- a possibly external IO buffer. Set to '0' to use the same
    -- polarity. If not using an external buffer, just leave it
    -- to '0'
    trig_ext_dir_pol_i                       : in std_logic;
    -- Output trigger polarity. Set to '1' to use reverse polarity
    -- ('1' to '0' output pulse). Set to '0' to use regular polarity
    -- ('0' to '1' output pulse)
    trig_pol_i                               : in std_logic;

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
    trig_out_o                               : out std_logic
  );
  end component;

  component trigger_io_rx_datapath
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
  end component;

  component trigger_io_tx_datapath
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
  end component;

end trigger_io_pkg;
