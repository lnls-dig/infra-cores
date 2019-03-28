library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package ifc_common_pkg is

  --------------------------------------------------------------------
  -- Components
  --------------------------------------------------------------------

  component reset_synch
  generic
  (
    -- Select 1 for no pipeline, and greater than 1 to insert
    -- pipeline stages
    g_pipeline                             : natural := 4
  );
  port
  (
    clk_i                                  : in  std_logic;
    arst_n_i                               : in  std_logic;
    rst_n_o                                : out std_logic
  );
  end component;

  component pulse2level
  port
  (
    clk_i                                  : in std_logic;
    rst_n_i                                : in std_logic;

    -- Pulse input
    pulse_i                                : in std_logic;
    -- Clear level
    clr_i                                  : in std_logic;
    -- Level output
    level_o                                : out std_logic
  );
  end component;


  component trigger_rcv is
    generic (
      g_glitch_len_width : positive;
      g_sync_edge        : string);
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      len_i   : in  std_logic_vector(g_glitch_len_width-1 downto 0);
      data_i  : in  std_logic;
      pulse_o : out std_logic;
      dbg_data_sync_o        : out std_logic;
      dbg_data_degliteched_o : out std_logic);
  end component trigger_rcv;

  component extend_pulse_dyn is
    generic (
      g_width_bus_size : natural);
    port (
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      pulse_i       : in  std_logic;
      pulse_width_i : in  unsigned(g_width_bus_size-1 downto 0);
      extended_o    : out std_logic := '0');
  end component extend_pulse_dyn;

  component counter_simple is
    generic (
      g_output_width : positive);
    port (
      clk_i   : in  std_logic;
      rst_n_i : in  std_logic;
      ce_i    : in  std_logic;
      up_i    : in  std_logic;
      down_i  : in  std_logic;
      count_o : out std_logic_vector(g_output_width-1 downto 0));
  end component counter_simple;

  component heartbeat
  generic
  (
    -- number of system clock cycles to count before blinking
    g_clk_counts                             : natural := 100000000
  );
  port
  (
    -- 100 MHz system clock
    clk_i                                    : in std_logic;
    rst_n_i                                  : in std_logic;

    -- Heartbeat pulse output
    heartbeat_o                              : out std_logic
  );
  end component;

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

  component trigger_io
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
    g_rx_delay_width                         : natural := 32;
    -- Length of transmitter delay counters
    g_tx_delay_width                         : natural := 32
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
  end component;

end ifc_common_pkg;
