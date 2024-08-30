------------------------------------------------------------------------------
-- Title      : Wishbone FMC130m_4ch Interface
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2013-19-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Top Module for the FMC130m_4ch ADC board interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-19-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- Custom Wishbone Modules
use work.ifc_wishbone_pkg.all;
-- Wishbone Stream Interface
--use work.wb_stream_pkg.all;
use work.wb_stream_generic_pkg.all;
-- Register interface
use work.wb_fmc_130m_4ch_csr_wbgen2_pkg.all;
-- Wishbone FMC ADC Common Register Interface
use work.wb_fmc_adc_common_csr_wbgen2_pkg.all;
-- FMC ADC package
use work.fmc_adc_pkg.all;
-- Reset Synch
use work.ifc_common_pkg.all;
-- General common cores
use work.gencores_pkg.all;

-- For Xilinx primitives
library unisim;
use unisim.vcomponents.all;

--package wb_stream_64_pkg is new wb_stream_generic_pkg
--   generic map (type => std_logic_vector(63 downto 0));

entity wb_fmc130m_4ch is
generic
(
    -- The only supported values are VIRTEX6 and 7SERIES
  g_fpga_device                             : string := "VIRTEX6";
  g_delay_type                              : string := "VARIABLE";
  g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
  g_address_granularity                     : t_wishbone_address_granularity := WORD;
  g_with_extra_wb_reg                       : boolean := false;
  g_adc_clk_period_values                   : t_clk_values_array := default_adc_clk_period_values;
  g_use_clk_chains                          : t_clk_use_chain := default_clk_use_chain;
  g_with_bufio_clk_chains                   : t_clk_use_bufio_chain := default_clk_use_bufio_chain;
  g_with_bufr_clk_chains                    : t_clk_use_bufr_chain := default_clk_use_bufr_chain;
  g_with_idelayctrl                         : boolean := true;
  g_use_data_chains                         : t_data_use_chain := default_data_use_chain;
  g_map_clk_data_chains                     : t_map_clk_data_chain := default_map_clk_data_chain;
  g_ref_clk                                 : t_ref_adc_clk := default_ref_adc_clk;
  g_packet_size                             : natural := 32;
  g_sim                                     : integer := 0
);
port
(
  sys_clk_i                                 : in std_logic;
  sys_rst_n_i                               : in std_logic;
  sys_clk_200Mhz_i                          : in std_logic;

  -----------------------------
  -- Wishbone Control Interface signals
  -----------------------------

  wb_adr_i                                  : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
  wb_dat_i                                  : in  std_logic_vector(c_wishbone_data_width-1 downto 0) := (others => '0');
  wb_dat_o                                  : out std_logic_vector(c_wishbone_data_width-1 downto 0);
  wb_sel_i                                  : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0) := (others => '0');
  wb_we_i                                   : in  std_logic := '0';
  wb_cyc_i                                  : in  std_logic := '0';
  wb_stb_i                                  : in  std_logic := '0';
  wb_ack_o                                  : out std_logic;
  wb_err_o                                  : out std_logic;
  wb_rty_o                                  : out std_logic;
  wb_stall_o                                : out std_logic;

  -----------------------------
  -- External ports
  -----------------------------

  -- ADC LTC2208 interface
  fmc_adc_pga_o                             : out std_logic;
  fmc_adc_shdn_o                            : out std_logic;
  fmc_adc_dith_o                            : out std_logic;
  fmc_adc_rand_o                            : out std_logic;

  -- ADC0 LTC2208
  fmc_adc0_clk_i                            : in std_logic := '0';
  fmc_adc0_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0) := (others => '0');
  fmc_adc0_of_i                             : in std_logic := '0'; -- Unused

  -- ADC1 LTC2208
  fmc_adc1_clk_i                            : in std_logic := '0';
  fmc_adc1_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0) := (others => '0');
  fmc_adc1_of_i                             : in std_logic := '0'; -- Unused

  -- ADC2 LTC2208
  fmc_adc2_clk_i                            : in std_logic := '0';
  fmc_adc2_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0) := (others => '0');
  fmc_adc2_of_i                             : in std_logic := '0'; -- Unused

  -- ADC3 LTC2208
  fmc_adc3_clk_i                            : in std_logic;
  fmc_adc3_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0) := (others => '0');
  fmc_adc3_of_i                             : in std_logic := '0'; -- Unused

  -- FMC General Status
  fmc_prsnt_i                               : in std_logic := '0';
  fmc_pg_m2c_i                              : in std_logic := '0';
  --fmc_clk_dir_i                           : in std_logic;, -- not supported on Kintex7 KC705 board

  -- Trigger
  fmc_trig_dir_o                            : out std_logic;
  fmc_trig_term_o                           : out std_logic;
  fmc_trig_val_p_b                          : inout std_logic;
  fmc_trig_val_n_b                          : inout std_logic;

  -- Si571 clock gen
  si571_scl_pad_b                           : inout std_logic;
  si571_sda_pad_b                           : inout std_logic;
  fmc_si571_oe_o                            : out std_logic;

  -- AD9510 clock distribution PLL
  spi_ad9510_cs_o                           : out std_logic;
  spi_ad9510_sclk_o                         : out std_logic;
  spi_ad9510_mosi_o                         : out std_logic;
  spi_ad9510_miso_i                         : in std_logic := '0';

  fmc_pll_function_o                        : out std_logic;
  fmc_pll_status_i                          : in std_logic := '0';

  -- AD9510 clock copy
  fmc_fpga_clk_p_i                          : in std_logic := '0';
  fmc_fpga_clk_n_i                          : in std_logic := '0';

  -- Clock reference selection (TS3USB221)
  fmc_clk_sel_o                             : out std_logic;

  -- EEPROM
  eeprom_scl_pad_b                          : inout std_logic;
  eeprom_sda_pad_b                          : inout std_logic;

  -- Temperature monitor
  -- LM75AIMM
  lm75_scl_pad_b                            : inout std_logic;
  lm75_sda_pad_b                            : inout std_logic;

  fmc_lm75_temp_alarm_i                     : in std_logic := '0';

  -- FMC LEDs
  fmc_led1_o                                : out std_logic;
  fmc_led2_o                                : out std_logic;
  fmc_led3_o                                : out std_logic;

  -----------------------------
  -- Optional external reference clock ports
  -----------------------------
  fmc_ext_ref_clk_i                        : in std_logic := '0';
  fmc_ext_ref_clk2x_i                      : in std_logic := '0';
  fmc_ext_ref_mmcm_locked_i                : in std_logic := '0';

  -----------------------------
  -- ADC output signals. Continuous flow
  -----------------------------
  adc_clk_o                                 : out std_logic_vector(c_num_adc_channels-1 downto 0);
  adc_clk2x_o                               : out std_logic_vector(c_num_adc_channels-1 downto 0);
  adc_rst_n_o                               : out std_logic_vector(c_num_adc_channels-1 downto 0);
  adc_rst2x_n_o                             : out std_logic_vector(c_num_adc_channels-1 downto 0);
  adc_data_o                                : out std_logic_vector(c_num_adc_channels*c_num_adc_bits-1 downto 0);
  adc_data_valid_o                          : out std_logic_vector(c_num_adc_channels-1 downto 0);

  -----------------------------
  -- General ADC output signals and status
  -----------------------------
  -- Trigger to other FPGA logic
  trig_hw_o                                 : out std_logic;
  trig_hw_i                                 : in std_logic := '0';

  -- General board status
  fmc_mmcm_lock_o                           : out std_logic;
  fmc_pll_status_o                          : out std_logic;

  -----------------------------
  -- Wishbone Streaming Interface Source
  -----------------------------
  wbs_adr_o                                 : out std_logic_vector(c_num_adc_channels*c_wbs_adr4_width-1 downto 0);
  wbs_dat_o                                 : out std_logic_vector(c_num_adc_channels*c_wbs_dat16_width-1 downto 0);
  wbs_cyc_o                                 : out std_logic_vector(c_num_adc_channels-1 downto 0);
  wbs_stb_o                                 : out std_logic_vector(c_num_adc_channels-1 downto 0);
  wbs_we_o                                  : out std_logic_vector(c_num_adc_channels-1 downto 0);
  wbs_sel_o                                 : out std_logic_vector(c_num_adc_channels*c_wbs_sel16_width-1 downto 0);
  wbs_ack_i                                 : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
  wbs_stall_i                               : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
  wbs_err_i                                 : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
  wbs_rty_i                                 : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');

  adc_dly_debug_o                           : out t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);

  fifo_debug_valid_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0);
  fifo_debug_full_o                         : out std_logic_vector(c_num_adc_channels-1 downto 0);
  fifo_debug_empty_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0)
);
end wb_fmc130m_4ch;

