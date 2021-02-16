library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fmc_adc_pkg.all;
use work.textio_extended_pkg.all;

package ifc_generic_pkg is

  --------------------------------------------------------------------
  -- Components
  --------------------------------------------------------------------

  component fmc4sfp_caen
  port (
    ---------------------------------------------------------------------------
    -- FMC board pins
    ---------------------------------------------------------------------------
    sfp_rx_p_i                                 : in    std_logic_vector(3 downto 0);
    sfp_rx_n_i                                 : in    std_logic_vector(3 downto 0);
    sfp_tx_p_o                                 : out   std_logic_vector(3 downto 0);
    sfp_tx_n_o                                 : out   std_logic_vector(3 downto 0);
    sfp_scl_b                                  : inout std_logic_vector(3 downto 0);
    sfp_sda_b                                  : inout std_logic_vector(3 downto 0);
    sfp_mod_abs_i                              : in    std_logic_vector(3 downto 0);
    sfp_rx_los_i                               : in    std_logic_vector(3 downto 0);
    sfp_tx_disable_o                           : out   std_logic_vector(3 downto 0);
    sfp_tx_fault_i                             : in    std_logic_vector(3 downto 0);
    sfp_rs0_o                                  : out   std_logic_vector(3 downto 0);
    sfp_rs1_o                                  : out   std_logic_vector(3 downto 0);

    si570_clk_p_i                              : in    std_logic;
    si570_clk_n_i                              : in    std_logic;
    si570_scl_b                                : inout std_logic;
    si570_sda_b                                : inout std_logic;

    ---------------------------------------------------------------------------
    -- FPGA side. Just a bypass for now
    ---------------------------------------------------------------------------
    fpga_sfp_rx_p_o                            : out    std_logic_vector(3 downto 0);
    fpga_sfp_rx_n_o                            : out    std_logic_vector(3 downto 0);
    fpga_sfp_tx_p_i                            : in     std_logic_vector(3 downto 0);
    fpga_sfp_tx_n_i                            : in     std_logic_vector(3 downto 0);
    fpga_sfp_mod_abs_o                         : out    std_logic_vector(3 downto 0);
    fpga_sfp_rx_los_o                          : out    std_logic_vector(3 downto 0);
    fpga_sfp_tx_disable_i                      : in     std_logic_vector(3 downto 0);
    fpga_sfp_tx_fault_o                        : out    std_logic_vector(3 downto 0);
    fpga_sfp_rs0_i                             : in     std_logic_vector(3 downto 0);
    fpga_sfp_rs1_i                             : in     std_logic_vector(3 downto 0);

    fpga_si570_clk_p_o                         : out    std_logic;
    fpga_si570_clk_n_o                         : out    std_logic
  );
  end component;

  component si57x_interface
  generic (
    g_SYS_CLOCK_FREQ                           : integer := 100000000;
    g_I2C_FREQ                                 : integer := 100000;
    -- Whether or not to initialize oscilator with the specified values
    g_INIT_OSC                                 : boolean := true;
    -- Init Oscillator values
    g_INIT_RFREQ_VALUE                         : std_logic_vector(37 downto 0) := "00" & x"3017a66ad";
    g_INIT_N1_VALUE                            : std_logic_vector(6 downto 0) := "0000011";
    g_INIT_HS_VALUE                            : std_logic_vector(2 downto 0) := "111"
  );
  port (
    ---------------------------------------------------------------------------
    -- clock and reset interface
    ---------------------------------------------------------------------------
    clk_sys_i                                  : in std_logic;
    rst_n_i                                    : in std_logic;

    ---------------------------------------------------------------------------
    -- Optional external RFFREQ interface
    ---------------------------------------------------------------------------
    ext_wr_i                                   : in std_logic := '0';
    ext_rfreq_value_i                          : in std_logic_vector(37 downto 0) := (others => '0');
    ext_n1_value_i                             : in std_logic_vector(6 downto 0) := (others => '0');
    ext_hs_value_i                             : in std_logic_vector(2 downto 0) := (others => '0');

    ---------------------------------------------------------------------------
    -- Status pins
    ---------------------------------------------------------------------------
    sta_reconfig_done_o                        : out std_logic;

    ---------------------------------------------------------------------------
    -- I2C bus: output enable (active low)
    ---------------------------------------------------------------------------
    scl_pad_oen_o                              : out std_logic;
    sda_pad_oen_o                              : out std_logic;

    ---------------------------------------------------------------------------
    -- SI57x pins
    ---------------------------------------------------------------------------
    -- Optional OE control
    si57x_oe_i                                 : in std_logic := '1';
    -- Si57x slave address. Default is (slave address & '0')
    si57x_addr_i                               : in std_logic_vector(7 downto 0) := "10101010";
    si57x_oe_o                                 : out std_logic

  );
  end component;

  component rtm8sfp_ohwr
  generic (
    g_NUM_SFPS                                 : integer := 8;
    g_SYS_CLOCK_FREQ                           : integer := 100000000;
    g_SI57x_I2C_FREQ                           : integer := 400000;
    -- Whether or not to initialize oscilator with the specified values
    g_SI57x_INIT_OSC                           : boolean := true;
    -- Init Oscillator values
    g_SI57x_INIT_RFREQ_VALUE                   : std_logic_vector(37 downto 0) := "00" & x"3017a66ad";
    g_SI57x_INIT_N1_VALUE                      : std_logic_vector(6 downto 0) := "0000011";
    g_SI57x_INIT_HS_VALUE                      : std_logic_vector(2 downto 0) := "111"
  );
  port (
    ---------------------------------------------------------------------------
    -- clock and reset interface
    ---------------------------------------------------------------------------
    clk_sys_i                                  : in std_logic;
    rst_n_i                                    : in std_logic;

    ---------------------------------------------------------------------------
    -- RTM board pins
    ---------------------------------------------------------------------------
    -- SFP
    sfp_rx_p_i                                 : in    std_logic_vector(g_NUM_SFPS-1 downto 0);
    sfp_rx_n_i                                 : in    std_logic_vector(g_NUM_SFPS-1 downto 0);
    sfp_tx_p_o                                 : out   std_logic_vector(g_NUM_SFPS-1 downto 0);
    sfp_tx_n_o                                 : out   std_logic_vector(g_NUM_SFPS-1 downto 0);

    -- RTM I2C.
    -- SFP configuration pins, behind a I2C MAX7356. I2C addr = 1110_100 & '0' = 0xE8
    -- Si570 oscillator. Input 0 of CDCLVD1212. I2C addr = 1010101 & '0' = 0x55
    rtm_scl_b                                  : inout std_logic;
    rtm_sda_b                                  : inout std_logic;

    -- Si570 oscillator output enable
    si570_oe_o                                 : out   std_logic;

    -- Clock to RTM connector. Input 1 of CDCLVD1212
    rtm_sync_clk_p_o                           : out   std_logic;
    rtm_sync_clk_n_o                           : out   std_logic;

    -- Select between input 0 or 1 or CDCLVD1212. 0 is Si570, 1 is RTM sync clock
    clk_in_sel_o                               : out   std_logic;

    -- FPGA clocks from CDCLVD1212
    fpga_clk1_p_i                              : in    std_logic;
    fpga_clk1_n_i                              : in    std_logic;
    fpga_clk2_p_i                              : in    std_logic;
    fpga_clk2_n_i                              : in    std_logic;

    -- SFP status bits. Behind 4 74HC165, 8-parallel-in/serial-out. 4 x 8 bits.
    -- The PISO chips are organized like this:
    --
    -- D0: SFP1_DETECT
    -- D1: SFP1_TXFAULT
    -- D2: SFP1_LOS
    -- D3: SFP1_LED1
    -- D4: SFP2_DETECT
    -- D5: SFP2_TXFAULT
    -- D6: SFP2_LOS
    -- D7: SFP2_LED1
    --
    -- ...
    --
    -- D0: SFP7_DETECT
    -- D1: SFP7_TXFAULT
    -- D2: SFP7_LOS
    -- D3: SFP7_LED1
    -- D4: SFP8_DETECT
    -- D5: SFP8_TXFAULT
    -- D6: SFP8_LOS
    -- D7: SFP8_LED1
    --
    -- So, after parallel load, each clock will shift the chain in the reverse
    -- order: SFP8_LED1, SFP8_LOS, SFP8_TXFAULT, SFP7_DETECT, ...
    --
    -- Parallel load
    sfp_status_reg_pl_o                        : out   std_logic;
    -- Clock N
    sfp_status_reg_clk_n_o                     : out   std_logic;
    -- Serial output
    sfp_status_reg_out_i                       : in    std_logic;

    -- SFP control bits. Behind 4 74HC4094D, serial-in/8-parallel-out. 5 x 8 bits.
    -- The SIPO chips are organized like this:
    --
    -- D0: SFP1_TXDISABLE
    -- D1: SFP1_RS0
    -- D2: SFP1_RS1
    -- D3: SFP1_LED1
    -- D4: SFP2_TXDISABLE
    -- D5: SFP2_RS0
    -- D6: SFP2_RS1
    -- D7: SFP2_LED1
    --
    -- ...
    --
    -- D0: SFP7_TXDISABLE
    -- D1: SFP7_RS0
    -- D2: SFP7_RS1
    -- D3: SFP7_LED1
    -- D4: SFP8_TXDISABLE
    -- D5: SFP8_RS0
    -- D6: SFP8_RS1
    -- D7: SFP8_LED1o
    --
    -- D0: SFP1_LED2
    -- D1: SFP2_LED2
    -- D2: SFP3_LED2
    -- D3: SFP4_LED2
    -- D4: SFP5_LED2
    -- D5: SFP6_LED2
    -- D6: SFP7_LED2
    -- D7: SFP8_LED2
    --
    --
    -- So, we must shift data in reverse order: SFP8_LED2, ..., SFP1_LED2,
    -- SFP8_LED1, SFP8_RS1LOS, SFP8_TXFAULT, SFP7_DETECT, ...
    --
    -- Strobe
    sfp_ctl_reg_str_n_o                        : out   std_logic;
    -- Data input
    sfp_ctl_reg_din_n_o                        : out   std_logic;
    -- Parallel output enable
    sfp_ctl_reg_oe_n_o                         : out   std_logic;

    -- External clock from RTM to FPGA
    ext_clk_p_i                                : in    std_logic;
    ext_clk_n_i                                : in    std_logic;

    ---------------------------------------------------------------------------
    -- Optional external RFFREQ interface
    ---------------------------------------------------------------------------
    ext_wr_i                                   : in     std_logic := '0';
    ext_rfreq_value_i                          : in     std_logic_vector(37 downto 0) := (others => '0');
    ext_n1_value_i                             : in     std_logic_vector(6 downto 0) := (others => '0');
    ext_hs_value_i                             : in     std_logic_vector(2 downto 0) := (others => '0');

    ---------------------------------------------------------------------------
    -- Status pins
    ---------------------------------------------------------------------------
    sta_reconfig_done_o                        : out    std_logic;

    ---------------------------------------------------------------------------
    -- FPGA side.
    ---------------------------------------------------------------------------
    sfp_txdisable_i                            : in     std_logic_vector(7 downto 0) := (others => '0');
    sfp_rs0_i                                  : in     std_logic_vector(7 downto 0) := (others => '0');
    sfp_rs1_i                                  : in     std_logic_vector(7 downto 0) := (others => '0');

    sfp_led1_o                                 : out    std_logic_vector(7 downto 0);
    sfp_los_o                                  : out    std_logic_vector(7 downto 0);
    sfp_txfault_o                              : out    std_logic_vector(7 downto 0);
    sfp_detect_n_o                             : out    std_logic_vector(7 downto 0);

    fpga_sfp_rx_p_o                            : out    std_logic_vector(g_NUM_SFPS-1 downto 0);
    fpga_sfp_rx_n_o                            : out    std_logic_vector(g_NUM_SFPS-1 downto 0);
    fpga_sfp_tx_p_i                            : in     std_logic_vector(g_NUM_SFPS-1 downto 0);
    fpga_sfp_tx_n_i                            : in     std_logic_vector(g_NUM_SFPS-1 downto 0);

    fpga_rtm_sync_clk_p_i                      : in     std_logic := '0';
    fpga_rtm_sync_clk_n_i                      : in     std_logic := '1';

    fpga_si570_oe_i                            : in     std_logic := '1';
    fpga_si57x_addr_i                          : in     std_logic_vector(7 downto 0) := "10101010";

    fpga_clk_in_sel_i                          : in     std_logic;

    fpga_clk1_p_o                              : out    std_logic;
    fpga_clk1_n_o                              : out    std_logic;
    fpga_clk2_p_o                              : out    std_logic;
    fpga_clk2_n_o                              : out    std_logic;

    fpga_ext_clk_p_o                           : out    std_logic;
    fpga_ext_clk_n_o                           : out    std_logic
  );
  end component;

  component rtm8sfp_ohwr_serial_regs
  generic (
    g_SYS_CLOCK_FREQ                           : integer := 100000000;
    g_SERIAL_FREQ                              : integer := 100000
  );
  port (
    ---------------------------------------------------------------------------
    -- clock and reset interface
    ---------------------------------------------------------------------------
    clk_sys_i                                  : in std_logic;
    rst_n_i                                    : in std_logic;

    ---------------------------------------------------------------------------
    -- RTM serial interface
    ---------------------------------------------------------------------------
    -- Set to 1 to read and write all SFP parameters listed at the SFP
    -- parallel interface
    sfp_sta_ctl_rw_i                           : in std_logic := '1';

    sfp_status_reg_clk_n_o                     : out std_logic;
    sfp_status_reg_out_i                       : in std_logic;
    sfp_status_reg_pl_o                        : out std_logic;

    sfp_ctl_reg_oe_n_o                         : out std_logic;
    sfp_ctl_reg_din_n_o                        : out std_logic;
    sfp_ctl_reg_str_n_o                        : out std_logic;

    ---------------------------------------------------------------------------
    -- SFP parallel interface
    ---------------------------------------------------------------------------
    sfp_led1_o                                 : out std_logic_vector(7 downto 0);
    sfp_los_o                                  : out std_logic_vector(7 downto 0);
    sfp_txfault_o                              : out std_logic_vector(7 downto 0);
    sfp_detect_n_o                             : out std_logic_vector(7 downto 0);
    sfp_txdisable_i                            : in std_logic_vector(7 downto 0);
    sfp_rs0_i                                  : in std_logic_vector(7 downto 0);
    sfp_rs1_i                                  : in std_logic_vector(7 downto 0);
    sfp_led1_i                                 : in std_logic_vector(7 downto 0);
    sfp_led2_i                                 : in std_logic_vector(7 downto 0)
  );
  end component;

end ifc_generic_pkg;
