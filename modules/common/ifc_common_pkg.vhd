library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

package ifc_common_pkg is

  -- Type that wraps all biquad coefficients (a0 = 1)
  type t_biquad_coeffs is record
    b0 : sfixed;
    b1 : sfixed;
    b2 : sfixed;
    a1 : sfixed;
    a2 : sfixed;
  end record;

  -- Type that wraps all internal biquads' coefficients (a0 = 1)
  type t_iir_filt_coeffs is array (natural range <>) of t_biquad_coeffs;

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

  component pulse2square
  port
  (
    clk_i                                    : in std_logic;
    rst_n_i                                  : in std_logic;

    -- Pulse input
    pulse_i                                  : in std_logic;
    -- Clear square
    clr_i                                    : in std_logic;
    -- square output
    square_o                                 : out std_logic
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

  component anti_windup_accumulator
    generic
    (
      g_A_WIDTH                              : natural;                           -- input width
      g_Q_WIDTH                              : natural;                           -- output width
      g_ANTI_WINDUP_UPPER_LIMIT              : signed(31 downto 0);               -- anti-windup upper limit
      g_ANTI_WINDUP_LOWER_LIMIT              : signed(31 downto 0)                -- anti-windup lower limit
    );
    port
    (
      clk_i                                  : in std_logic;                      -- clock
      rst_n_i                                : in std_logic;                      -- reset

      a_i                                    : in signed(g_A_WIDTH-1 downto 0);   -- input a
      clear_i                                : in std_logic;                      -- clear
      sum_i                                  : in std_logic;                      -- sum
      q_o                                    : out signed(g_Q_WIDTH-1 downto 0);  -- output q
      valid_o                                : out std_logic                      -- valid
    );
  end component anti_windup_accumulator;

  component prbs_gen is
    port (
      clk_i     : in std_logic;
      rst_n_i   : in std_logic;
      length_i  : in natural range 2 to 32 := 32;
      valid_i   : in std_logic;
      prbs_o    : out std_logic;
      valid_o   : out std_logic
    );
  end component prbs_gen;

  component prbs_gen_for_sys_id is
    port (
      clk_i           : in std_logic;
      rst_n_i         : in std_logic;
      en_i            : in std_logic;
      step_duration_i : in natural range 1 to 1024 := 1;
      lfsr_length_i   : in natural range 2 to 32 := 32;
      valid_i         : in std_logic;
      busy_o          : out std_logic;
      prbs_o          : out std_logic;
      valid_o         : out std_logic
    );
  end component prbs_gen_for_sys_id;

  component pulse_syncr is
    port (
      clk_i         : in std_logic;
      rst_n_i       : in std_logic;
      clr_i         : in std_logic;
      pulse_i       : in std_logic;
      sync_i        : in std_logic;
      sync_pulse_o  : out std_logic
    );
  end component pulse_syncr;

  component mov_avg_dyn is
  generic (
    g_MAX_ORDER_SEL : natural := 4;
    g_DATA_WIDTH    : natural := 32
  );
  port (
    clk_i           : in std_logic;
    rst_n_i         : in std_logic;
    order_sel_i     : in natural range 0 to g_MAX_ORDER_SEL := 0;
    data_i          : in signed(g_DATA_WIDTH-1 downto 0);
    valid_i         : in std_logic;
    avgd_data_o     : out signed(g_DATA_WIDTH-1 downto 0);
    valid_o         : out std_logic
  );
  end component mov_avg_dyn;

  component biquad is
    generic (
      g_X_INT_WIDTH       : natural;
      g_X_FRAC_WIDTH      : natural;
      g_COEFF_INT_WIDTH   : natural;
      g_COEFF_FRAC_WIDTH  : natural;
      g_Y_INT_WIDTH       : natural;
      g_Y_FRAC_WIDTH      : natural;
      g_EXTRA_BITS        : natural
    );
    port (
      clk_i               : in  std_logic;
      rst_n_i             : in  std_logic;
      x_i                 : in  sfixed(g_X_INT_WIDTH-1 downto -g_X_FRAC_WIDTH);
      x_valid_i           : in  std_logic;
      coeffs_i            : in  t_biquad_coeffs(
                                  b0(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  b1(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  b2(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  a1(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  a2(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH)
                                );

      busy_o              : out std_logic;
      y_o                 : out sfixed(g_Y_INT_WIDTH-1 downto -g_Y_FRAC_WIDTH);
      y_valid_o           : out std_logic
    );
  END COMPONENT biquad;

  component iir_filt is
    generic (
      g_MAX_FILT_ORDER    : natural;
      g_X_INT_WIDTH       : natural;
      g_X_FRAC_WIDTH      : natural;
      g_COEFF_INT_WIDTH   : natural;
      g_COEFF_FRAC_WIDTH  : natural;
      g_Y_INT_WIDTH       : natural;
      g_Y_FRAC_WIDTH      : natural;
      g_ARITH_EXTRA_BITS  : natural;
      g_IFCS_EXTRA_BITS   : natural
    );
    port (
      clk_i               : in  std_logic;
      rst_n_i             : in  std_logic;
      x_i                 : in  sfixed(g_X_INT_WIDTH-1 downto -g_X_FRAC_WIDTH);
      x_valid_i           : in  std_logic;
      coeffs_i            : in  t_iir_filt_coeffs(
                                  ((g_MAX_FILT_ORDER + 1)/2)-1 downto 0)(
                                  b0(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  b1(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  b2(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  a1(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH),
                                  a2(g_COEFF_INT_WIDTH-1 downto -g_COEFF_FRAC_WIDTH)
                                );
      busy_o              : out std_logic;
      y_o                 : out sfixed(g_Y_INT_WIDTH-1 downto -g_Y_FRAC_WIDTH);
      y_valid_o           : out std_logic
    );
  end component iir_filt;
end ifc_common_pkg;