architecture rtl of wb_fmc130m_4ch is

  -- Slightly different behaviour than the one located at wishbone_pkg.vhd.
  -- The original f_ceil_log2 returns 0 for x <= 1. We cannot allow this,
  -- as we must have at least one bit size, for x > 0
  function f_ceil_log2(x : natural) return natural is
  begin
    if x <= 2
    then return 1;
    else return f_ceil_log2((x+1)/2) +1;
    end if;
  end f_ceil_log2;

  -----------------------------
  -- General Contants
  -----------------------------
  -- Number packet size counter bits
  constant c_packet_num_bits                : natural := f_packet_num_bits(g_packet_size);
  -- Numbert of bits in Wishbone register interface. Plus 2 to account for BYTE addressing
  constant c_periph_addr_size               : natural := 4+2;
  constant c_periph_acommon_addr_size       : natural := 2+2;
  constant c_first_used_clk                 : natural := f_first_used_clk(g_use_clk_chains);
  constant c_ref_clk                        : natural := f_adc_ref_clk(g_ref_clk);
  constant c_with_clk_single_ended          : boolean := true;
  constant c_with_data_single_ended         : boolean := true;
  constant c_with_data_sdr                  : boolean := true;
  constant c_with_fn_dly_select             : boolean := true;
  constant c_with_idelay_var_loadable       : boolean := true;
  constant c_with_idelay_variable           : boolean := false;

  -- 130 MHz parameters. Generate 2x input clock
  constant c_mmcm_param                     : t_mmcm_param :=
                                   (1, 8.000, g_adc_clk_period_values(c_ref_clk), 8.000, 4);
  --constant c_mmcm_param                     : t_mmcm_param :=
  --                                 (1, 8.000, g_adc_clk_period_values(c_ref_clk), 8.000, 8);

  -----------------------------
  -- Crossbar component constants
  -----------------------------
  -- Internal crossbar layout
  -- 0 -> FMC130_4CH Register Wishbone Interface
  -- 1 -> FMC ADC Common
  -- 2 -> FMC Active Clock
  -- 3 -> EEPROM I2C Bus.
  -- 4 -> LM75A I2C Bus.
  -- Number of slaves
  constant c_slaves                         : natural := 5;
  -- Number of masters
  constant c_masters                        : natural := 1;            -- Top master.

  constant c_fmc_active_clk_bridge_sdb : t_sdb_bridge := f_xwb_bridge_manual_sdb(x"00000FFF", x"00000300");

  -- WB SDB (Self describing bus) layout
  constant c_layout : t_sdb_record_array(c_slaves-1 downto 0) :=
  ( 0 => f_sdb_embed_device(c_xwb_fmc130m_4ch_regs_sdb, x"00000000"),   -- Register interface
    1 => f_sdb_embed_device(c_xwb_fmc_adc_common_regs_sdb,
                                                        x"00001000"),   -- FMC ADC Common
    2 => f_sdb_embed_bridge(c_fmc_active_clk_bridge_sdb,
                                                        x"00002000"),   -- FMC Active Clock
    3 => f_sdb_embed_device(c_xwb_i2c_master_sdb,       x"00003000"),   -- EEPROM I2C
    4 => f_sdb_embed_device(c_xwb_i2c_master_sdb,       x"00004000")    -- LM75A I2C
  );

  -- Self Describing Bus ROM Address. It will be an addressed slave as well.
  constant c_sdb_address                    : t_wishbone_address := x"00006000";

  -----------------------------
  -- Clock and reset signals
  -----------------------------
  signal sys_rst_n                          : std_logic;
  signal sys_rst_sync_n                     : std_logic;
  --signal adc_clk_chain_rst                  : std_logic;

  -----------------------------
  -- Wishbone Register Interface signals
  -----------------------------
  -- FMC130m_4ch reg structure
  signal regs_out                           : t_wb_fmc_130m_4ch_csr_out_registers;
  signal regs_in                            : t_wb_fmc_130m_4ch_csr_in_registers;

  -- FMC ADC Common reg structure
  signal regs_acommon_out                   : t_wb_fmc_adc_common_csr_out_registers;
  signal regs_acommon_in                    : t_wb_fmc_adc_common_csr_in_registers;

  -----------------------------
  -- ADC Interface signals
  -----------------------------
  --signal fs_clk                             : std_logic;
  signal fs_rst_n                           : std_logic;
  signal fs_rst_sync_n                      : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal fs_rst2x_sync_n                    : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal adc_rst                            : std_logic; -- ADC reset from wishbone
  signal mmcm_adc_locked                    : std_logic;
  signal mmcm_rst_reg                       : std_logic;

  -- ADC clock + data single ended inputs
  signal adc_in                             : t_adc_sdr_in_array(c_num_adc_channels-1 downto 0);
  signal adc_in_dummy                       : t_adc_in_array(c_num_adc_channels-1 downto 0) :=
                                                (0 => ('0', '0', (others => '0')),
                                                 1 => ('0', '0', (others => '0')),
                                                 2 => ('0', '0', (others => '0')),
                                                 3 => ('0', '0', (others => '0'))
                                                 );

  signal adc_clk0                           : std_logic;
  signal adc_clk1                           : std_logic;
  signal adc_clk2                           : std_logic;
  signal adc_clk3                           : std_logic;

  signal adc_data_ch0                       : std_logic_vector(f_num_adc_pins(c_with_data_sdr)-1 downto 0);
  signal adc_data_ch1                       : std_logic_vector(f_num_adc_pins(c_with_data_sdr)-1 downto 0);
  signal adc_data_ch2                       : std_logic_vector(f_num_adc_pins(c_with_data_sdr)-1 downto 0);
  signal adc_data_ch3                       : std_logic_vector(f_num_adc_pins(c_with_data_sdr)-1 downto 0);

  -- ADC fine delay signals.
  signal adc_fn_dly_in                      : t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);
  signal adc_idelay_rdy                     : std_logic;
  signal adc_idelay_update_or               : std_logic;
  --signal adc_fn_dly_in_int                  : t_adc_fn_dly_int_array(c_num_adc_channels-1 downto 0);
  signal adc_fn_dly_wb_ctl_out              : t_adc_fn_dly_wb_ctl_array(c_num_adc_channels-1 downto 0);
  signal adc_fn_dly_out                     : t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);
  -- ADC coarse delay signals.
  signal adc_cs_dly_in                      : t_adc_cs_dly_array(c_num_adc_channels-1 downto 0);
  signal adc_cs_dly_in_int                  : t_adc_cs_dly_array(c_num_adc_channels-1 downto 0);
  -- ADC output signals.
  signal adc_out                            : t_adc_out_array(c_num_adc_channels-1 downto 0);

  -- ADC test data enable
  signal adc_test_data_en                   : std_logic;

  -- ADC Clock/Data variable delay interface internal structure
  signal adc_dly_pulse_clk_int              : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal adc_dly_pulse_data_int             : std_logic_vector(c_num_adc_channels-1 downto 0);


  -- Signals for adc internal use
  --signal adc_clk_int                        : std_logic_vector(c_num_adc_bits-1 downto 0);
  signal fs_clk                             : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal fs_clk2x                           : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal adc_valid                          : std_logic_vector(c_num_adc_channels-1 downto 0);
  signal adc_data                           : std_logic_vector(c_num_adc_bits*c_num_adc_channels-1 downto 0);

  -- Optional reference clock
  signal adc_ext_glob_clk_int               : t_adc_clk_chain_glob;

  -- ADC Reset signals
  signal adc_clk_div_rst_int                : std_logic;
  signal adc_clk_div_rst_int_p              : std_logic;
  signal fmc_reset_adcs_int                 : std_logic;

  -----------------------------
  -- Test data signals and constants
  -----------------------------
  -- Counter width. It willl count up to 2^32 clock cycles
  constant c_counter_width                  : natural := 16;
  -- 100MHz period or 1 second
  constant c_counter_full                   : natural := 1000000;
  -- Offset between adjacent test data channels
  constant c_offset_test_data               : natural := 10;
  -- Counter signal
  type t_wbs_test_data_array is array(natural range<>) of unsigned(c_counter_width-1 downto 0);

  signal wbs_test_data                      : t_wbs_test_data_array(c_num_adc_channels-1 downto 0);

  -----------------------------
  -- Wishbone Streaming control signals
  -----------------------------
  type t_wbs_dat16_array is array(natural range<>) of std_logic_vector(c_wbs_dat16_width-1 downto 0);
  type t_wbs_valid16_array is array(natural range<>) of std_logic;

  signal wbs_dat                            : t_wbs_dat16_array(c_num_adc_channels-1 downto 0);
  signal wbs_valid                          : t_wbs_valid16_array(c_num_adc_channels-1 downto 0);
  signal wbs_adr                            : std_logic_vector(c_wbs_adr4_width-1 downto 0);
  --signal wbs_dat                            : std_logic_vector(c_wbs_dat16_width-1 downto 0);
  --signal wbs_dvalid                         : std_logic;
  signal wbs_sof                            : std_logic;
  signal wbs_eof                            : std_logic;
  signal wbs_error                          : std_logic;
  signal wbs_sel                            : std_logic_vector(c_wbs_sel16_width-1 downto 0);

  -- Wishbone Streaming interface structure
  signal wbs_stream_out                     : t_wbs_source_out16_array(c_num_adc_channels-1 downto 0);
  signal wbs_stream_in                      : t_wbs_source_in16_array(c_num_adc_channels-1 downto 0);

  -----------------------------
  -- Wishbone slave adapter signals/structures
  -----------------------------
  signal wb_slv_adp_out                     : t_wishbone_master_out;
  signal wb_slv_adp_in                      : t_wishbone_master_in;
  signal resized_addr                       : std_logic_vector(c_wishbone_address_width-1 downto 0);

  signal wb_slv_adp_acommon_out             : t_wishbone_master_out;
  signal wb_slv_adp_acommon_in              : t_wishbone_master_in;
  signal resized_acommon_addr               : std_logic_vector(c_wishbone_address_width-1 downto 0);

  -----------------------------
  -- Wishbone crossbar signals
  -----------------------------
  --signal wb_out                           : t_wishbone_master_in_array(0 to c_num_int_slaves-1);
  --signal wb_in                            : t_wishbone_master_out_array(0 to c_num_int_slaves-1);
  -- Crossbar master/slave arrays
  signal cbar_slave_in                      : t_wishbone_slave_in_array (c_masters-1 downto 0);
  signal cbar_slave_out                     : t_wishbone_slave_out_array(c_masters-1 downto 0);
  signal cbar_master_in                     : t_wishbone_master_in_array(c_slaves-1 downto 0);
  signal cbar_master_out                    : t_wishbone_master_out_array(c_slaves-1 downto 0);

  -- Extra Wishbone registering stage
  signal cbar_slave_in_reg0                 : t_wishbone_slave_in_array (c_masters-1 downto 0);
  signal cbar_slave_out_reg0                : t_wishbone_slave_out_array(c_masters-1 downto 0);

  -----------------------------
  -- EEPROM I2C Signals
  -----------------------------
  signal eeprom_i2c_scl_in                  : std_logic_vector(0 downto 0);
  signal eeprom_i2c_scl_out                 : std_logic_vector(0 downto 0);
  signal eeprom_i2c_scl_oe_n                : std_logic_vector(0 downto 0);
  signal eeprom_i2c_sda_in                  : std_logic_vector(0 downto 0);
  signal eeprom_i2c_sda_out                 : std_logic_vector(0 downto 0);
  signal eeprom_i2c_sda_oe_n                : std_logic_vector(0 downto 0);

  -----------------------------
  -- LM75A I2C Signals
  -----------------------------
  signal lm75a_i2c_scl_in                   : std_logic_vector(0 downto 0);
  signal lm75a_i2c_scl_out                  : std_logic_vector(0 downto 0);
  signal lm75a_i2c_scl_oe_n                 : std_logic_vector(0 downto 0);
  signal lm75a_i2c_sda_in                   : std_logic_vector(0 downto 0);
  signal lm75a_i2c_sda_out                  : std_logic_vector(0 downto 0);
  signal lm75a_i2c_sda_oe_n                 : std_logic_vector(0 downto 0);

  -----------------------------
  -- Trigger signals
  -----------------------------
  --signal m2c_trig                           : std_logic;
  --signal m2c_trig_sync                      : std_logic;
  --signal c2m_trig                           : std_logic;
  signal fmc_trig_val_in                    : std_logic;
  signal fmc_trig_val_in_buf                : std_logic;
  signal fmc_trig_val_in_sync               : std_logic;
  signal fmc_trig_dir_int                   : std_logic;
  signal fmc_trig_term_int                  : std_logic;
  signal fmc_trig_val_int_reg               : std_logic;
  signal fmc_trig_val_int                   : std_logic;

  -----------------------------
  -- Led signals
  -----------------------------
  signal led1_extd_p                        : std_logic;
  signal led2_extd_p                        : std_logic;
  signal led3_extd_p                        : std_logic;

  signal fmc_led1_int                       : std_logic;
  signal fmc_led2_int                       : std_logic;
  signal fmc_led3_int                       : std_logic;

  -----------------------------
  -- Dummy signals
  -----------------------------
  signal dummy_bit_low                      : std_logic := '0';
  signal dummy_adc_vector_low               : std_logic_vector(f_num_adc_pins(c_with_data_sdr)-1 downto 0) :=
                                                 (others => '0');
  -----------------------------
  -- Components
  -----------------------------

  component wb_fmc_130m_4ch_csr
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(3 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    fs_clk_i                                 : in     std_logic;
    regs_i                                   : in     t_wb_fmc_130m_4ch_csr_in_registers;
    regs_o                                   : out    t_wb_fmc_130m_4ch_csr_out_registers
  );
  end component;

  component wb_fmc_adc_common_csr
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(1 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    regs_i                                   : in     t_wb_fmc_adc_common_csr_in_registers;
    regs_o                                   : out    t_wb_fmc_adc_common_csr_out_registers
  );
  end component;

