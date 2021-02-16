------------------------------------------------------------------------------
-- Title      : RTM 8 SFP Board Controller
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2020-12-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: RTM 8 SFP Board Controller.
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2020-12-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_generic_pkg.all;

entity rtm8sfp_ohwr is
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
end rtm8sfp_ohwr;

architecture rtl of rtm8sfp_ohwr is

  signal scl_pad_oen                         : std_logic;
  signal sda_pad_oen                         : std_logic;

  signal sfp_led1_in                        : std_logic_vector(7 downto 0);
  signal sfp_led2_in                        : std_logic_vector(7 downto 0);
  signal sfp_los                             : std_logic_vector(7 downto 0);
  signal sfp_detect_n                        : std_logic_vector(7 downto 0);

begin

  -- Simple bypass for now
  fpga_sfp_rx_p_o     <= sfp_rx_p_i;
  fpga_sfp_rx_n_o     <= sfp_rx_n_i;
  sfp_tx_p_o          <= fpga_sfp_tx_p_i;
  sfp_tx_n_o          <= fpga_sfp_tx_n_i;

  rtm_sync_clk_p_o    <= fpga_rtm_sync_clk_p_i;
  rtm_sync_clk_n_o    <= fpga_rtm_sync_clk_n_i;

  clk_in_sel_o        <= fpga_clk_in_sel_i;

  fpga_clk1_p_o        <= fpga_clk1_p_i;
  fpga_clk1_n_o        <= fpga_clk1_n_i;
  fpga_clk2_p_o        <= fpga_clk2_p_i;
  fpga_clk2_n_o        <= fpga_clk2_n_i;

  fpga_ext_clk_p_o     <=  ext_clk_p_i;
  fpga_ext_clk_n_o     <=  ext_clk_n_i;

  ---------------------------------------------------------------------------
  -- SI57x control. The same I2C is used to access 8 SFPs I2C configuration pins,
  -- but those are going to be ignored for now.
  ---------------------------------------------------------------------------

  cmp_si57x_interface : si57x_interface
  generic map (
    g_SYS_CLOCK_FREQ                           => g_SYS_CLOCK_FREQ,
    g_I2C_FREQ                                 => g_SI57x_I2C_FREQ,
    g_INIT_OSC                                 => g_SI57x_INIT_OSC,
    g_INIT_RFREQ_VALUE                         => g_SI57x_INIT_RFREQ_VALUE,
    g_INIT_N1_VALUE                            => g_SI57x_INIT_N1_VALUE,
    g_INIT_HS_VALUE                            => g_SI57x_INIT_HS_VALUE
  )
  port map (
    ---------------------------------------------------------------------------
    -- clock and reset interface
    ---------------------------------------------------------------------------
    clk_sys_i                                  => clk_sys_i,
    rst_n_i                                    => rst_n_i,

    ---------------------------------------------------------------------------
    -- Optional external RFFREQ interface
    ---------------------------------------------------------------------------
    ext_wr_i                                   => ext_wr_i,
    ext_rfreq_value_i                          => ext_rfreq_value_i,
    ext_n1_value_i                             => ext_n1_value_i,
    ext_hs_value_i                             => ext_hs_value_i,

    ---------------------------------------------------------------------------
    -- Status pins
    ---------------------------------------------------------------------------
    sta_reconfig_done_o                        => sta_reconfig_done_o,

    ---------------------------------------------------------------------------
    -- I2C bus: output enable (active low)
    ---------------------------------------------------------------------------
    scl_pad_oen_o                              => scl_pad_oen,
    sda_pad_oen_o                              => sda_pad_oen,

    ---------------------------------------------------------------------------
    -- SI57x pins
    ---------------------------------------------------------------------------
    -- Optional OE control
    si57x_oe_i                                 => fpga_si570_oe_i,
    si57x_addr_i                               => fpga_si57x_addr_i,
    si57x_oe_o                                 => si570_oe_o
  );

  -- No input reading
  rtm_scl_b <= '0' when scl_pad_oen = '0' else 'Z';
  rtm_sda_b <= '0' when sda_pad_oen = '0' else 'Z';

  cmp_rtm_status_and_ctrl : rtm8sfp_ohwr_serial_regs
  port map(
    ---------------------------------------------------------------------------
    -- clock and reset interface
    ---------------------------------------------------------------------------
    clk_sys_i                                => clk_sys_i,
    rst_n_i                                  => rst_n_i,

   ---------------------------------------------------------------------------
   -- RTM serial interface
   ---------------------------------------------------------------------------
    sfp_sta_ctl_rw_i                        => '1',

    sfp_status_reg_clk_n_o                  => sfp_status_reg_clk_n_o,
    sfp_status_reg_out_i                    => sfp_status_reg_out_i,
    sfp_status_reg_pl_o                     => sfp_status_reg_pl_o,

    sfp_ctl_reg_oe_n_o                      => sfp_ctl_reg_oe_n_o,
    sfp_ctl_reg_din_n_o                     => sfp_ctl_reg_din_n_o,
    sfp_ctl_reg_str_n_o                     => sfp_ctl_reg_str_n_o,

    ---------------------------------------------------------------------------
    -- SFP parallel interface
    ---------------------------------------------------------------------------
    sfp_led1_o                              => sfp_led1_o,
    sfp_los_o                               => sfp_los,
    sfp_txfault_o                           => sfp_txfault_o,
    sfp_detect_n_o                          => sfp_detect_n,
    sfp_txdisable_i                         => sfp_txdisable_i,
    sfp_rs0_i                               => sfp_rs0_i,
    sfp_rs1_i                               => sfp_rs1_i,
    sfp_led1_i                              => sfp_led1_in,
    sfp_led2_i                              => sfp_led2_in
  );

  sfp_led1_in <= not sfp_los;
  sfp_led2_in <= sfp_detect_n;

  sfp_detect_n_o <= sfp_detect_n;
  sfp_los_o <= sfp_los;

end rtl;
