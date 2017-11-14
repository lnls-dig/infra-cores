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
      pulse_o : out std_logic);
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

end ifc_common_pkg;