begin
  -- Reset signals and sychronization with positive edge of
  -- respective clock
  --sys_rst_n <= sys_rst_n_i and mmcm_adc_locked;
  sys_rst_n <= sys_rst_n_i;
  fs_rst_n <= sys_rst_n and mmcm_adc_locked;

  -- Reset synchronization with SYS clock domain
  -- Align the reset deassertion to the next clock edge
  cmp_reset_sys_synch : reset_synch
  port map(
    clk_i                                   => sys_clk_i,
    arst_n_i                                => sys_rst_n,
    rst_n_o                                 => sys_rst_sync_n
  );

  --sys_rst_sync_n <= sys_rst_n;

  -- Reset synchronization with FS clock domain (just clock 1
  -- is used for now). Align the reset deassertion to the next
  -- clock edge
  gen_adc_reset_synch : for i in 0 to c_num_adc_channels-1 generate
    gen_adc_reset_synch_ch : if g_use_data_chains(i) = '1' generate
      cmp_reset_fs_synch : reset_synch
      port map(
        clk_i                                       => fs_clk(i),
        arst_n_i                                    => fs_rst_n,
        --rst_n_o                                      => fs_rst_sync_n
        rst_n_o                                      => fs_rst_sync_n(i)
      );

      cmp_reset_fs2x_synch : reset_synch
      port map(
        clk_i                                       => fs_clk2x(i),
        arst_n_i                                    => fs_rst_n,
        rst_n_o                                     => fs_rst2x_sync_n(i)
      );

      -- Output adc sync'ed reset to downstream FPGA logic
      adc_rst_n_o(i) <= fs_rst_sync_n(i);
      adc_rst2x_n_o(i) <= fs_rst2x_sync_n(i);
      --fs_rst_sync_n(i) <= fs_rst_n;
    end generate;
  end generate;

  -----------------------------
  -- Insert extra Wishbone registering stage for ease timing.
  -- It effectively cuts the bandwodth in half!
  -----------------------------
  gen_with_extra_wb_reg : if g_with_extra_wb_reg generate

    cmp_register_link : xwb_register_link -- puts a register of delay between crossbars
    port map (
      clk_sys_i 			    => sys_clk_i,
      rst_n_i   			    => sys_rst_sync_n,
      slave_i   			    => cbar_slave_in_reg0(0),
      slave_o                               => cbar_slave_out_reg0(0),
      master_i                              => cbar_slave_out(0),
      master_o 		                    => cbar_slave_in(0)
    );

    cbar_slave_in_reg0(0).adr               <= wb_adr_i;
    cbar_slave_in_reg0(0).dat               <= wb_dat_i;
    cbar_slave_in_reg0(0).sel               <= wb_sel_i;
    cbar_slave_in_reg0(0).we                <= wb_we_i;
    cbar_slave_in_reg0(0).cyc               <= wb_cyc_i;
    cbar_slave_in_reg0(0).stb               <= wb_stb_i;

    wb_dat_o                                <= cbar_slave_out_reg0(0).dat;
    wb_ack_o                                <= cbar_slave_out_reg0(0).ack;
    wb_err_o                                <= cbar_slave_out_reg0(0).err;
    wb_rty_o                                <= cbar_slave_out_reg0(0).rty;
    wb_stall_o                              <= cbar_slave_out_reg0(0).stall;

  end generate;

  gen_without_extra_wb_reg : if not g_with_extra_wb_reg generate

    -- External master connection
    cbar_slave_in(0).adr                    <= wb_adr_i;
    cbar_slave_in(0).dat                    <= wb_dat_i;
    cbar_slave_in(0).sel                    <= wb_sel_i;
    cbar_slave_in(0).we                     <= wb_we_i;
    cbar_slave_in(0).cyc                    <= wb_cyc_i;
    cbar_slave_in(0).stb                    <= wb_stb_i;

    wb_dat_o                                <= cbar_slave_out(0).dat;
    wb_ack_o                                <= cbar_slave_out(0).ack;
    wb_err_o                                <= cbar_slave_out(0).err;
    wb_rty_o                                <= cbar_slave_out(0).rty;
    wb_stall_o                              <= cbar_slave_out(0).stall;

  end generate;

  -----------------------------
  -- FMC130M_4CH Address decoder for SPI/I2C Wishbone interfaces modules
  -----------------------------
  -- We need 5 outputs, as in the same wishbone addressing range, 5
  -- other wishbone peripherals must be driven:
  --
  -- 0 -> FMC130_4CH Register Wishbone Interface
  -- 1 -> FMC ADC Common
  -- 2 -> FMC Active Clock
  -- 3 -> EEPROM I2C Bus.
  -- 4 -> LM75A I2C Bus.

  -- The Internal Wishbone B.4 crossbar
  cmp_interconnect : xwb_sdb_crossbar
  generic map(
    g_num_masters                           => c_masters,
    g_num_slaves                            => c_slaves,
    g_registered                            => true,
    g_wraparound                            => true, -- Should be true for nested buses
    g_layout                                => c_layout,
    g_sdb_addr                              => c_sdb_address
  )
  port map(
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_sync_n,
    -- Master connections (INTERCON is a slave)
    slave_i                                 => cbar_slave_in,
    slave_o                                 => cbar_slave_out,
    -- Slave connections (INTERCON is a master)
    master_i                                => cbar_master_in,
    master_o                                => cbar_master_out
  );


  -----------------------------
  -- Slave adapter for Wishbone Register Interface
  -----------------------------
  cmp_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                     => true,
    g_master_mode                           => PIPELINED,
    g_master_granularity                    => WORD,
    g_slave_use_struct                      => false,
    g_slave_mode                            => g_interface_mode,
    g_slave_granularity                     => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_sync_n,
    master_i                                => wb_slv_adp_in,
    master_o                                => wb_slv_adp_out,
    sl_adr_i                                => resized_addr,
    sl_dat_i                                => cbar_master_out(0).dat,
    sl_sel_i                                => cbar_master_out(0).sel,
    sl_cyc_i                                => cbar_master_out(0).cyc,
    sl_stb_i                                => cbar_master_out(0).stb,
    sl_we_i                                 => cbar_master_out(0).we,
    sl_dat_o                                => cbar_master_in(0).dat,
    sl_ack_o                                => cbar_master_in(0).ack,
    sl_rty_o                                => cbar_master_in(0).rty,
    sl_err_o                                => cbar_master_in(0).err,
    sl_stall_o                              => cbar_master_in(0).stall
  );

  -- By doing this zeroing we avoid the issue related to BYTE -> WORD  conversion
  -- slave addressing (possibly performed by the slave adapter component)
  -- in which a bit in the MSB of the peripheral addressing part (31 - 4 in our case)
  -- is shifted to the internal register adressing part (3 - 0 in our case).
  -- Therefore, possibly changing the these bits!
  resized_addr(c_periph_addr_size-1 downto 0)
                                            <= cbar_master_out(0).adr(c_periph_addr_size-1 downto 0);
  resized_addr(c_wishbone_address_width-1 downto c_periph_addr_size)
                                            <= (others => '0');

  -----------------------------
  -- FMC516 Register Wishbone Interface. Word addressed!
  -----------------------------
  --FMC516 register interface is the slave number 0, word addressed
  cmp_wb_fmc_130m_4ch_csr : wb_fmc_130m_4ch_csr
  port map(
    rst_n_i                                 => sys_rst_sync_n,
    clk_sys_i                               => sys_clk_i,
    wb_adr_i                                => wb_slv_adp_out.adr(3 downto 0),
    wb_dat_i                                => wb_slv_adp_out.dat,
    wb_dat_o                                => wb_slv_adp_in.dat,
    wb_cyc_i                                => wb_slv_adp_out.cyc,
    wb_sel_i                                => wb_slv_adp_out.sel,
    wb_stb_i                                => wb_slv_adp_out.stb,
    wb_we_i                                 => wb_slv_adp_out.we,
    wb_ack_o                                => wb_slv_adp_in.ack,
    wb_stall_o                              => wb_slv_adp_in.stall,
    fs_clk_i                                => fs_clk(c_ref_clk),
    regs_i                                  => regs_in,
    regs_o                                  => regs_out
  );

  -- Unused wishbone signals
  --wb_slv_adp_in.err                         <= '0';
  --wb_slv_adp_in.rty                         <= '0';

  -- Wishbone Interface Register input assignments. There are others registers
  -- not assigned here.
  regs_in.fpga_ctrl_fmc_idelay0_rdy_i       <= adc_idelay_rdy;
  regs_in.fpga_ctrl_fmc_idelay1_rdy_i       <= adc_idelay_rdy;
  regs_in.fpga_ctrl_fmc_idelay2_rdy_i       <= adc_idelay_rdy;
  regs_in.fpga_ctrl_fmc_idelay3_rdy_i       <= adc_idelay_rdy;
  regs_in.fpga_ctrl_reserved1_i             <= (others => '0');
  regs_in.fpga_ctrl_temp_alarm_i            <= fmc_lm75_temp_alarm_i;
  regs_in.fpga_ctrl_reserved2_i             <= (others => '0');
  regs_in.idelay0_cal_val_i                 <= adc_fn_dly_out(0).data_chain.idelay.val;
  regs_in.idelay0_cal_reserved_i            <= (others => '0');
  regs_in.idelay1_cal_val_i                 <= adc_fn_dly_out(1).data_chain.idelay.val;
  regs_in.idelay1_cal_reserved_i            <= (others => '0');
  regs_in.idelay2_cal_val_i                 <= adc_fn_dly_out(2).data_chain.idelay.val;
  regs_in.idelay2_cal_reserved_i            <= (others => '0');
  regs_in.idelay3_cal_val_i                 <= adc_fn_dly_out(3).data_chain.idelay.val;
  regs_in.idelay3_cal_reserved_i            <= (others => '0');
  -- ADC RAW data channel 0
  regs_in.data0_val_i(regs_in.data0_val_i'left downto c_num_adc_bits)
                                            <= (others => '0');
  regs_in.data0_val_i(c_num_adc_bits-1 downto 0)
                                            <= adc_data(c_num_adc_bits-1 downto 0);
  -- ADC RAW data channel 1
  regs_in.data1_val_i(regs_in.data1_val_i'left downto c_num_adc_bits)
                                            <= (others => '0');
  regs_in.data1_val_i(c_num_adc_bits-1 downto 0)
                                            <= adc_data(2*c_num_adc_bits-1 downto c_num_adc_bits);

  -- ADC RAW data channel 2
  regs_in.data2_val_i(regs_in.data2_val_i'left downto c_num_adc_bits)
                                            <= (others => '0');
  regs_in.data2_val_i(c_num_adc_bits-1 downto 0)
                                            <= adc_data(3*c_num_adc_bits-1 downto 2*c_num_adc_bits);

  -- ADC RAW data channel 3
  regs_in.data3_val_i(regs_in.data3_val_i'left downto c_num_adc_bits)
                                            <= (others => '0');
  regs_in.data3_val_i(c_num_adc_bits-1 downto 0)
                                            <= adc_data(4*c_num_adc_bits-1 downto 3*c_num_adc_bits);

  regs_in.dcm_adc_done_i                    <= '0'; -- Unused
  regs_in.dcm_adc_status0_i                 <= '0'; -- Unused
  regs_in.dcm_reserved_i                    <= (others => '0');

  --regs_in.ch0_sta_val_i                     <= adc_out(0).adc_data;
  --regs_in.ch0_sta_reserved_i                <= (others => '0');
  --regs_in.ch0_fn_dly_reserved_clk_chain_dly_i  <= (others => '0');
  --regs_in.ch0_fn_dly_reserved_data_chain_dly_i <= (others => '0');
  --regs_in.ch1_sta_val_i                     <= adc_out(1).adc_data;
  --regs_in.ch1_sta_reserved_i                <= (others => '0');
  --regs_in.ch1_fn_dly_reserved_clk_chain_dly_i  <= (others => '0');
  --regs_in.ch1_fn_dly_reserved_data_chain_dly_i <= (others => '0');
  --regs_in.ch2_sta_val_i                     <= adc_out(2).adc_data;
  --regs_in.ch2_sta_reserved_i                <= (others => '0');
  --regs_in.ch2_fn_dly_reserved_clk_chain_dly_i  <= (others => '0');
  --regs_in.ch2_fn_dly_reserved_data_chain_dly_i <= (others => '0');
  --regs_in.ch3_sta_val_i                     <= adc_out(3).adc_data;
  --regs_in.ch3_sta_reserved_i                <= (others => '0');
  --regs_in.ch3_fn_dly_reserved_clk_chain_dly_i  <= (others => '0');
  --regs_in.ch3_fn_dly_reserved_data_chain_dly_i <= (others => '0');

  ---- ADC delay registers out
  --regs_in.ch0_fn_dly_clk_chain_dly_i <= adc_fn_dly_out(0).adc_clk_dly_val;
  --regs_in.ch0_fn_dly_data_chain_dly_i <= adc_fn_dly_out(0).adc_data_dly_val;
  --regs_in.ch1_fn_dly_clk_chain_dly_i <= adc_fn_dly_out(1).adc_clk_dly_val;
  --regs_in.ch1_fn_dly_data_chain_dly_i <= adc_fn_dly_out(1).adc_data_dly_val;
  --regs_in.ch2_fn_dly_clk_chain_dly_i <= adc_fn_dly_out(2).adc_clk_dly_val;
  --regs_in.ch2_fn_dly_data_chain_dly_i <= adc_fn_dly_out(2).adc_data_dly_val;
  --regs_in.ch3_fn_dly_clk_chain_dly_i <= adc_fn_dly_out(3).adc_clk_dly_val;
  --regs_in.ch3_fn_dly_data_chain_dly_i <= adc_fn_dly_out(3).adc_data_dly_val;
  --
  -- ADC delay registers in
  adc_fn_dly_wb_ctl_out(0).clk_chain.loadable.load      <= regs_out.idelay0_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(0).data_chain.loadable.load     <= regs_out.idelay0_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(0).clk_chain.loadable.val       <= regs_out.idelay0_cal_val_o;
  adc_fn_dly_wb_ctl_out(0).data_chain.loadable.val      <= regs_out.idelay0_cal_val_o;
  adc_fn_dly_wb_ctl_out(0).clk_chain.loadable.pulse     <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(0).data_chain.loadable.pulse    <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(0).clk_chain.sel.which          <= regs_out.idelay0_cal_line_o(c_num_adc_bits);
  adc_fn_dly_wb_ctl_out(0).data_chain.sel.which         <= regs_out.idelay0_cal_line_o(c_num_adc_bits-1 downto 0);
  --adc_fn_dly_wb_ctl_out(0).clk_chain.var.inc              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(0).data_chain.var.inc             <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(0).clk_chain.var.dec              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(0).data_chain.var.dec             <= '0'; -- Unused

  adc_fn_dly_wb_ctl_out(1).clk_chain.loadable.load      <= regs_out.idelay1_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(1).data_chain.loadable.load     <= regs_out.idelay1_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(1).clk_chain.loadable.val       <= regs_out.idelay1_cal_val_o;
  adc_fn_dly_wb_ctl_out(1).data_chain.loadable.val      <= regs_out.idelay1_cal_val_o;
  adc_fn_dly_wb_ctl_out(1).clk_chain.loadable.pulse     <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(1).data_chain.loadable.pulse    <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(1).clk_chain.sel.which          <= regs_out.idelay1_cal_line_o(c_num_adc_bits);
  adc_fn_dly_wb_ctl_out(1).data_chain.sel.which         <= regs_out.idelay1_cal_line_o(c_num_adc_bits-1 downto 0);
  --adc_fn_dly_wb_ctl_out(1).clk_chain.var.inc              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(1).data_chain.var.inc             <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(1).clk_chain.var.dec              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(1).data_chain.var.dec             <= '0'; -- Unused

  adc_fn_dly_wb_ctl_out(2).clk_chain.loadable.load      <= regs_out.idelay2_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(2).data_chain.loadable.load     <= regs_out.idelay2_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(2).clk_chain.loadable.val       <= regs_out.idelay2_cal_val_o;
  adc_fn_dly_wb_ctl_out(2).data_chain.loadable.val      <= regs_out.idelay2_cal_val_o;
  adc_fn_dly_wb_ctl_out(2).clk_chain.loadable.pulse     <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(2).data_chain.loadable.pulse    <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(2).clk_chain.sel.which          <= regs_out.idelay2_cal_line_o(c_num_adc_bits);
  adc_fn_dly_wb_ctl_out(2).data_chain.sel.which         <= regs_out.idelay2_cal_line_o(c_num_adc_bits-1 downto 0);
  --adc_fn_dly_wb_ctl_out(2).clk_chain.var.inc              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(2).data_chain.var.inc             <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(2).clk_chain.var.dec              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(2).data_chain.var.dec             <= '0'; -- Unused

  adc_fn_dly_wb_ctl_out(3).clk_chain.loadable.load      <= regs_out.idelay3_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(3).data_chain.loadable.load     <= regs_out.idelay3_cal_val_load_o;
  adc_fn_dly_wb_ctl_out(3).clk_chain.loadable.val       <= regs_out.idelay3_cal_val_o;
  adc_fn_dly_wb_ctl_out(3).data_chain.loadable.val      <= regs_out.idelay3_cal_val_o;
  adc_fn_dly_wb_ctl_out(3).clk_chain.loadable.pulse     <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(3).data_chain.loadable.pulse    <= adc_idelay_update_or;
  adc_fn_dly_wb_ctl_out(3).clk_chain.sel.which          <= regs_out.idelay3_cal_line_o(c_num_adc_bits);
  adc_fn_dly_wb_ctl_out(3).data_chain.sel.which         <= regs_out.idelay3_cal_line_o(c_num_adc_bits-1 downto 0);
  --adc_fn_dly_wb_ctl_out(3).clk_chain.var.inc              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(3).data_chain.var.inc             <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(3).clk_chain.var.dec              <= '0'; -- Unused
  --adc_fn_dly_wb_ctl_out(3).data_chain.var.dec             <= '0'; -- Unused

  adc_idelay_update_or                      <= regs_out.idelay0_cal_update_o or
                                                 regs_out.idelay1_cal_update_o or
                                                 regs_out.idelay2_cal_update_o or
                                                 regs_out.idelay3_cal_update_o;

  ---- ADC delay falling edge control
  --adc_cs_dly_in_int(0).adc_data_fe_d1_en <= regs_out.ch0_cs_dly_fe_dly_o(0);
  --adc_cs_dly_in_int(0).adc_data_fe_d2_en <= regs_out.ch0_cs_dly_fe_dly_o(1);
  --adc_cs_dly_in_int(1).adc_data_fe_d1_en <= regs_out.ch1_cs_dly_fe_dly_o(0);
  --adc_cs_dly_in_int(1).adc_data_fe_d2_en <= regs_out.ch1_cs_dly_fe_dly_o(1);
  --adc_cs_dly_in_int(2).adc_data_fe_d1_en <= regs_out.ch2_cs_dly_fe_dly_o(0);
  --adc_cs_dly_in_int(2).adc_data_fe_d2_en <= regs_out.ch2_cs_dly_fe_dly_o(1);
  --adc_cs_dly_in_int(3).adc_data_fe_d1_en <= regs_out.ch3_cs_dly_fe_dly_o(0);
  --adc_cs_dly_in_int(3).adc_data_fe_d2_en <= regs_out.ch3_cs_dly_fe_dly_o(1);
  --
  ---- ADC regular delay control
  --adc_cs_dly_in_int(0).adc_data_rg_d1_en <= regs_out.ch0_cs_dly_rg_dly_o(0);
  --adc_cs_dly_in_int(0).adc_data_rg_d2_en <= regs_out.ch0_cs_dly_rg_dly_o(1);
  --adc_cs_dly_in_int(1).adc_data_rg_d1_en <= regs_out.ch1_cs_dly_rg_dly_o(0);
  --adc_cs_dly_in_int(1).adc_data_rg_d2_en <= regs_out.ch1_cs_dly_rg_dly_o(1);
  --adc_cs_dly_in_int(2).adc_data_rg_d1_en <= regs_out.ch2_cs_dly_rg_dly_o(0);
  --adc_cs_dly_in_int(2).adc_data_rg_d2_en <= regs_out.ch2_cs_dly_rg_dly_o(1);
  --adc_cs_dly_in_int(3).adc_data_rg_d1_en <= regs_out.ch3_cs_dly_rg_dly_o(0);
  --adc_cs_dly_in_int(3).adc_data_rg_d2_en <= regs_out.ch3_cs_dly_rg_dly_o(1);

  -- Wishbone Interface Register output assignments. There are others registers
  -- not assigned here.
  fmc_adc_rand_o                            <= regs_out.adc_rand_o;
  fmc_adc_dith_o                            <= regs_out.adc_dith_o;
  fmc_adc_shdn_o                            <= regs_out.adc_shdn_o;
  fmc_adc_pga_o                             <= regs_out.adc_pga_o;

  adc_rst                                   <= regs_out.fpga_ctrl_fmc_idelay_rst_o;
  --regs_out.fpga_ctrl_fmc_fifo_rst_o; -- Unused

  --regs_out.dcm_adc_en_o    -- Unused
  --regs_out.dcm_adc_phase_o -- Unused
  --regs_out.dcm_adc_reset_o -- Unused

  -----------------------------
  -- Slave adapter for Wishbone Register Interface FMC ADC common
  -----------------------------
  cmp_acommon_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                     => true,
    g_master_mode                           => PIPELINED,
    g_master_granularity                    => WORD,
    g_slave_use_struct                      => false,
    g_slave_mode                            => g_interface_mode,
    g_slave_granularity                     => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_sync_n,
    master_i                                => wb_slv_adp_acommon_in,
    master_o                                => wb_slv_adp_acommon_out,
    sl_adr_i                                => resized_acommon_addr,
    sl_dat_i                                => cbar_master_out(1).dat,
    sl_sel_i                                => cbar_master_out(1).sel,
    sl_cyc_i                                => cbar_master_out(1).cyc,
    sl_stb_i                                => cbar_master_out(1).stb,
    sl_we_i                                 => cbar_master_out(1).we,
    sl_dat_o                                => cbar_master_in(1).dat,
    sl_ack_o                                => cbar_master_in(1).ack,
    sl_rty_o                                => cbar_master_in(1).rty,
    sl_err_o                                => cbar_master_in(1).err,
    sl_stall_o                              => cbar_master_in(1).stall
  );

  -- By doing this zeroing we avoid the issue related to BYTE -> WORD  conversion
  -- slave addressing (possibly performed by the slave adapter component)
  -- in which a bit in the MSB of the peripheral addressing part (31 - 5 in our case)
  -- is shifted to the internal register adressing part (4 - 0 in our case).
  -- Therefore, possibly changing the these bits!
  -- See wb_fmc250m_4ch_port.vhd for register bank addresses
  resized_acommon_addr(c_periph_acommon_addr_size-1 downto 0)
                                            <= cbar_master_out(1).adr(c_periph_acommon_addr_size-1 downto 0);
  resized_acommon_addr(c_wishbone_address_width-1 downto c_periph_acommon_addr_size)
                                            <= (others => '0');

  -----------------------------
  -- FMC ADC Common Register Wishbone Interface. Word addressed!
  -----------------------------
  --FMC ADC Common register interface is the slave number 1, word addressed
  cmp_wb_fmc_adc_common_port : wb_fmc_adc_common_csr
  port map(
    rst_n_i                                 => sys_rst_sync_n,
    clk_sys_i                               => sys_clk_i,
    wb_adr_i                                => wb_slv_adp_acommon_out.adr(1 downto 0),
    wb_dat_i                                => wb_slv_adp_acommon_out.dat,
    wb_dat_o                                => wb_slv_adp_acommon_in.dat,
    wb_cyc_i                                => wb_slv_adp_acommon_out.cyc,
    wb_sel_i                                => wb_slv_adp_acommon_out.sel,
    wb_stb_i                                => wb_slv_adp_acommon_out.stb,
    wb_we_i                                 => wb_slv_adp_acommon_out.we,
    wb_ack_o                                => wb_slv_adp_acommon_in.ack,
    wb_stall_o                              => wb_slv_adp_acommon_in.stall,
    -- Check if this clock is necessary!
    --wb_clk_i                                => sys_clk_i,
    regs_i                                  => regs_acommon_in,
    regs_o                                  => regs_acommon_out
  );

  -- Unused wishbone signals
  wb_slv_adp_acommon_in.err                 <= '0';
  wb_slv_adp_acommon_in.rty                 <= '0';

  -- Wishbone Interface Register input assignments. There are others registers
  -- not assigned here.
  regs_acommon_in.fmc_status_mmcm_locked_i  <= mmcm_adc_locked;
  regs_acommon_in.fmc_status_pwr_good_i     <= fmc_pg_m2c_i;
  regs_acommon_in.fmc_status_prst_i         <= fmc_prsnt_i;
  regs_acommon_in.fmc_status_reserved_i     <= (others => '0');

  -- Wishbone Interface Register output assignments. There are others registers
  -- not assigned here.
  fmc_trig_dir_int                          <= regs_acommon_out.trigger_dir_o;
  fmc_trig_term_o                           <= regs_acommon_out.trigger_term_o;
  fmc_trig_val_int_reg                      <= regs_acommon_out.trigger_trig_val_o;

  fmc_led1_int                              <= regs_acommon_out.monitor_led1_o;
  fmc_led2_int                              <= regs_acommon_out.monitor_led2_o;
  fmc_led3_int                              <= regs_acommon_out.monitor_led3_o;

  adc_test_data_en                          <= regs_acommon_out.monitor_test_data_en_o;
  mmcm_rst_reg                              <= regs_acommon_out.monitor_mmcm_rst_o;

  -----------------------------
  -- Pins connections for ADC interface structures
  -----------------------------
  -- The hardcoded part here is innevitable as we have to mannualy connect
  -- the external ports to the structures.
  --
  -- WARNING: just clock 1 is is used for now. If more clocks are used,
  -- we would have to synchronise the other resets (adc_in(x).adc_rst_n)
  -- to it and map them below!

  -- ADC in signal mangling
  adc_in(0).adc_clk                         <= adc_clk0;
  adc_in(0).adc_data                        <= adc_data_ch0;
  adc_in(1).adc_clk                         <= adc_clk1;
  adc_in(1).adc_data                        <= adc_data_ch1;
  adc_in(2).adc_clk                         <= adc_clk2;
  adc_in(2).adc_data                        <= adc_data_ch2;
  adc_in(3).adc_clk                         <= adc_clk3;
  adc_in(3).adc_data                        <= adc_data_ch3;

  gen_fs_rst_in : for i in 0 to c_num_adc_channels-1 generate
    adc_in(i).adc_rst_n                     <= fs_rst_sync_n(i);
  end generate;

  -----------------------------
  -- Wishbone Delay Register Interface <-> ADC interface (clock + data delays).
  -----------------------------
  -- Clock/Data Chain delays

  -- Capture delay signals (clock + data chains) coming from the Wishbone
  -- Register Interface.
  gen_adc_idly_iface : for i in 0 to c_num_adc_channels-1 generate

    cmp_fmc_adc_dly_iface : fmc_adc_dly_iface
    generic map(
      g_with_var_loadable                     => c_with_idelay_var_loadable,
      g_with_variable                         => c_with_idelay_variable,
      g_with_fn_dly_select                    => c_with_fn_dly_select
    )
    port map(
      rst_n_i                                 => sys_rst_sync_n,
      clk_sys_i                               => sys_clk_i,

      adc_fn_dly_wb_ctl_i                     => adc_fn_dly_wb_ctl_out(i),
      adc_fn_dly_o                            => adc_fn_dly_in(i)
    );

    -- Debug interface
    adc_dly_debug_o(i) <= adc_fn_dly_in(i);
  end generate;

  -----------------------------
  -- ADC Interface
  -----------------------------
  cmp_fmc_adc_buf : fmc_adc_buf
  generic map (
    g_with_clk_single_ended                 => c_with_clk_single_ended,
    g_with_data_single_ended                => c_with_data_single_ended,
    g_with_data_sdr                         => c_with_data_sdr
  )
  port map (
    -----------------------------
    -- External ports
    -----------------------------
    adc_clk0_p_i                            => dummy_bit_low,
    adc_clk0_n_i                            => dummy_bit_low,
    adc_clk1_p_i                            => dummy_bit_low,
    adc_clk1_n_i                            => dummy_bit_low,
    adc_clk2_p_i                            => dummy_bit_low,
    adc_clk2_n_i                            => dummy_bit_low,
    adc_clk3_p_i                            => dummy_bit_low,
    adc_clk3_n_i                            => dummy_bit_low,

    -- ADC clocks. One clock per ADC channel
    adc_clk0_i                              => fmc_adc0_clk_i,
    adc_clk1_i                              => fmc_adc1_clk_i,
    adc_clk2_i                              => fmc_adc2_clk_i,
    adc_clk3_i                              => fmc_adc3_clk_i,

    adc_data_ch0_p_i                        => dummy_adc_vector_low,
    adc_data_ch0_n_i                        => dummy_adc_vector_low,
    adc_data_ch1_p_i                        => dummy_adc_vector_low,
    adc_data_ch1_n_i                        => dummy_adc_vector_low,
    adc_data_ch2_p_i                        => dummy_adc_vector_low,
    adc_data_ch2_n_i                        => dummy_adc_vector_low,
    adc_data_ch3_p_i                        => dummy_adc_vector_low,
    adc_data_ch3_n_i                        => dummy_adc_vector_low,

    -- SDR ADC data channels.
    adc_data_ch0_i                          => fmc_adc0_data_i,
    adc_data_ch1_i                          => fmc_adc1_data_i,
    adc_data_ch2_i                          => fmc_adc2_data_i,
    adc_data_ch3_i                          => fmc_adc3_data_i,

    adc_clk0_o                              => adc_clk0,
    adc_clk1_o                              => adc_clk1,
    adc_clk2_o                              => adc_clk2,
    adc_clk3_o                              => adc_clk3,

    adc_data_ch0_o                          => adc_data_ch0,
    adc_data_ch1_o                          => adc_data_ch1,
    adc_data_ch2_o                          => adc_data_ch2,
    adc_data_ch3_o                          => adc_data_ch3
  );

  cmp_fmc_adc_iface : fmc_adc_iface
  generic map(
      -- The only supported values are VIRTEX6 and 7SERIES
    g_fpga_device                           => g_fpga_device,
    g_delay_type                            => g_delay_type,
    --g_delay_type                            => "VARIABLE",
    g_adc_clk_period_values                 => g_adc_clk_period_values,
    g_use_clk_chains                        => g_use_clk_chains,
    g_use_data_chains                       => g_use_data_chains,
    g_map_clk_data_chains                   => g_map_clk_data_chains,
    g_ref_clk                               => g_ref_clk,
    g_mmcm_param                            => c_mmcm_param,
    g_with_bufio_clk_chains                 => g_with_bufio_clk_chains,
    g_with_bufr_clk_chains                  => g_with_bufr_clk_chains,
    g_with_data_sdr                         => c_with_data_sdr,
    g_with_fn_dly_select                    => c_with_fn_dly_select,
    g_with_idelayctrl                       => g_with_idelayctrl,
    g_sim                                   => g_sim
  )
  port map(
    sys_clk_i                               => sys_clk_i,
    -- System Reset
    sys_rst_n_i                             => sys_rst_sync_n,
    -- ADC clock generation reset. Just a regular asynchronous reset.
    sys_clk_200Mhz_i                        => sys_clk_200Mhz_i,

    -- MMCM reset port
    mmcm_rst_i                              => mmcm_rst_reg,

    -----------------------------
    -- External ports
    -----------------------------
    adc_in_i                                => adc_in_dummy,
    adc_in_sdr_i                            => adc_in,

    -----------------------------
    -- Optional External Global Clock ports
    -----------------------------
    adc_ext_glob_clk_i                      => adc_ext_glob_clk_int,

    -----------------------------
    -- ADC Delay signals
    -----------------------------

    adc_fn_dly_i                            => adc_fn_dly_in,
    adc_fn_dly_o                            => adc_fn_dly_out,

    adc_cs_dly_i                            => adc_cs_dly_in,

    -----------------------------
    -- ADC output signals
    -----------------------------
    adc_out_o                               => adc_out,

    -- Idelay ready signal
    idelay_rdy_o                            => adc_idelay_rdy,

    -----------------------------
    -- MMCM general signals
    -----------------------------
    mmcm_adc_locked_o                       => mmcm_adc_locked,

    fifo_debug_valid_o                      => fifo_debug_valid_o,
    fifo_debug_full_o                       => fifo_debug_full_o,
    fifo_debug_empty_o                      => fifo_debug_empty_o
  );

  -- Clock and reset assignments
  -- General status board pins
  fmc_mmcm_lock_o                           <= mmcm_adc_locked;

  -- Optional reference clock
  adc_ext_glob_clk_int.adc_clk_bufg         <= fmc_ext_ref_clk_i;
  adc_ext_glob_clk_int.adc_clk2x_bufg       <= fmc_ext_ref_clk2x_i;
  adc_ext_glob_clk_int.mmcm_adc_locked      <= fmc_ext_ref_mmcm_locked_i;

  -- ADC data for internal use
  gen_adc_data_int : for i in 0 to c_num_adc_channels-1 generate
    --adc_clk_int(i)                          <= adc_out(i).adc_clk;
    fs_clk(i)                               <= adc_out(i).adc_clk;
    fs_clk2x(i)                             <= adc_out(i).adc_clk2x;
    adc_data(c_num_adc_bits*(i+1)-1 downto c_num_adc_bits*i) <=
      adc_out(i).adc_data when adc_test_data_en = '0'
                      else std_logic_vector(wbs_test_data(i));
    adc_valid(i) <=
      adc_out(i).adc_data_valid when adc_test_data_en = '0'
                      else '1';
  end generate;

  -- Output ADC signals to external FPGA
  adc_clk_o                                <= fs_clk;
  adc_clk2x_o                              <= fs_clk2x;
  adc_data_o                               <= adc_data;
  adc_data_valid_o                         <= adc_valid;

  -----------------------------
  --  FMC Active Clock
  -----------------------------
  -- FMC Active Clock is slave number 2, word addressed
  cmp_fmc_active_clk : xwb_fmc_active_clk
  generic map(
    -- I2C address for Si571AJC000337DG
    g_si57x_i2c_addr                        => "1001001",
    g_si57x_7ppm_variant                    => false,
    -- Considering a 125 MHz clock, this should result in a 250 kHz SCL
    -- frequency, but the measured SCL frequency is 180 kHz, this seems to be a
    -- bug in i2c_master_byte_ctrl or i2c_master_bit_ctrl.
    g_si57x_i2c_clk_div                     => 125,
    g_interface_mode                        => g_interface_mode,
    g_address_granularity                   => g_address_granularity,
    g_with_extra_wb_reg                     => g_with_extra_wb_reg
  )
  port map (
    sys_clk_i                               => sys_clk_i,
    sys_rst_n_i                             => sys_rst_n_i,

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                => cbar_master_out(2),
    wb_slv_o                                => cbar_master_in(2),

    -----------------------------
    -- External ports
    -----------------------------

    -- Si571 clock gen
    si571_scl_pad_b                         => si571_scl_pad_b,
    si571_sda_pad_b                         => si571_sda_pad_b,
    fmc_si571_oe_o                          => fmc_si571_oe_o,

    -- AD9510 clock distribution PLL
    spi_ad9510_cs_o                         => spi_ad9510_cs_o,
    spi_ad9510_sclk_o                       => spi_ad9510_sclk_o,
    spi_ad9510_mosi_o                       => spi_ad9510_mosi_o,
    spi_ad9510_miso_i                       => spi_ad9510_miso_i,

    fmc_pll_function_o                      => fmc_pll_function_o,
    fmc_pll_status_i                        => fmc_pll_status_i,

    -- AD9510 clock copy
    fmc_fpga_clk_p_i                        => fmc_fpga_clk_p_i,
    fmc_fpga_clk_n_i                        => fmc_fpga_clk_n_i,

    -- Clock reference selection (TS3USB221)
    fmc_clk_sel_o                           => fmc_clk_sel_o,

    -----------------------------
    -- General ADC output signals and status
    -----------------------------

    -- General board status
    fmc_pll_status_o                        => fmc_pll_status_o,

    -- fmc_fpga_clk_*_i bypass signals
    fmc_fpga_clk_p_o                        => open,
    fmc_fpga_clk_n_o                        => open
  );

  -- Not used wishbone signals
  --cbar_master_in(3).err                     <= '0';
  --cbar_master_in(3).rty                     <= '0';

  -----------------------------
  --  I2C EEPROM 24AA64T-I
  -----------------------------
  -- I2C EEPROM is slave number 3, word addressed

  cmp_eeprom_i2c : xwb_i2c_master
  generic map(
    g_interface_mode                        => g_interface_mode,
    g_address_granularity                   => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_sync_n,

    slave_i                                 => cbar_master_out(3),
    slave_o                                 => cbar_master_in(3),
    desc_o                                  => open,

    scl_pad_i                               => eeprom_i2c_scl_in,
    scl_pad_o                               => eeprom_i2c_scl_out,
    scl_padoen_o                            => eeprom_i2c_scl_oe_n,
    sda_pad_i                               => eeprom_i2c_sda_in,
    sda_pad_o                               => eeprom_i2c_sda_out,
    sda_padoen_o                            => eeprom_i2c_sda_oe_n
  );

  eeprom_scl_pad_b  <= eeprom_i2c_scl_out(0) when eeprom_i2c_scl_oe_n(0) = '0' else 'Z';
  eeprom_i2c_scl_in(0) <= eeprom_scl_pad_b;

  eeprom_sda_pad_b  <= eeprom_i2c_sda_out(0) when eeprom_i2c_sda_oe_n(0) = '0' else 'Z';
  eeprom_i2c_sda_in(0) <= eeprom_sda_pad_b;

  -- Not used wishbone signals
  --cbar_master_in(3).err                     <= '0';
  --cbar_master_in(3).rty                     <= '0';

  -----------------------------
  --  I2C LM75AIMM
  -----------------------------
  -- I2C LM75AIMM is slave number 4, word addressed

  cmp_lm75_i2c : xwb_i2c_master
  generic map(
    g_interface_mode                        => g_interface_mode,
    g_address_granularity                   => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_sync_n,

    slave_i                                 => cbar_master_out(4),
    slave_o                                 => cbar_master_in(4),
    desc_o                                  => open,

    scl_pad_i                               => lm75a_i2c_scl_in,
    scl_pad_o                               => lm75a_i2c_scl_out,
    scl_padoen_o                            => lm75a_i2c_scl_oe_n,
    sda_pad_i                               => lm75a_i2c_sda_in,
    sda_pad_o                               => lm75a_i2c_sda_out,
    sda_padoen_o                            => lm75a_i2c_sda_oe_n
  );

  lm75_scl_pad_b  <= lm75a_i2c_scl_out(0) when lm75a_i2c_scl_oe_n(0) = '0' else 'Z';
  lm75a_i2c_scl_in(0) <= lm75_scl_pad_b;

  lm75_sda_pad_b  <= lm75a_i2c_sda_out(0) when lm75a_i2c_sda_oe_n(0) = '0' else 'Z';
  lm75a_i2c_sda_in(0) <= lm75_sda_pad_b;

  -- Not used wishbone signals
  --cbar_master_in(4).err                     <= '0';
  --cbar_master_in(4).rty                     <= '0';

  -----------------------------
  -- Wishbone Streaming Interface
  -----------------------------
  -- This stream source is in ADC clock domain
  gen_wbs_interfaces : for i in 0 to c_num_adc_channels-1 generate
    gen_wbs_interfaces_ch : if g_use_data_chains(i) = '1' generate
      -- Generate 16-bit wishbone streaming interface
      cmp_wb_stream_source_gen : wb_stream_source_gen
      generic map (
        g_wbs_interface_width                   => NARROW2
      )
      port map(
        clk_i                                   => fs_clk(i),
        rst_n_i                                 => fs_rst_sync_n(i),

        ---- Wishbone Fabric Interface I/O
        -- 16-bit interface
        src_adr16_o                             => wbs_adr_o(c_wbs_adr4_width*(i+1)-1 downto
                                                    c_wbs_adr4_width*i),
        src_dat16_o                             => wbs_dat_o(c_wbs_dat16_width*(i+1)-1 downto
                                                    c_wbs_dat16_width*i),
        src_sel16_o                             => wbs_sel_o(c_wbs_sel16_width*(i+1)-1 downto
                                                    c_wbs_sel16_width*i),

        -- Common Wishbone Streaming lines
        src_cyc_o                               => wbs_cyc_o(i),
        src_stb_o                               => wbs_stb_o(i),
        src_we_o                                => wbs_we_o(i),
        src_ack_i                               => wbs_ack_i(i),
        src_stall_i                             => wbs_stall_i(i),
        --src_err_i                               => wbs_err_i(i),
        src_err_i                               => '0',
        src_rty_i                               => wbs_rty_i(i),

        -- Decoded & buffered logic
        -- 16-bit interface
        adr16_i                                 => wbs_adr,
        dat16_i                                 => wbs_dat(i),
        sel16_i                                 => wbs_sel,

        dvalid_i                                => wbs_valid(i),
        sof_i                                   => '1',
        eof_i                                   => '0',
        error_i                                 => wbs_error,
        dreq_o                                  => open
      );

      -- Generate test data
      p_gen_test_data : process(fs_clk(i))
      begin
        if rising_edge(fs_clk(i)) then
          if fs_rst_sync_n(i) = '0' then
            wbs_test_data(i) <= (others => '0');
          else
            wbs_test_data(i) <= wbs_test_data(i) + 1;
          end if;
        end if;
      end process;

      wbs_dat(i) <= adc_out(i).adc_data when adc_test_data_en = '0'
                      else std_logic_vector(wbs_test_data(i));
      wbs_valid(i) <= adc_out(i).adc_data_valid when adc_test_data_en = '0'
                        else '1';
    end generate;
  end generate;

  -- Write always to addr c_WBS_DATA (meaning we are transmiting data)
  wbs_adr                                   <= std_logic_vector(resize(c_WBS_DATA, wbs_adr'length));
  wbs_error                                 <= '0';
  wbs_sel                                   <= (others => '1');

  -- generate SOF and EOF signals
  --p_gen_wbs_sof_eof : process(fs_clk, fs_rst_sync_n)
  --begin
  --  if fs_rst_sync_n = '0' then
  --    wbs_packet_counter <= (others => '0');
  --    wbs_sof <= '0';
  --    wbs_eof <= '0';
  --  elsif rising_edge(fs_clk) then
  --    -- Increment counter if data is valid
  --    if wbs_dvalid = '1' then
  --      wbs_packet_counter <= wbs_packet_counter + 1;
  --    end if;
  --
  --    if wbs_packet_counter = to_unsigned(0, g_packet_size) then
  --      wbs_sof <= '1';
  --    else
  --      wbs_sof <= '0';
  --    end if;
  --
  --    if wbs_packet_counter = g_packet_size-2 and wbs_dvalid = '1' then
  --      wbs_eof <= '1';
  --    else
  --      wbs_eof <= '0';
  --    end if;
  --  end if;
  --end process;

  -- Generate SOF and EOF signals based on counter
  --wbs_sof <= '1' when wbs_packet_counter = to_unsigned(0, g_packet_size) else '0';
  --wbs_eof <= '1' when wbs_packet_counter = g_packet_size-1 else '0';

  -----------------------------
  -- Trigger Interface.
  -----------------------------

  --Trigger data output (if in output mode)
  cmp_trigger_iobufds : iobufds
  generic map (
    diff_term                               => true,   -- Differential Termination ("TRUE"/"FALSE")
    ibuf_low_pwr                            => false,   -- Low Power - "TRUE", High Performance = "FALSE"
    iostandard                              => "BLVDS_25" -- Specify the I/O standard
  )
  port map (
    o                                       => fmc_trig_val_in_buf, -- Buffer output for further use
    io                                      => fmc_trig_val_p_b,    -- Diff_p inout (connect directly to top-level port)
    iob                                     => fmc_trig_val_n_b,    -- Diff_n inout (connect directly to top-level port)
    i                                       => fmc_trig_val_int,    -- Buffer input
    t                                       => fmc_trig_dir_int     -- 3-state enable input, high=input, low=output
  );

  fmc_trig_dir_o                            <= fmc_trig_dir_int;
  -- Only assign FMC internal trigger if the buffer direction is set to 1 (FPGA is input).
  -- Otherwise, an external logic driving fmc_trig_val_int signal would be fed out to
  -- the same fmc_triv_val_in_buf, which is not desirable in most cases.
  -- Maybe, in the future, we add a register field to control this, but for now this is
  -- enough
  fmc_trig_val_in                           <= fmc_trig_val_in_buf when fmc_trig_dir_int = '1' else '0';

  -- External hardware trigger synchronization
  cmp_trig_sync : gc_ext_pulse_sync
  generic map(
    -- minimum pulse in ns to accept input (must be >1 clk_i ns)
    g_min_pulse_width                       => 16,
    g_clk_frequency                         => 130,   -- MHz
    g_output_polarity                       => '0',   -- positive pulse
    g_output_retrig                         => false,
    g_output_length                         => 1      -- clk_i tick
  )
  port map(
    rst_n_i                                 => fs_rst_sync_n(c_ref_clk),
    clk_i                                   => fs_clk(c_ref_clk),
    input_polarity_i                        => '1',
    pulse_i                                 => fmc_trig_val_in,
    pulse_o                                 => fmc_trig_val_in_sync
  );

  -- Input external trigger to FPGA pin
  fmc_trig_val_int <= fmc_trig_val_int_reg or trig_hw_i;

  -- Output external trigger to other logic. Hardware trigger enable
  trig_hw_o                                 <= fmc_trig_val_in_sync;

  -----------------------------
  -- LEDs Interface. Output extended pulses of important commands
  -----------------------------

  -- FMC LED1
  cmp_led1_extende_pulse : gc_extend_pulse
  generic map (
    -- 20000000 clock pulses
    g_width => 20000000
  )
  port map(
    clk_i                                   => fs_clk(c_ref_clk),
    rst_n_i                                 => fs_rst_sync_n(c_ref_clk),
    -- input pulse (synchronous to clk_i)
    pulse_i                                 => fmc_trig_val_in_sync,
    -- extended output pulse
    extended_o                              => led1_extd_p
  );

  -- Output extended pulse led from FMC power good signal or register interface
  -- manual led control
  fmc_led1_o <= led1_extd_p or fmc_led1_int;

  -- FMC LED2
  cmp_led2_extende_pulse : gc_extend_pulse
  generic map (
    -- 20000000 clock pulses
    g_width => 20000000
  )
  port map(
    clk_i                                   => fs_clk(c_ref_clk),
    rst_n_i                                 => fs_rst_sync_n(c_ref_clk),
    -- input pulse (synchronous to clk_i)
    pulse_i                                 => trig_hw_i,
    -- extended output pulse
    extended_o                              => led2_extd_p
  );

  fmc_led2_o <= led2_extd_p or fmc_led2_int;
  fmc_led3_o <= fmc_led3_int;

end rtl;
