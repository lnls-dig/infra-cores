library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;
use work.wb_stream_pkg.all;
use work.wb_stream_generic_pkg.all;
use work.fmc_adc_pkg.all;
use work.wr_fabric_pkg.all;
use work.acq_core_pkg.all;
use work.ipcores_pkg.all;
use work.pcie_cntr_axi_pkg.all;
use work.trigger_common_pkg.all;

package ifc_wishbone_pkg is

  --------------------------------------------------------------------
  -- Types
  --------------------------------------------------------------------
  subtype t_boolean is boolean;
  type t_boolean_array is array (natural range <>) of t_boolean;

  --------------------------------------------------------------------
  -- Components
  --------------------------------------------------------------------

  component wb_fmc150
  generic
  (
      g_interface_mode                        : t_wishbone_interface_mode      := PIPELINED;
      g_address_granularity                   : t_wishbone_address_granularity := WORD;
      g_packet_size                           : natural := 32;
      g_sim                                   : integer := 0
  );
  port
  (
      rst_n_i                                 : in std_logic;
      clk_sys_i                               : in std_logic;
      --clk_100Mhz_i                            : in std_logic;
      clk_200Mhz_i                            : in std_logic;

      -----------------------------
      -- Wishbone signals
      -----------------------------

      wb_adr_i                                : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
      wb_dat_i                                : in  std_logic_vector(c_wishbone_data_width-1 downto 0) := (others => '0');
      wb_dat_o                                : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_sel_i                                : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0) := (others => '0');
      wb_we_i                                 : in  std_logic := '0';
      wb_cyc_i                                : in  std_logic := '0';
      wb_stb_i                                : in  std_logic := '0';
      wb_ack_o                                : out std_logic;
      wb_err_o                                : out std_logic;
      wb_rty_o                                : out std_logic;
      wb_stall_o                              : out std_logic;

      -----------------------------
      -- Simulation Only ports
      -----------------------------
      sim_adc_clk_i                           : in std_logic;
      sim_adc_clk2x_i                         : in std_logic;

      sim_adc_cha_data_i                      : in std_logic_vector(13 downto 0);
      sim_adc_chb_data_i                      : in std_logic_vector(13 downto 0);
      sim_adc_data_valid                      : in std_logic;

      -----------------------------
      -- External ports
      -----------------------------
      --Clock/Data connection to ADC on FMC150 (ADS62P49)
      adc_clk_ab_p_i                          : in  std_logic;
      adc_clk_ab_n_i                          : in  std_logic;
      adc_cha_p_i                             : in  std_logic_vector(6 downto 0);
      adc_cha_n_i                             : in  std_logic_vector(6 downto 0);
      adc_chb_p_i                             : in  std_logic_vector(6 downto 0);
      adc_chb_n_i                             : in  std_logic_vector(6 downto 0);

      --Clock/Data connection to DAC on FMC150 (DAC3283)
      dac_dclk_p_o                            : out std_logic;
      dac_dclk_n_o                            : out std_logic;
      dac_data_p_o                            : out std_logic_vector(7 downto 0);
      dac_data_n_o                            : out std_logic_vector(7 downto 0);
      dac_frame_p_o                           : out std_logic;
      dac_frame_n_o                           : out std_logic;
      txenable_o                              : out std_logic;

      --Clock/Trigger connection to FMC150
      --clk_to_fpga_p           : in  std_logic;
      --clk_to_fpga_n           : in  std_logic;
      --ext_trigger_p           : in  std_logic;
      --ext_trigger_n           : in  std_logic;

      -- Control signals from/to FMC150
      --Serial Peripheral Interface (SPI)
      spi_sclk_o                              : out std_logic; -- Shared SPI clock line
      spi_sdata_o                             : out std_logic; -- Shared SPI data line

      -- ADC specific signals
      adc_n_en_o                              : out std_logic; -- SPI chip select
      adc_sdo_i                               : in  std_logic; -- SPI data out
      adc_reset_o                             : out std_logic; -- SPI reset

      -- CDCE specific signals
      cdce_n_en_o                             : out std_logic; -- SPI chip select
      cdce_sdo_i                              : in  std_logic; -- SPI data out
      cdce_n_reset_o                          : out std_logic;
      cdce_n_pd_o                             : out std_logic;
      cdce_ref_en_o                           : out std_logic;
      cdce_pll_status_i                       : in  std_logic;

      -- DAC specific signals
      dac_n_en_o                              : out std_logic; -- SPI chip select
      dac_sdo_i                               : in  std_logic; -- SPI data out

      -- Monitoring specific signals
      mon_n_en_o                              : out std_logic; -- SPI chip select
      mon_sdo_i                               : in  std_logic; -- SPI data out
      mon_n_reset_o                           : out std_logic;
      mon_n_int_i                             : in  std_logic;

      --FMC Present status
      prsnt_m2c_l_i                           : in  std_logic;

      -- ADC output signals
      adc_dout_o                              : out std_logic_vector(31 downto 0);
      clk_adc_o                               : out std_logic;

      -- Wishbone Streaming Interface Source
      wbs_adr_o                               : out std_logic_vector(c_wbs_address_width-1 downto 0);
      wbs_dat_o                               : out std_logic_vector(c_wbs_data_width-1 downto 0);
      wbs_cyc_o                               : out std_logic;
      wbs_stb_o                               : out std_logic;
      wbs_we_o                                : out std_logic;
      wbs_sel_o                               : out std_logic_vector((c_wbs_data_width/8)-1 downto 0);

      wbs_ack_i                               : in std_logic;
      wbs_stall_i                             : in std_logic;
      wbs_err_i                               : in std_logic;
      wbs_rty_i                               : in std_logic
  );
  end component;

  component xwb_fmc150
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := PIPELINED;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_packet_size                             : natural := 32;
    g_sim                                     : integer := 0
  );
  port
  (
    rst_n_i                                   : in std_logic;
    clk_sys_i                                 : in std_logic;
    --clk_100Mhz_i                              : in std_logic;
    clk_200Mhz_i                              : in std_logic;

    -----------------------------
    -- Wishbone signals
    -----------------------------

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- Simulation Only ports
    -----------------------------
    sim_adc_clk_i                             : in std_logic;
    sim_adc_clk2x_i                           : in std_logic;

    sim_adc_cha_data_i                        : in std_logic_vector(13 downto 0);
    sim_adc_chb_data_i                        : in std_logic_vector(13 downto 0);
    sim_adc_data_valid                        : in std_logic;

    -----------------------------
    -- External ports
    -----------------------------
    --Clock/Data connection to ADC on FMC150 (ADS62P49)
    adc_clk_ab_p_i                            : in  std_logic;
    adc_clk_ab_n_i                            : in  std_logic;
    adc_cha_p_i                               : in  std_logic_vector(6 downto 0);
    adc_cha_n_i                               : in  std_logic_vector(6 downto 0);
    adc_chb_p_i                               : in  std_logic_vector(6 downto 0);
    adc_chb_n_i                               : in  std_logic_vector(6 downto 0);

    --Clock/Data connection to DAC on FMC150 (DAC3283)
    dac_dclk_p_o                              : out std_logic;
    dac_dclk_n_o                              : out std_logic;
    dac_data_p_o                              : out std_logic_vector(7 downto 0);
    dac_data_n_o                              : out std_logic_vector(7 downto 0);
    dac_frame_p_o                             : out std_logic;
    dac_frame_n_o                             : out std_logic;
    txenable_o                                : out std_logic;

    --Clock/Trigger connection to FMC150
    --clk_to_fpga_p           : in  std_logic;
    --clk_to_fpga_n           : in  std_logic;
    --ext_trigger_p           : in  std_logic;
    --ext_trigger_n           : in  std_logic;

    -- Control signals from/to FMC150
    --Serial Peripheral Interface (SPI)
    spi_sclk_o                                : out std_logic; -- Shared SPI clock line
    spi_sdata_o                               : out std_logic; -- Shared SPI data line

    -- ADC specific signals
    adc_n_en_o                                : out std_logic; -- SPI chip select
    adc_sdo_i                                 : in  std_logic; -- SPI data out
    adc_reset_o                               : out std_logic; -- SPI reset

    -- CDCE specific signals
    cdce_n_en_o                               : out std_logic; -- SPI chip select
    cdce_sdo_i                                : in  std_logic; -- SPI data out
    cdce_n_reset_o                            : out std_logic;
    cdce_n_pd_o                               : out std_logic;
    cdce_ref_en_o                             : out std_logic;
    cdce_pll_status_i                         : in  std_logic;

    -- DAC specific signals
    dac_n_en_o                                : out std_logic; -- SPI chip select
    dac_sdo_i                                 : in  std_logic; -- SPI data out

    -- Monitoring specific signals
    mon_n_en_o                                : out std_logic; -- SPI chip select
    mon_sdo_i                                 : in  std_logic; -- SPI data out
    mon_n_reset_o                             : out std_logic;
    mon_n_int_i                               : in  std_logic;

    --FMC Present status
    prsnt_m2c_l_i                             : in  std_logic;

    -- ADC output signals
    adc_dout_o                                : out std_logic_vector(31 downto 0);
    clk_adc_o                                 : out std_logic;

    -- Wishbone Streaming Interface Source
    wbs_source_i                              : in t_wbs_source_in;
    wbs_source_o                              : out t_wbs_source_out
  );
  end component;

  component wb_fmc516
  generic
  (
      -- The only supported values are VIRTEX6 and 7SERIES
    g_fpga_device                             : string := "VIRTEX6";
    g_delay_type                              : string := "VARIABLE";
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_adc_clk_period_values                   : t_clk_values_array := default_adc_clk_period_values;
    g_use_clk_chains                          : t_clk_use_chain := dummy_clk_use_chain;
    g_use_data_chains                         : t_data_use_chain := dummy_data_use_chain;
    g_map_clk_data_chains                     : t_map_clk_data_chain := default_map_clk_data_chain;
    g_ref_clk                                 : t_ref_adc_clk := default_ref_adc_clk;
    g_packet_size                             : natural := 32;
    g_with_idelayctrl                         : boolean := true;
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
    -- System I2C Bus. Slaves: Atmel AT24C512B Serial EEPROM,
    -- AD7417 temperature diodes and AD7417 supply rails
    sys_i2c_scl_b                             : inout std_logic;
    sys_i2c_sda_b                             : inout std_logic;

    -- ADC clocks. One clock per ADC channel.
    -- Only ch0 clock is used as all data chains
    -- are sampled at the same frequency
    adc_clk0_p_i                              : in std_logic;
    adc_clk0_n_i                              : in std_logic;
    adc_clk1_p_i                              : in std_logic;
    adc_clk1_n_i                              : in std_logic;
    adc_clk2_p_i                              : in std_logic;
    adc_clk2_n_i                              : in std_logic;
    adc_clk3_p_i                              : in std_logic;
    adc_clk3_n_i                              : in std_logic;

    -- DDR ADC data channels.
    adc_data_ch0_p_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch0_n_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch1_p_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch1_n_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch2_p_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch2_n_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch3_p_i                          : in std_logic_vector(7 downto 0);
    adc_data_ch3_n_i                          : in std_logic_vector(7 downto 0);

    -- ADC clock (half of the sampling frequency) divider reset
    adc_clk_div_rst_p_o                       : out std_logic;
    adc_clk_div_rst_n_o                       : out std_logic;

    -- FMC Front leds. Typical uses: Over Range or Full Scale
    -- condition.
    fmc_leds_o                                : out std_logic_vector(1 downto 0);

    -- ADC SPI control interface. Three-wire mode. Tri-stated data pin
    sys_spi_clk_o                             : out std_logic;
    sys_spi_data_b                            : inout std_logic;
    --sys_spi_dout_o                            : out std_logic;
    --sys_spi_din_i                             : in std_logic;
    sys_spi_cs_adc0_n_o                       : out std_logic;  -- SPI ADC CS channel 0
    sys_spi_cs_adc1_n_o                       : out std_logic;  -- SPI ADC CS channel 1
    sys_spi_cs_adc2_n_o                       : out std_logic;  -- SPI ADC CS channel 2
    sys_spi_cs_adc3_n_o                       : out std_logic;  -- SPI ADC CS channel 3
    --sys_spi_miosio_oe_n_o                     : out std_logic;

    -- External Trigger To/From FMC
    m2c_trig_p_i                              : in std_logic;
    m2c_trig_n_i                              : in std_logic;
    c2m_trig_p_o                              : out std_logic;
    c2m_trig_n_o                              : out std_logic;

    -- LMK (National Semiconductor) is the clock and distribution IC.
    -- SPI interface?
    lmk_lock_i                                : in std_logic;
    lmk_sync_o                                : out std_logic;
    lmk_uwire_latch_en_o                      : out std_logic;
    lmk_uwire_data_o                          : out std_logic;
    lmk_uwire_clock_o                         : out std_logic;

    -- Programable Si571 VCXO via I2C
    vcxo_i2c_sda_b                            : inout std_logic;
    vcxo_i2c_scl_b                            : inout std_logic;
    vcxo_pd_l_o                               : out std_logic;

    -- One-wire To/From DS2431 (VMETRO Data)
    fmc_id_dq_b                               : inout std_logic;
    -- One-wire To/From DS2432 SHA-1 (SP-Devices key)
    fmc_key_dq_b                              : inout std_logic;

    -- General board pins
    fmc_pwr_good_i                            : in std_logic;
    -- Internal/External clock distribution selection
    fmc_clk_sel_o                             : out std_logic;
    -- Reset ADCs
    fmc_reset_adcs_n_o                        : out std_logic;
    --FMC Present status
    fmc_prsnt_m2c_l_i                         : in  std_logic;

    -----------------------------
    -- Optional external reference clock ports
    -----------------------------
    fmc_ext_ref_clk_i                         : in std_logic := '0';
    fmc_ext_ref_clk2x_i                       : in std_logic := '0';
    fmc_ext_ref_mmcm_locked_i                 : in std_logic := '0';

    -----------------------------
    -- ADC output signals. Continuous flow
    -----------------------------
    adc_clk_o                                 : out std_logic_vector(c_num_adc_channels-1 downto 0);
    adc_clk2x_o                               : out std_logic_vector(c_num_adc_channels-1 downto 0);
    adc_rst_n_o                               : out std_logic_vector(c_num_adc_channels-1 downto 0);
    adc_data_o                                : out std_logic_vector(c_num_adc_channels*c_num_adc_bits-1 downto 0);
    adc_data_valid_o                          : out std_logic_vector(c_num_adc_channels-1 downto 0);

    -----------------------------
    -- General ADC output signals
    -----------------------------
    -- Trigger to other FPGA logic
    trig_hw_o                                 : out std_logic;
    trig_hw_i                                 : in std_logic;

    -- General board status
    fmc_mmcm_lock_o                           : out std_logic;
    fmc_lmk_lock_o                            : out std_logic;

    -----------------------------
    -- Wishbone Streaming Interface Source
    -----------------------------
    wbs_adr_o                                : out std_logic_vector(c_num_adc_channels*c_wbs_adr4_width-1 downto 0);
    wbs_dat_o                                : out std_logic_vector(c_num_adc_channels*c_wbs_dat16_width-1 downto 0);
    wbs_cyc_o                                : out std_logic_vector(c_num_adc_channels-1 downto 0);
    wbs_stb_o                                : out std_logic_vector(c_num_adc_channels-1 downto 0);
    wbs_we_o                                 : out std_logic_vector(c_num_adc_channels-1 downto 0);
    wbs_sel_o                                : out std_logic_vector(c_num_adc_channels*c_wbs_sel16_width-1 downto 0);
    wbs_ack_i                                : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
    wbs_stall_i                              : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
    wbs_err_i                                : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');
    wbs_rty_i                                : in std_logic_vector(c_num_adc_channels-1 downto 0) := (others => '0');

    adc_dly_debug_o                          : out t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);

    fifo_debug_valid_o                       : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_full_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_empty_o                       : out std_logic_vector(c_num_adc_channels-1 downto 0)
  );
  end component;

  component xwb_fmc516
  generic
  (
    -- The only supported values are VIRTEX6 and 7SERIES
    g_fpga_device                             : string := "VIRTEX6";
    g_delay_type                              : string := "VARIABLE";
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_adc_clk_period_values                   : t_clk_values_array := default_adc_clk_period_values;
    g_use_clk_chains                          : t_clk_use_chain := dummy_clk_use_chain;
    g_use_data_chains                         : t_data_use_chain := dummy_data_use_chain;
    g_map_clk_data_chains                     : t_map_clk_data_chain := default_map_clk_data_chain;
    g_ref_clk                                 : t_ref_adc_clk := default_ref_adc_clk;
    g_packet_size                             : natural := 32;
    g_with_idelayctrl                         : boolean := true;
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

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------
    -- System I2C Bus. Slaves: Atmel AT24C512B Serial EEPROM,
    -- AD7417 temperature diodes and AD7417 supply rails
    sys_i2c_scl_b                             : inout std_logic;
    sys_i2c_sda_b                             : inout std_logic;

    -- ADC clocks. One clock per ADC channel.
    -- Only ch1 clock is used as all data chains
    -- are sampled at the same frequency
    adc_clk0_p_i                              : in std_logic;
    adc_clk0_n_i                              : in std_logic;
    adc_clk1_p_i                              : in std_logic;
    adc_clk1_n_i                              : in std_logic;
    adc_clk2_p_i                              : in std_logic;
    adc_clk2_n_i                              : in std_logic;
    adc_clk3_p_i                              : in std_logic;
    adc_clk3_n_i                              : in std_logic;

    -- DDR ADC data channels.
    adc_data_ch0_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch0_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch1_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch1_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch2_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch2_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch3_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);
    adc_data_ch3_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0);

    -- ADC clock (half of the sampling frequency) divider reset
    adc_clk_div_rst_p_o                       : out std_logic;
    adc_clk_div_rst_n_o                       : out std_logic;

    -- FMC Front leds. Typical uses: Over Range or Full Scale
    -- condition.
    fmc_leds_o                                : out std_logic_vector(1 downto 0);

    -- ADC SPI control interface. Three-wire mode. Tri-stated data pin
    sys_spi_clk_o                             : out std_logic;
    sys_spi_data_b                            : inout std_logic;
    --sys_spi_dout_o                            : out std_logic;
    --sys_spi_din_i                             : in std_logic;
    sys_spi_cs_adc0_n_o                       : out std_logic;  -- SPI ADC CS channel 0
    sys_spi_cs_adc1_n_o                       : out std_logic;  -- SPI ADC CS channel 1
    sys_spi_cs_adc2_n_o                       : out std_logic;  -- SPI ADC CS channel 2
    sys_spi_cs_adc3_n_o                       : out std_logic;  -- SPI ADC CS channel 3
    --sys_spi_miosio_oe_n_o                     : out std_logic;

    -- External Trigger To/From FMC
    m2c_trig_p_i                              : in std_logic;
    m2c_trig_n_i                              : in std_logic;
    c2m_trig_p_o                              : out std_logic;
    c2m_trig_n_o                              : out std_logic;

    -- LMK (National Semiconductor) is the clock and distribution IC,
    -- programmable via Microwire Interface
    lmk_lock_i                                : in std_logic;
    lmk_sync_o                                : out std_logic;
    lmk_uwire_latch_en_o                      : out std_logic;
    lmk_uwire_data_o                          : out std_logic;
    lmk_uwire_clock_o                         : out std_logic;

    -- Programable VCXO via I2C
    vcxo_i2c_sda_b                            : inout std_logic;
    vcxo_i2c_scl_b                            : inout std_logic;
    vcxo_pd_l_o                               : out std_logic;

    -- One-wire To/From DS2431 (VMETRO Data)
    fmc_id_dq_b                               : inout std_logic;
    -- One-wire To/From DS2432 SHA-1 (SP-Devices key)
    fmc_key_dq_b                              : inout std_logic;

    -- General board pins
    fmc_pwr_good_i                            : in std_logic;
    -- Internal/External clock distribution selection
    fmc_clk_sel_o                             : out std_logic;
    -- Reset ADCs
    fmc_reset_adcs_n_o                        : out std_logic;
    --FMC Present status
    fmc_prsnt_m2c_l_i                         : in  std_logic;

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
    adc_data_o                                : out std_logic_vector(c_num_adc_channels*c_num_adc_bits-1 downto 0);
    adc_data_valid_o                          : out std_logic_vector(c_num_adc_channels-1 downto 0);

    -----------------------------
    -- General ADC output signals and status
    -----------------------------
    -- Trigger to other FPGA logic
    trig_hw_o                                 : out std_logic;
    trig_hw_i                                 : in std_logic;

    -- General board status
    fmc_mmcm_lock_o                           : out std_logic;
    fmc_lmk_lock_o                            : out std_logic;

    -----------------------------
    -- Wishbone Streaming Interface Source
    -----------------------------
    wbs_source_i                              : in t_wbs_source_in16_array(c_num_adc_channels-1 downto 0);
    wbs_source_o                              : out t_wbs_source_out16_array(c_num_adc_channels-1 downto 0);

    adc_dly_debug_o                           : out t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);

    fifo_debug_valid_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_full_o                         : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_empty_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0)
  );
  end component;

  component wb_fmc130m_4ch
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
  end component;

  component xwb_fmc130m_4ch
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

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

    -- ADC LTC2208 interface
    fmc_adc_pga_o                             : out std_logic;
    fmc_adc_shdn_o                            : out std_logic;
    fmc_adc_dith_o                            : out std_logic;
    fmc_adc_rand_o                            : out std_logic;

    -- ADC0 LTC2208
    fmc_adc0_clk_i                            : in std_logic;
    fmc_adc0_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0);
    fmc_adc0_of_i                             : in std_logic; -- Unused

    -- ADC1 LTC2208
    fmc_adc1_clk_i                            : in std_logic;
    fmc_adc1_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0);
    fmc_adc1_of_i                             : in std_logic; -- Unused

    -- ADC2 LTC2208
    fmc_adc2_clk_i                            : in std_logic;
    fmc_adc2_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0);
    fmc_adc2_of_i                             : in std_logic; -- Unused

    -- ADC3 LTC2208
    fmc_adc3_clk_i                            : in std_logic;
    fmc_adc3_data_i                           : in std_logic_vector(c_num_adc_bits-1 downto 0);
    fmc_adc3_of_i                             : in std_logic; -- Unused

    -- FMC General Status
    fmc_prsnt_i                               : in std_logic;
    fmc_pg_m2c_i                              : in std_logic;
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
    spi_ad9510_miso_i                         : in std_logic;

    fmc_pll_function_o                        : out std_logic;
    fmc_pll_status_i                          : in std_logic;

    -- AD9510 clock copy
    fmc_fpga_clk_p_i                          : in std_logic;
    fmc_fpga_clk_n_i                          : in std_logic;

    -- Clock reference selection (TS3USB221)
    fmc_clk_sel_o                             : out std_logic;

    -- EEPROM
    eeprom_scl_pad_b                          : inout std_logic;
    eeprom_sda_pad_b                          : inout std_logic;

    -- Temperature monitor
    -- LM75AIMM
    lm75_scl_pad_b                            : inout std_logic;
    lm75_sda_pad_b                            : inout std_logic;

    fmc_lm75_temp_alarm_i                     : in std_logic;

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
    wbs_source_i                              : in t_wbs_source_in16_array(c_num_adc_channels-1 downto 0);
    wbs_source_o                              : out t_wbs_source_out16_array(c_num_adc_channels-1 downto 0);

    adc_dly_debug_o                          : out t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);

    fifo_debug_valid_o                       : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_full_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_empty_o                       : out std_logic_vector(c_num_adc_channels-1 downto 0)
  );
  end component;

  component wb_fmc250m_4ch
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

    -- ADC clock (half of the sampling frequency) divider reset
    adc_clk_div_rst_p_o                       : out std_logic;
    adc_clk_div_rst_n_o                       : out std_logic;
    adc_ext_rst_n_o                           : out std_logic;
    adc_sleep_o                               : out std_logic;

    -- ADC clocks. One clock per ADC channel.
    -- Only ch1 clock is used as all data chains
    -- are sampled at the same frequency
    adc_clk0_p_i                              : in std_logic := '0';
    adc_clk0_n_i                              : in std_logic := '0';
    adc_clk1_p_i                              : in std_logic := '0';
    adc_clk1_n_i                              : in std_logic := '0';
    adc_clk2_p_i                              : in std_logic := '0';
    adc_clk2_n_i                              : in std_logic := '0';
    adc_clk3_p_i                              : in std_logic := '0';
    adc_clk3_n_i                              : in std_logic := '0';

    -- DDR ADC data channels.
    adc_data_ch0_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch0_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch1_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch1_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch2_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch2_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch3_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch3_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');

    -- FMC General Status
    fmc_prsnt_i                               : in std_logic := '0';
    fmc_pg_m2c_i                              : in std_logic := '0';
    --fmc_clk_dir_i                           : in std_logic;

    -- Trigger
    fmc_trig_dir_o                            : out std_logic;
    fmc_trig_term_o                           : out std_logic;
    fmc_trig_val_p_b                          : inout std_logic;
    fmc_trig_val_n_b                          : inout std_logic;

    -- ADC SPI control interface. Three-wire mode. Tri-stated data pin
    adc_spi_clk_o                             : out std_logic;
    adc_spi_mosi_o                            : out std_logic;
    adc_spi_miso_i                            : in std_logic;
    adc_spi_cs_adc0_n_o                       : out std_logic;  -- SPI ADC CS channel 0
    adc_spi_cs_adc1_n_o                       : out std_logic;  -- SPI ADC CS channel 1
    adc_spi_cs_adc2_n_o                       : out std_logic;  -- SPI ADC CS channel 2
    adc_spi_cs_adc3_n_o                       : out std_logic;  -- SPI ADC CS channel 3

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

    -- AMC7823 temperature monitor
    amc7823_spi_cs_o                          : out std_logic;
    amc7823_spi_sclk_o                        : out std_logic;
    amc7823_spi_mosi_o                        : out std_logic;
    amc7823_spi_miso_i                        : in std_logic;
    amc7823_davn_i                            : in std_logic;

    -- FMC LEDs
    fmc_led1_o                                : out std_logic;
    fmc_led2_o                                : out std_logic;
    fmc_led3_o                                : out std_logic;

    -----------------------------
    -- Optional external reference clock ports
    -----------------------------
    fmc_ext_ref_clk_i                         : in std_logic := '0';
    fmc_ext_ref_clk2x_i                       : in std_logic := '0';
    fmc_ext_ref_mmcm_locked_i                 : in std_logic := '0';

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
  end component;

  component xwb_fmc250m_4ch
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

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

    -- ADC clock (half of the sampling frequency) divider reset
    adc_clk_div_rst_p_o                       : out std_logic;
    adc_clk_div_rst_n_o                       : out std_logic;
    adc_ext_rst_n_o                           : out std_logic;
    adc_sleep_o                               : out std_logic;

    -- ADC clocks. One clock per ADC channel.
    -- Only ch1 clock is used as all data chains
    -- are sampled at the same frequency
    adc_clk0_p_i                              : in std_logic := '0';
    adc_clk0_n_i                              : in std_logic := '0';
    adc_clk1_p_i                              : in std_logic := '0';
    adc_clk1_n_i                              : in std_logic := '0';
    adc_clk2_p_i                              : in std_logic := '0';
    adc_clk2_n_i                              : in std_logic := '0';
    adc_clk3_p_i                              : in std_logic := '0';
    adc_clk3_n_i                              : in std_logic := '0';

    -- DDR ADC data channels.
    adc_data_ch0_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch0_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch1_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch1_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch2_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch2_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch3_p_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');
    adc_data_ch3_n_i                          : in std_logic_vector(c_num_adc_bits/2-1 downto 0) := (others => '0');

    -- FMC General Status
    fmc_prsnt_i                               : in std_logic := '0';
    fmc_pg_m2c_i                              : in std_logic := '0';
    --fmc_clk_dir_i                           : in std_logic;

    -- Trigger
    fmc_trig_dir_o                            : out std_logic;
    fmc_trig_term_o                           : out std_logic;
    fmc_trig_val_p_b                          : inout std_logic;
    fmc_trig_val_n_b                          : inout std_logic;

    -- ADC SPI control interface. Three-wire mode. Tri-stated data pin
    adc_spi_clk_o                             : out std_logic;
    adc_spi_mosi_o                            : out std_logic;
    adc_spi_miso_i                            : in std_logic;
    adc_spi_cs_adc0_n_o                       : out std_logic;  -- SPI ADC CS channel 0
    adc_spi_cs_adc1_n_o                       : out std_logic;  -- SPI ADC CS channel 1
    adc_spi_cs_adc2_n_o                       : out std_logic;  -- SPI ADC CS channel 2
    adc_spi_cs_adc3_n_o                       : out std_logic;  -- SPI ADC CS channel 3

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

    -- AMC7823 temperature monitor
    amc7823_spi_cs_o                          : out std_logic;
    amc7823_spi_sclk_o                        : out std_logic;
    amc7823_spi_mosi_o                        : out std_logic;
    amc7823_spi_miso_i                        : in std_logic;
    amc7823_davn_i                            : in std_logic;

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
    wbs_source_i                              : in t_wbs_source_in16_array(c_num_adc_channels-1 downto 0);
    wbs_source_o                              : out t_wbs_source_out16_array(c_num_adc_channels-1 downto 0);

    adc_dly_debug_o                           : out t_adc_fn_dly_array(c_num_adc_channels-1 downto 0);

    fifo_debug_valid_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_full_o                         : out std_logic_vector(c_num_adc_channels-1 downto 0);
    fifo_debug_empty_o                        : out std_logic_vector(c_num_adc_channels-1 downto 0)
  );
  end component;

  component wb_fmcpico1m_4ch
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false;
    g_num_adc_bits                            : natural := 20;
    g_num_adc_channels                        : natural := 4;
    g_clk_freq                                : natural := 300000000; -- Hz
    g_sclk_freq                               : natural := 75000000 --Hz
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

    adc_fast_spi_clk_i                        : in std_logic;
    adc_fast_spi_rstn_i                       : in std_logic;

    -- Control signals
    adc_start_i                               : in std_logic;

    -- SPI bus
    adc_sdo1_i                                : in std_logic;
    adc_sdo2_i                                : in std_logic;
    adc_sdo3_i                                : in std_logic;
    adc_sdo4_i                                : in std_logic;
    adc_sck_o                                 : out std_logic;
    adc_sck_rtrn_i                            : in std_logic;
    adc_busy_cmn_i                            : in std_logic;
    adc_cnv_out_o                             : out std_logic;

    -- Range selection
    adc_rng_r1_o                              : out std_logic;
    adc_rng_r2_o                              : out std_logic;
    adc_rng_r3_o                              : out std_logic;
    adc_rng_r4_o                              : out std_logic;

    -- Board LEDs
    fmc_led1_o                                : out std_logic;
    fmc_led2_o                                : out std_logic;

    -----------------------------
    -- ADC output signals. Continuous flow
    -----------------------------
    -- clock to CDC. This must be g_sclk_freq/g_num_adc_bits. A regular 100MHz should
    -- suffice in all cases
    adc_clk_i                                 : in std_logic;
    adc_data_o                                : out std_logic_vector(g_num_adc_channels*g_num_adc_bits-1 downto 0);
    adc_data_valid_o                          : out std_logic_vector(g_num_adc_channels-1 downto 0);
    adc_out_busy_o                            : out std_logic
  );
  end component;

  component xwb_fmcpico1m_4ch
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false;
    g_num_adc_bits                            : natural := 20;
    g_num_adc_channels                        : natural := 4;
    g_clk_freq                                : natural := 300000000; -- Hz
    g_sclk_freq                               : natural := 75000000 --Hz
  );
  port
  (
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;
    sys_clk_200Mhz_i                          : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

    adc_fast_spi_clk_i                        : in std_logic;
    adc_fast_spi_rstn_i                       : in std_logic;

    -- Control signals
    adc_start_i                               : in std_logic;

    -- SPI bus
    adc_sdo1_i                                : in std_logic;
    adc_sdo2_i                                : in std_logic;
    adc_sdo3_i                                : in std_logic;
    adc_sdo4_i                                : in std_logic;
    adc_sck_o                                 : out std_logic;
    adc_sck_rtrn_i                            : in std_logic;
    adc_busy_cmn_i                            : in std_logic;
    adc_cnv_out_o                             : out std_logic;

    -- Range selection
    adc_rng_r1_o                              : out std_logic;
    adc_rng_r2_o                              : out std_logic;
    adc_rng_r3_o                              : out std_logic;
    adc_rng_r4_o                              : out std_logic;

    -- Board LEDs
    fmc_led1_o                                : out std_logic;
    fmc_led2_o                                : out std_logic;

    -----------------------------
    -- ADC output signals. Continuous flow
    -----------------------------
    -- clock to CDC. This must be g_sclk_freq/g_num_adc_bits. A regular 100MHz should
    -- suffice in all cases
    adc_clk_i                                 : in std_logic;
    adc_data_o                                : out std_logic_vector(g_num_adc_channels*g_num_adc_bits-1 downto 0);
    adc_data_valid_o                          : out std_logic_vector(g_num_adc_channels-1 downto 0);
    adc_out_busy_o                            : out std_logic

  );
  end component;

  component xwb_ethmac_adapter
  port(
    clk_i                                     : in std_logic;
    rstn_i                                    : in std_logic;

    wb_slave_o                                : out t_wishbone_slave_out;
    wb_slave_i                                : in t_wishbone_slave_in;

    tx_ram_o                                  : out t_wishbone_master_out;
    tx_ram_i                                  : in t_wishbone_master_in;

    rx_ram_o                                  : out t_wishbone_master_out;
    rx_ram_i                                  : in t_wishbone_master_in;

    rx_eb_o                                   : out t_wrf_source_out;
    rx_eb_i                                   : in t_wrf_source_in;

    tx_eb_o                                   : out t_wrf_sink_out;
    tx_eb_i                                   : in t_wrf_sink_in;

    irq_tx_done_o                             : out std_logic;
    irq_rx_done_o                             : out std_logic
  );
  end component;

  component wb_dbe_periph
  generic(
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_cntr_period                             : integer                        := 100000; -- 100MHz clock, ms granularity
    g_num_leds                                : natural                        := 8;
    g_with_led_heartbeat                      : t_boolean_array                ;          -- must match g_num_leds width
    g_num_buttons                             : natural                        := 8
  );
  port(
    clk_sys_i                                 : in std_logic;
    rst_n_i                                   : in std_logic;

    -- UART
    uart_rxd_i                                : in  std_logic;
    uart_txd_o                                : out std_logic;

    -- LEDs
    led_out_o                                 : out std_logic_vector(g_num_leds-1 downto 0);
    led_in_i                                  : in  std_logic_vector(g_num_leds-1 downto 0);
    led_oen_o                                 : out std_logic_vector(g_num_leds-1 downto 0);

    -- Buttons
    button_out_o                              : out std_logic_vector(g_num_buttons-1 downto 0);
    button_in_i                               : in  std_logic_vector(g_num_buttons-1 downto 0);
    button_oen_o                              : out std_logic_vector(g_num_buttons-1 downto 0);

    -- Wishbone
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
    wb_stall_o                                : out std_logic
  );
  end component;

  component xwb_dbe_periph
  generic(
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_cntr_period                             : integer                        := 100000; -- 100MHz clock, ms granularity
    g_num_leds                                : natural                        := 8;
    g_with_led_heartbeat                      : t_boolean_array                ;          -- must match g_num_leds width
    g_num_buttons                             : natural                        := 8
  );
  port(
    clk_sys_i                                 : in std_logic;
    rst_n_i                                   : in std_logic;

    -- UART
    uart_rxd_i                                : in  std_logic;
    uart_txd_o                                : out std_logic;

    -- LEDs
    led_out_o                                 : out std_logic_vector(g_num_leds-1 downto 0);
    led_in_i                                  : in  std_logic_vector(g_num_leds-1 downto 0);
    led_oen_o                                 : out std_logic_vector(g_num_leds-1 downto 0);

    -- Buttons
    button_out_o                              : out std_logic_vector(g_num_buttons-1 downto 0);
    button_in_i                               : in  std_logic_vector(g_num_buttons-1 downto 0);
    button_oen_o                              : out std_logic_vector(g_num_buttons-1 downto 0);

    -- Wishbone
    slave_i                                   : in  t_wishbone_slave_in;
    slave_o                                   : out t_wishbone_slave_out
  );
  end component;

  component wb_rs232_syscon
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode      := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE
  );
  port(
    -- WISHBONE common
    wb_clk_i                                  : in std_logic;
    wb_rstn_i                                 : in std_logic;

    -- External ports
    rs232_rxd_i                               : in std_logic;
    rs232_txd_o                               : out std_logic;

    -- Reset to FPGA logic
    rstn_o                                    : out std_logic;

    -- WISHBONE master
    m_wb_adr_o                                : out std_logic_vector(31 downto 0);
    m_wb_sel_o                                : out std_logic_vector(3 downto 0);
    m_wb_we_o                                 : out std_logic;
    m_wb_dat_o                                : out std_logic_vector(31 downto 0);
    m_wb_dat_i                                : in std_logic_vector(31 downto 0);
    m_wb_cyc_o                                : out std_logic;
    m_wb_stb_o                                : out std_logic;
    m_wb_ack_i                                : in std_logic;
    m_wb_err_i                                : in std_logic;
    m_wb_stall_i                              : in std_logic;
    m_wb_rty_i                                : in std_logic
  );
  end component;

  component xwb_rs232_syscon
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode      := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE
  );
  port(
    -- WISHBONE common
    wb_clk_i                                  : in std_logic;
    wb_rstn_i                                 : in std_logic;

    -- External ports
    rs232_rxd_i                               : in std_logic;
    rs232_txd_o                               : out std_logic;

    -- Reset to FPGA logic
    rstn_o                                    : out std_logic;

    -- WISHBONE master
    wb_master_i                               : in t_wishbone_master_in;
    wb_master_o                               : out t_wishbone_master_out
  );
  end component;

  component wb_acq_core
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_acq_channels                            : t_acq_chan_param_array := c_default_acq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : natural := 2048;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    fs_clk_i                                  : in std_logic;
    fs_ce_i                                   : in std_logic;
    fs_rst_n_i                                : in std_logic;

    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

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
    -- External Interface
    -----------------------------
    acq_val_low_i                             : in t_acq_val_half_array(g_acq_num_channels-1 downto 0);
    acq_val_high_i                            : in t_acq_val_half_array(g_acq_num_channels-1 downto 0);
    acq_dvalid_i                              : in std_logic_vector(g_acq_num_channels-1 downto 0);
    acq_id_i                                  : in t_acq_id_array(g_acq_num_channels-1 downto 0);
    acq_trig_i                                : in std_logic_vector(g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_o                              : out std_logic_vector(f_acq_chan_find_widest(g_acq_channels)-1 downto 0);
    dpram_valid_o                             : out std_logic;

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_o                                : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ext_valid_o                               : out std_logic;
    ext_addr_o                                : out std_logic_vector(g_acq_addr_width-1 downto 0);
    ext_sof_o                                 : out std_logic;
    ext_eof_o                                 : out std_logic;
    ext_dreq_o                                : out std_logic; -- for debbuging purposes
    ext_stall_o                               : out std_logic; -- for debbuging purposes

    -----------------------------
    -- Xilinx UI DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    ui_app_addr_o                             : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ui_app_cmd_o                              : out std_logic_vector(2 downto 0);
    ui_app_en_o                               : out std_logic;
    ui_app_rdy_i                              : in std_logic := '0';

    ui_app_wdf_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ui_app_wdf_end_o                          : out std_logic;
    ui_app_wdf_mask_o                         : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    ui_app_wdf_wren_o                         : out std_logic;
    ui_app_wdf_rdy_i                          : in std_logic := '0';

    ui_app_rd_data_i                          : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    ui_app_rd_data_end_i                      : in std_logic := '0';
    ui_app_rd_data_valid_i                    : in std_logic := '0';

    ui_app_req_o                              : out std_logic;
    ui_app_gnt_i                              : in std_logic := '0';

    -----------------------------
    -- AXIS DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    axis_s2mm_cmd_tdata_o                     : out std_logic_vector(71 downto 0);
    axis_s2mm_cmd_tvalid_o                    : out std_logic;
    axis_s2mm_cmd_tready_i                    : in std_logic := '0';

    axis_s2mm_pld_tdata_o                     : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    axis_s2mm_pld_tkeep_o                     : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    axis_s2mm_pld_tlast_o                     : out std_logic;
    axis_s2mm_pld_tvalid_o                    : out std_logic;
    axis_s2mm_pld_tready_i                    : in std_logic := '0';

    axis_s2mm_rstn_o                          : out std_logic;
    axis_s2mm_halt_o                          : out std_logic;
    axis_s2mm_halt_cmplt_i                    : in  std_logic := '0';
    axis_s2mm_allow_addr_req_o                : out std_logic;
    axis_s2mm_addr_req_posted_i               : in  std_logic := '0';
    axis_s2mm_wr_xfer_cmplt_i                 : in  std_logic := '0';
    axis_s2mm_ld_nxt_len_i                    : in  std_logic := '0';
    axis_s2mm_wr_len_i                        : in  std_logic_vector(7 downto 0) := (others => '0');

    axis_mm2s_cmd_tdata_o                     : out std_logic_vector(71 downto 0);
    axis_mm2s_cmd_tvalid_o                    : out std_logic;
    axis_mm2s_cmd_tready_i                    : in std_logic := '0';

    axis_mm2s_pld_tdata_i                     : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    axis_mm2s_pld_tkeep_i                     : in std_logic_vector(g_ddr_payload_width/8-1 downto 0) := (others => '0');
    axis_mm2s_pld_tlast_i                     : in std_logic := '0';
    axis_mm2s_pld_tvalid_i                    : in std_logic := '0';
    axis_mm2s_pld_tready_o                    : out std_logic;

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_i                      : in std_logic := '0';
    dbg_ddr_rb_rdy_o                          : out std_logic;
    dbg_ddr_rb_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_o                         : out std_logic_vector(g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_o                        : out std_logic
  );
  end component;

  component xwb_acq_core
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_acq_channels                            : t_acq_chan_param_array := c_default_acq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : natural := 2048;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    fs_clk_i                                  : in std_logic;
    fs_ce_i                                   : in std_logic;
    fs_rst_n_i                                : in std_logic;

    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External Interface
    -----------------------------
    acq_chan_array_i                          : in t_acq_chan_array(g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_o                              : out std_logic_vector(f_acq_chan_find_widest(g_acq_channels)-1 downto 0);
    dpram_valid_o                             : out std_logic;

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_o                                : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ext_valid_o                               : out std_logic;
    ext_addr_o                                : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ext_sof_o                                 : out std_logic;
    ext_eof_o                                 : out std_logic;
    ext_dreq_o                                : out std_logic; -- for debbuging purposes
    ext_stall_o                               : out std_logic; -- for debbuging purposes

    -----------------------------
    -- Xilinx UI DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    ui_app_addr_o                             : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ui_app_cmd_o                              : out std_logic_vector(2 downto 0);
    ui_app_en_o                               : out std_logic;
    ui_app_rdy_i                              : in std_logic := '0';

    ui_app_wdf_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ui_app_wdf_end_o                          : out std_logic;
    ui_app_wdf_mask_o                         : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    ui_app_wdf_wren_o                         : out std_logic;
    ui_app_wdf_rdy_i                          : in std_logic := '0';

    ui_app_rd_data_i                          : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    ui_app_rd_data_end_i                      : in std_logic := '0';
    ui_app_rd_data_valid_i                    : in std_logic := '0';

    ui_app_req_o                              : out std_logic;
    ui_app_gnt_i                              : in std_logic := '0';

    -----------------------------
    -- AXIS DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    -- AXIS Read Channel
    axis_mm2s_cmd_ma_i                        : in t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
    axis_mm2s_cmd_ma_o                        : out t_axis_cmd_master_out;
    axis_mm2s_pld_sl_i                        : in t_axis_pld_slave_in := cc_dummy_axis_pld_slave_in;
    axis_mm2s_pld_sl_o                        : out t_axis_pld_slave_out;
    -- AXIMM Write Channel
    axis_s2mm_cmd_ma_i                        : in t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
    axis_s2mm_cmd_ma_o                        : out t_axis_cmd_master_out;
    axis_s2mm_pld_ma_i                        : in t_axis_pld_master_in := cc_dummy_axis_pld_master_in;
    axis_s2mm_pld_ma_o                        : out t_axis_pld_master_out;

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_i                      : in std_logic := '0';
    dbg_ddr_rb_rdy_o                          : out std_logic;
    dbg_ddr_rb_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_o                         : out std_logic_vector(g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_o                        : out std_logic
  );
  end component;

  component wb_facq_core
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_facq_channels                           : t_facq_chan_param_array := c_default_facq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : natural := 2048;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    fs_clk_i                                  : in std_logic;
    fs_ce_i                                   : in std_logic;
    fs_rst_n_i                                : in std_logic;

    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

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
    -- External Interface
    -----------------------------
    acq_val_i                                 : in t_acq_val_cmplt_array(g_acq_num_channels-1 downto 0);
    acq_dvalid_i                              : in std_logic_vector(g_acq_num_channels-1 downto 0);
    acq_trig_i                                : in std_logic_vector(g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_o                              : out std_logic_vector(f_acq_chan_find_widest(f_conv_facq_to_acq_chan_array(g_facq_channels))-1 downto 0);
    dpram_valid_o                             : out std_logic;

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_o                                : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ext_valid_o                               : out std_logic;
    ext_addr_o                                : out std_logic_vector(g_acq_addr_width-1 downto 0);
    ext_sof_o                                 : out std_logic;
    ext_eof_o                                 : out std_logic;
    ext_dreq_o                                : out std_logic; -- for debbuging purposes
    ext_stall_o                               : out std_logic; -- for debbuging purposes

    -----------------------------
    -- Xilinx UI DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    ui_app_addr_o                             : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ui_app_cmd_o                              : out std_logic_vector(2 downto 0);
    ui_app_en_o                               : out std_logic;
    ui_app_rdy_i                              : in std_logic := '0';

    ui_app_wdf_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ui_app_wdf_end_o                          : out std_logic;
    ui_app_wdf_mask_o                         : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    ui_app_wdf_wren_o                         : out std_logic;
    ui_app_wdf_rdy_i                          : in std_logic := '0';

    ui_app_rd_data_i                          : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    ui_app_rd_data_end_i                      : in std_logic := '0';
    ui_app_rd_data_valid_i                    : in std_logic := '0';

    ui_app_req_o                              : out std_logic;
    ui_app_gnt_i                              : in std_logic := '0';

    -----------------------------
    -- AXIS DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    axis_s2mm_cmd_tdata_o                     : out std_logic_vector(71 downto 0);
    axis_s2mm_cmd_tvalid_o                    : out std_logic;
    axis_s2mm_cmd_tready_i                    : in std_logic := '0';

    axis_s2mm_pld_tdata_o                     : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    axis_s2mm_pld_tkeep_o                     : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    axis_s2mm_pld_tlast_o                     : out std_logic;
    axis_s2mm_pld_tvalid_o                    : out std_logic;
    axis_s2mm_pld_tready_i                    : in std_logic := '0';

    axis_s2mm_rstn_o                          : out std_logic;
    axis_s2mm_halt_o                          : out std_logic;
    axis_s2mm_halt_cmplt_i                    : in  std_logic := '0';
    axis_s2mm_allow_addr_req_o                : out std_logic;
    axis_s2mm_addr_req_posted_i               : in  std_logic := '0';
    axis_s2mm_wr_xfer_cmplt_i                 : in  std_logic := '0';
    axis_s2mm_ld_nxt_len_i                    : in  std_logic := '0';
    axis_s2mm_wr_len_i                        : in  std_logic_vector(7 downto 0) := (others => '0');

    axis_mm2s_cmd_tdata_o                     : out std_logic_vector(71 downto 0);
    axis_mm2s_cmd_tvalid_o                    : out std_logic;
    axis_mm2s_cmd_tready_i                    : in std_logic := '0';

    axis_mm2s_pld_tdata_i                     : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    axis_mm2s_pld_tkeep_i                     : in std_logic_vector(g_ddr_payload_width/8-1 downto 0) := (others => '0');
    axis_mm2s_pld_tlast_i                     : in std_logic := '0';
    axis_mm2s_pld_tvalid_i                    : in std_logic := '0';
    axis_mm2s_pld_tready_o                    : out std_logic;

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_i                      : in std_logic := '0';
    dbg_ddr_rb_rdy_o                          : out std_logic;
    dbg_ddr_rb_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_o                         : out std_logic_vector(g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_o                        : out std_logic
  );
  end component;

  component xwb_facq_core
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_facq_channels                           : t_facq_chan_param_array := c_default_facq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : natural := 2048;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    fs_clk_i                                  : in std_logic;
    fs_ce_i                                   : in std_logic;
    fs_rst_n_i                                : in std_logic;

    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External Interface
    -----------------------------
    acq_chan_array_i                          : in t_facq_chan_array(g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_o                              : out std_logic_vector(f_acq_chan_find_widest(f_conv_facq_to_acq_chan_array(g_facq_channels))-1 downto 0);
    dpram_valid_o                             : out std_logic;

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_o                                : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ext_valid_o                               : out std_logic;
    ext_addr_o                                : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ext_sof_o                                 : out std_logic;
    ext_eof_o                                 : out std_logic;
    ext_dreq_o                                : out std_logic; -- for debbuging purposes
    ext_stall_o                               : out std_logic; -- for debbuging purposes

    -----------------------------
    -- Xilinx UI DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    ui_app_addr_o                             : out std_logic_vector(g_ddr_addr_width-1 downto 0);
    ui_app_cmd_o                              : out std_logic_vector(2 downto 0);
    ui_app_en_o                               : out std_logic;
    ui_app_rdy_i                              : in std_logic := '0';

    ui_app_wdf_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    ui_app_wdf_end_o                          : out std_logic;
    ui_app_wdf_mask_o                         : out std_logic_vector(g_ddr_payload_width/8-1 downto 0);
    ui_app_wdf_wren_o                         : out std_logic;
    ui_app_wdf_rdy_i                          : in std_logic := '0';

    ui_app_rd_data_i                          : in std_logic_vector(g_ddr_payload_width-1 downto 0) := (others => '0');
    ui_app_rd_data_end_i                      : in std_logic := '0';
    ui_app_rd_data_valid_i                    : in std_logic := '0';

    ui_app_req_o                              : out std_logic;
    ui_app_gnt_i                              : in std_logic := '0';

    -----------------------------
    -- AXIS DDR3 SDRAM Interface (choose between UI and AXIS with g_ddr_interface_type)
    -----------------------------
    -- AXIS Read Channel
    axis_mm2s_cmd_ma_i                        : in t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
    axis_mm2s_cmd_ma_o                        : out t_axis_cmd_master_out;
    axis_mm2s_pld_sl_i                        : in t_axis_pld_slave_in := cc_dummy_axis_pld_slave_in;
    axis_mm2s_pld_sl_o                        : out t_axis_pld_slave_out;
    -- AXIMM Write Channel
    axis_s2mm_cmd_ma_i                        : in t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
    axis_s2mm_cmd_ma_o                        : out t_axis_cmd_master_out;
    axis_s2mm_pld_ma_i                        : in t_axis_pld_master_in := cc_dummy_axis_pld_master_in;
    axis_s2mm_pld_ma_o                        : out t_axis_pld_master_out;

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_i                      : in std_logic := '0';
    dbg_ddr_rb_rdy_o                          : out std_logic;
    dbg_ddr_rb_data_o                         : out std_logic_vector(g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_o                         : out std_logic_vector(g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_o                        : out std_logic
  );
  end component;

  component wb_facq_core_mux
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_facq_channels                           : t_facq_chan_param_array := c_default_facq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : t_property_value_array := c_default_multishot_ram_size;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_acq_num_cores                           : natural := 2;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    -- Clock signals
    fs_clk_array_i                            : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_ce_array_i                             : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_rst_n_array_i                          : in std_logic_vector(g_acq_num_cores-1 downto 0);

    -- Clock signals for Wishbone
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -- Clock signals for External Memory
    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------

    wb_adr_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_dat_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_data_width-1 downto 0) := (others => '0');
    wb_dat_array_o                            : out std_logic_vector(g_acq_num_cores*c_wishbone_data_width-1 downto 0);
    wb_sel_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_data_width/8-1 downto 0) := (others => '0');
    wb_we_array_i                             : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_cyc_array_i                            : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_stb_array_i                            : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_ack_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_err_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_rty_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_stall_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface
    -----------------------------
    acq_val_array_i                           : in t_acq_val_cmplt_array(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_dvalid_array_i                        : in std_logic_vector(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_trig_array_i                          : in std_logic_vector(g_acq_num_cores*g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_array_o                        : out std_logic_vector(g_acq_num_cores*f_acq_chan_find_widest(f_conv_facq_to_acq_chan_array(g_facq_channels))-1 downto 0);
    dpram_valid_array_o                       : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_array_o                          : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    ext_valid_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_addr_array_o                          : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    ext_sof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_eof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_dreq_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes
    ext_stall_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_array_i                : in std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    dbg_ddr_rb_rdy_array_o                    : out std_logic_vector(g_acq_num_cores-1 downto 0);
    dbg_ddr_rb_data_array_o                   : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_array_o                   : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_array_o                  : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- DDR3 SDRAM Interface
    -----------------------------
    ddr_aximm_ma_awid_o                       : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awaddr_o                     : out std_logic_vector (31 downto 0);
    ddr_aximm_ma_awlen_o                      : out std_logic_vector (7 downto 0);
    ddr_aximm_ma_awsize_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_awburst_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_ma_awlock_o                     : out std_logic;
    ddr_aximm_ma_awcache_o                    : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awprot_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_awqos_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awvalid_o                    : out std_logic;
    ddr_aximm_ma_awready_i                    : in std_logic;
    ddr_aximm_ma_wdata_o                      : out std_logic_vector (g_ddr_payload_width-1 downto 0);
    ddr_aximm_ma_wstrb_o                      : out std_logic_vector (g_ddr_payload_width/8-1 downto 0);
    ddr_aximm_ma_wlast_o                      : out std_logic;
    ddr_aximm_ma_wvalid_o                     : out std_logic;
    ddr_aximm_ma_wready_i                     : in std_logic;
    ddr_aximm_ma_bready_o                     : out std_logic;
    ddr_aximm_ma_bid_i                        : in std_logic_vector (3 downto 0);
    ddr_aximm_ma_bresp_i                      : in std_logic_vector (1 downto 0);
    ddr_aximm_ma_bvalid_i                     : in std_logic;
    ddr_aximm_ma_arid_o                       : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_araddr_o                     : out std_logic_vector (31 downto 0);
    ddr_aximm_ma_arlen_o                      : out std_logic_vector (7 downto 0);
    ddr_aximm_ma_arsize_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_arburst_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_ma_arlock_o                     : out std_logic;
    ddr_aximm_ma_arcache_o                    : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_arprot_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_arqos_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_arvalid_o                    : out std_logic;
    ddr_aximm_ma_arready_i                    : in std_logic;
    ddr_aximm_ma_rready_o                     : out std_logic;
    ddr_aximm_ma_rid_i                        : in std_logic_vector (3 downto 0);
    ddr_aximm_ma_rdata_i                      : in std_logic_vector (g_ddr_payload_width-1 downto 0);
    ddr_aximm_ma_rresp_i                      : in std_logic_vector (1 downto 0);
    ddr_aximm_ma_rlast_i                      : in std_logic;
    ddr_aximm_ma_rvalid_i                     : in std_logic
  );
  end component;

  component xwb_facq_core_mux
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_facq_channels                           : t_facq_chan_param_array := c_default_facq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : t_property_value_array := c_default_multishot_ram_size;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_acq_num_cores                           : natural := 2;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    -- Clock signals
    fs_clk_array_i                            : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_ce_array_i                             : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_rst_n_array_i                          : in std_logic_vector(g_acq_num_cores-1 downto 0);

    -- Clock signals for Wishbone
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -- Clock signals for External Memory
    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                  : in t_wishbone_slave_in_array(g_acq_num_cores-1 downto 0);
    wb_slv_o                                  : out t_wishbone_slave_out_array(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface
    -----------------------------
    acq_chan_array_i                          : in t_facq_chan_array2d(g_acq_num_cores-1 downto 0, g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_array_o                        : out std_logic_vector(g_acq_num_cores*f_acq_chan_find_widest(f_conv_facq_to_acq_chan_array(g_facq_channels))-1 downto 0);
    dpram_valid_array_o                       : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_array_o                          : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    ext_valid_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_addr_array_o                          : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    ext_sof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_eof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_dreq_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes
    ext_stall_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_array_i                : in std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    dbg_ddr_rb_rdy_array_o                    : out std_logic_vector(g_acq_num_cores-1 downto 0);
    dbg_ddr_rb_data_array_o                   : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_array_o                   : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_array_o                  : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- DDR3 SDRAM Interface
    -----------------------------
    -- AXIMM Read Channel
    ddr_aximm_r_ma_i                          : in t_aximm_r_master_in := cc_dummy_aximm_r_master_in;
    ddr_aximm_r_ma_o                          : out t_aximm_r_master_out;
    -- AXIMM Write Channel
    ddr_aximm_w_ma_i                          : in t_aximm_w_master_in := cc_dummy_aximm_w_master_in;
    ddr_aximm_w_ma_o                          : out t_aximm_w_master_out
  );
  end component;

  component wb_acq_core_mux
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_acq_channels                            : t_acq_chan_param_array := c_default_acq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : t_property_value_array := c_default_multishot_ram_size;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_acq_num_cores                           : natural := 2;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    -- Clock signals
    fs_clk_array_i                            : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_ce_array_i                             : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_rst_n_array_i                          : in std_logic_vector(g_acq_num_cores-1 downto 0);

    -- Clock signals for Wishbone
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -- Clock signals for External Memory
    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------

    wb_adr_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_dat_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_data_width-1 downto 0) := (others => '0');
    wb_dat_array_o                            : out std_logic_vector(g_acq_num_cores*c_wishbone_data_width-1 downto 0);
    wb_sel_array_i                            : in  std_logic_vector(g_acq_num_cores*c_wishbone_data_width/8-1 downto 0) := (others => '0');
    wb_we_array_i                             : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_cyc_array_i                            : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_stb_array_i                            : in  std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    wb_ack_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_err_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_rty_array_o                            : out std_logic_vector(g_acq_num_cores-1 downto 0);
    wb_stall_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface
    -----------------------------
    acq_val_low_array_i                       : in t_acq_val_half_array(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_val_high_array_i                      : in t_acq_val_half_array(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_dvalid_array_i                        : in std_logic_vector(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_id_array_i                            : in t_acq_id_array(g_acq_num_cores*g_acq_num_channels-1 downto 0);
    acq_trig_array_i                          : in std_logic_vector(g_acq_num_cores*g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_array_o                        : out std_logic_vector(g_acq_num_cores*f_acq_chan_find_widest(g_acq_channels)-1 downto 0);
    dpram_valid_array_o                       : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_array_o                          : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    ext_valid_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_addr_array_o                          : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    ext_sof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_eof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_dreq_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes
    ext_stall_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_array_i                : in std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    dbg_ddr_rb_rdy_array_o                    : out std_logic_vector(g_acq_num_cores-1 downto 0);
    dbg_ddr_rb_data_array_o                   : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_array_o                   : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_array_o                  : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- DDR3 SDRAM Interface
    -----------------------------
    ddr_aximm_ma_awid_o                       : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awaddr_o                     : out std_logic_vector (31 downto 0);
    ddr_aximm_ma_awlen_o                      : out std_logic_vector (7 downto 0);
    ddr_aximm_ma_awsize_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_awburst_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_ma_awlock_o                     : out std_logic;
    ddr_aximm_ma_awcache_o                    : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awprot_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_awqos_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_awvalid_o                    : out std_logic;
    ddr_aximm_ma_awready_i                    : in std_logic;
    ddr_aximm_ma_wdata_o                      : out std_logic_vector (g_ddr_payload_width-1 downto 0);
    ddr_aximm_ma_wstrb_o                      : out std_logic_vector (g_ddr_payload_width/8-1 downto 0);
    ddr_aximm_ma_wlast_o                      : out std_logic;
    ddr_aximm_ma_wvalid_o                     : out std_logic;
    ddr_aximm_ma_wready_i                     : in std_logic;
    ddr_aximm_ma_bready_o                     : out std_logic;
    ddr_aximm_ma_bid_i                        : in std_logic_vector (3 downto 0);
    ddr_aximm_ma_bresp_i                      : in std_logic_vector (1 downto 0);
    ddr_aximm_ma_bvalid_i                     : in std_logic;
    ddr_aximm_ma_arid_o                       : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_araddr_o                     : out std_logic_vector (31 downto 0);
    ddr_aximm_ma_arlen_o                      : out std_logic_vector (7 downto 0);
    ddr_aximm_ma_arsize_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_arburst_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_ma_arlock_o                     : out std_logic;
    ddr_aximm_ma_arcache_o                    : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_arprot_o                     : out std_logic_vector (2 downto 0);
    ddr_aximm_ma_arqos_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_ma_arvalid_o                    : out std_logic;
    ddr_aximm_ma_arready_i                    : in std_logic;
    ddr_aximm_ma_rready_o                     : out std_logic;
    ddr_aximm_ma_rid_i                        : in std_logic_vector (3 downto 0);
    ddr_aximm_ma_rdata_i                      : in std_logic_vector (g_ddr_payload_width-1 downto 0);
    ddr_aximm_ma_rresp_i                      : in std_logic_vector (1 downto 0);
    ddr_aximm_ma_rlast_i                      : in std_logic;
    ddr_aximm_ma_rvalid_i                     : in std_logic
  );
  end component;

  component xwb_acq_core_mux
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_acq_addr_width                          : natural := 32;
    g_acq_num_channels                        : natural := c_default_acq_num_channels;
    g_acq_channels                            : t_acq_chan_param_array := c_default_acq_chan_param_array;
    g_ddr_payload_width                       : natural := 256;     -- be careful changing these!
    g_ddr_dq_width                            : natural := 64;      -- be careful changing these!
    g_ddr_addr_width                          : natural := 32;      -- be careful changing these!
    g_multishot_ram_size                      : t_property_value_array := c_default_multishot_ram_size;
    g_fifo_fc_size                            : natural := 64;
    g_sim_readback                            : boolean := false;
    g_acq_num_cores                           : natural := 2;
    g_ddr_interface_type                      : string  := "AXIS";
    g_max_burst_size                          : natural := 4
  );
  port
  (
    -- Clock signals
    fs_clk_array_i                            : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_ce_array_i                             : in std_logic_vector(g_acq_num_cores-1 downto 0);
    fs_rst_n_array_i                          : in std_logic_vector(g_acq_num_cores-1 downto 0);

    -- Clock signals for Wishbone
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -- Clock signals for External Memory
    ext_clk_i                                 : in std_logic;
    ext_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                  : in t_wishbone_slave_in_array(g_acq_num_cores-1 downto 0);
    wb_slv_o                                  : out t_wishbone_slave_out_array(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface
    -----------------------------
    acq_chan_array_i                          : in t_acq_chan_array2d(g_acq_num_cores-1 downto 0, g_acq_num_channels-1 downto 0);

    -----------------------------
    -- DRRAM Interface
    -----------------------------
    dpram_dout_array_o                        : out std_logic_vector(g_acq_num_cores*f_acq_chan_find_widest(g_acq_channels)-1 downto 0);
    dpram_valid_array_o                       : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- External Interface (w/ FLow Control)
    -----------------------------
    ext_dout_array_o                          : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    ext_valid_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_addr_array_o                          : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    ext_sof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_eof_array_o                           : out std_logic_vector(g_acq_num_cores-1 downto 0);
    ext_dreq_array_o                          : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes
    ext_stall_array_o                         : out std_logic_vector(g_acq_num_cores-1 downto 0); -- for debbuging purposes

    -----------------------------
    -- Debug Interface
    -----------------------------
    dbg_ddr_rb_start_p_array_i                : in std_logic_vector(g_acq_num_cores-1 downto 0) := (others => '0');
    dbg_ddr_rb_rdy_array_o                    : out std_logic_vector(g_acq_num_cores-1 downto 0);
    dbg_ddr_rb_data_array_o                   : out std_logic_vector(g_acq_num_cores*g_ddr_payload_width-1 downto 0);
    dbg_ddr_rb_addr_array_o                   : out std_logic_vector(g_acq_num_cores*g_acq_addr_width-1 downto 0);
    dbg_ddr_rb_valid_array_o                  : out std_logic_vector(g_acq_num_cores-1 downto 0);

    -----------------------------
    -- DDR3 SDRAM Interface
    -----------------------------
    -- AXIMM Read Channel
    ddr_aximm_r_ma_i                          : in t_aximm_r_master_in := cc_dummy_aximm_r_master_in;
    ddr_aximm_r_ma_o                          : out t_aximm_r_master_out;
    -- AXIMM Write Channel
    ddr_aximm_w_ma_i                          : in t_aximm_w_master_in := cc_dummy_aximm_w_master_in;
    ddr_aximm_w_ma_o                          : out t_aximm_w_master_out
  );
  end component;

  component wb_pcie_cntr
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE;
    g_simulation                              : string  := "FALSE"
  );
  port (
    -- DDR3 memory pins
    ddr3_dq_b                                 : inout std_logic_vector(c_ddr_dq_width-1 downto 0);
    ddr3_dqs_p_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_dqs_n_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_addr_o                               : out   std_logic_vector(c_ddr_row_width-1 downto 0);
    ddr3_ba_o                                 : out   std_logic_vector(c_ddr_bank_width-1 downto 0);
    ddr3_cs_n_o                               : out   std_logic_vector(0 downto 0);
    ddr3_ras_n_o                              : out   std_logic;
    ddr3_cas_n_o                              : out   std_logic;
    ddr3_we_n_o                               : out   std_logic;
    ddr3_reset_n_o                            : out   std_logic;
    ddr3_ck_p_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_ck_n_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_cke_o                                : out   std_logic_vector(c_ddr_cke_width-1 downto 0);
    ddr3_dm_o                                 : out   std_logic_vector(c_ddr_dm_width-1 downto 0);
    ddr3_odt_o                                : out   std_logic_vector(c_ddr_odt_width-1 downto 0);

    -- PCIe transceivers
    pci_exp_rxp_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_rxn_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txp_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txn_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);

    -- Necessity signals
    ddr_clk_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    ddr_rst_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    pcie_clk_p_i                              : in std_logic; --100 MHz PCIe Clock (connect directly to input pin)
    pcie_clk_n_i                              : in std_logic; --100 MHz PCIe Clock
    pcie_rst_n_i                              : in std_logic; --Reset to PCIe core

    -- DDR memory controller interface --
    ddr_aximm_sl_aclk_o                       : out std_logic;
    ddr_aximm_sl_aresetn_o                    : out std_logic;
    ddr_aximm_w_sl_awid_i                     : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awaddr_i                   : in std_logic_vector (31 downto 0);
    ddr_aximm_w_sl_awlen_i                    : in std_logic_vector (7 downto 0);
    ddr_aximm_w_sl_awsize_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_w_sl_awburst_i                  : in std_logic_vector (1 downto 0);
    ddr_aximm_w_sl_awlock_i                   : in std_logic;
    ddr_aximm_w_sl_awcache_i                  : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awprot_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_w_sl_awqos_i                    : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awvalid_i                  : in std_logic;
    ddr_aximm_w_sl_awready_o                  : out std_logic;
    ddr_aximm_w_sl_wdata_i                    : in std_logic_vector (c_ddr_payload_width-1 downto 0);
    ddr_aximm_w_sl_wstrb_i                    : in std_logic_vector (c_ddr_payload_width/8-1 downto 0);
    ddr_aximm_w_sl_wlast_i                    : in std_logic;
    ddr_aximm_w_sl_wvalid_i                   : in std_logic;
    ddr_aximm_w_sl_wready_o                   : out std_logic;
    ddr_aximm_w_sl_bready_i                   : in std_logic;
    ddr_aximm_w_sl_bid_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_bresp_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_w_sl_bvalid_o                   : out std_logic;
    ddr_aximm_r_sl_arid_i                     : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_araddr_i                   : in std_logic_vector (31 downto 0);
    ddr_aximm_r_sl_arlen_i                    : in std_logic_vector (7 downto 0);
    ddr_aximm_r_sl_arsize_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_r_sl_arburst_i                  : in std_logic_vector (1 downto 0);
    ddr_aximm_r_sl_arlock_i                   : in std_logic;
    ddr_aximm_r_sl_arcache_i                  : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_arprot_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_r_sl_arqos_i                    : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_arvalid_i                  : in std_logic;
    ddr_aximm_r_sl_arready_o                  : out std_logic;
    ddr_aximm_r_sl_rready_i                   : in std_logic;
    ddr_aximm_r_sl_rid_o                      : out std_logic_vector (3 downto 0 );
    ddr_aximm_r_sl_rdata_o                    : out std_logic_vector (c_ddr_payload_width-1 downto 0);
    ddr_aximm_r_sl_rresp_o                    : out std_logic_vector (1 downto 0 );
    ddr_aximm_r_sl_rlast_o                    : out std_logic;
    ddr_aximm_r_sl_rvalid_o                   : out std_logic;

    -- Wishbone interface --
    wb_clk_i                                  : in std_logic;
    wb_rst_i                                  : in std_logic;
    wb_ma_adr_o                               : out std_logic_vector(c_wishbone_address_width-1 downto 0);
    wb_ma_dat_o                               : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_ma_sel_o                               : out std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_ma_cyc_o                               : out std_logic;
    wb_ma_stb_o                               : out std_logic;
    wb_ma_we_o                                : out std_logic;
    wb_ma_dat_i                               : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := cc_dummy_data;
    wb_ma_err_i                               : in  std_logic                                             := '0';
    wb_ma_rty_i                               : in  std_logic                                             := '0';
    wb_ma_ack_i                               : in  std_logic                                             := '0';
    wb_ma_stall_i                             : in  std_logic                                             := '0';
    -- Additional exported signals for instantiation
    wb_ma_pcie_rst_o                          : out std_logic;
    pcie_clk_o                                : out std_logic;
    ddr_rdy_o                                 : out std_logic
  );
  end component;

  component xwb_pcie_cntr
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE;
    g_simulation                              : string  := "FALSE"
  );
  port (
    -- DDR3 memory pins
    ddr3_dq_b                                 : inout std_logic_vector(c_ddr_dq_width-1 downto 0);
    ddr3_dqs_p_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_dqs_n_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_addr_o                               : out   std_logic_vector(c_ddr_row_width-1 downto 0);
    ddr3_ba_o                                 : out   std_logic_vector(c_ddr_bank_width-1 downto 0);
    ddr3_cs_n_o                               : out   std_logic_vector(0 downto 0);
    ddr3_ras_n_o                              : out   std_logic;
    ddr3_cas_n_o                              : out   std_logic;
    ddr3_we_n_o                               : out   std_logic;
    ddr3_reset_n_o                            : out   std_logic;
    ddr3_ck_p_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_ck_n_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_cke_o                                : out   std_logic_vector(c_ddr_cke_width-1 downto 0);
    ddr3_dm_o                                 : out   std_logic_vector(c_ddr_dm_width-1 downto 0);
    ddr3_odt_o                                : out   std_logic_vector(c_ddr_odt_width-1 downto 0);

    -- PCIe transceivers
    pci_exp_rxp_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_rxn_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txp_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txn_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);

    -- Necessity signals
    ddr_clk_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    ddr_rst_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    pcie_clk_p_i                              : in std_logic; --100 MHz PCIe Clock (connect directly to input pin)
    pcie_clk_n_i                              : in std_logic; --100 MHz PCIe Clock
    pcie_rst_n_i                              : in std_logic; --Reset to PCIe core

    -- DDR memory controller interface --
    ddr_aximm_sl_aclk_o                       : out std_logic;
    ddr_aximm_sl_aresetn_o                    : out std_logic;
    -- AXIMM Read Channel
    ddr_aximm_r_sl_i                          : in t_aximm_r_slave_in := cc_dummy_aximm_r_slave_in;
    ddr_aximm_r_sl_o                          : out t_aximm_r_slave_out;
    -- AXIMM Write Channel
    ddr_aximm_w_sl_i                          : in t_aximm_w_slave_in := cc_dummy_aximm_w_slave_in;
    ddr_aximm_w_sl_o                          : out t_aximm_w_slave_out;

    -- Wishbone interface --
    wb_clk_i                                  : in std_logic;
    wb_rst_i                                  : in std_logic;
    wb_ma_i                                   : in  t_wishbone_master_in := cc_dummy_slave_out;
    wb_ma_o                                   : out t_wishbone_master_out;

    -- Additional exported signals for instantiation
    wb_ma_pcie_rst_o                          : out std_logic;
    pcie_clk_o                                : out std_logic;
    ddr_rdy_o                                 : out std_logic
  );
  end component;

  component wb_bpm_pcie
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE;
    g_simulation                              : string  := "FALSE"
  );
  port (
    -- DDR3 memory pins
    ddr3_dq_b                                 : inout std_logic_vector(c_ddr_dq_width-1 downto 0);
    ddr3_dqs_p_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_dqs_n_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_addr_o                               : out   std_logic_vector(c_ddr_row_width-1 downto 0);
    ddr3_ba_o                                 : out   std_logic_vector(c_ddr_bank_width-1 downto 0);
    ddr3_cs_n_o                               : out   std_logic_vector(0 downto 0);
    ddr3_ras_n_o                              : out   std_logic;
    ddr3_cas_n_o                              : out   std_logic;
    ddr3_we_n_o                               : out   std_logic;
    ddr3_reset_n_o                            : out   std_logic;
    ddr3_ck_p_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_ck_n_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_cke_o                                : out   std_logic_vector(c_ddr_cke_width-1 downto 0);
    ddr3_dm_o                                 : out   std_logic_vector(c_ddr_dm_width-1 downto 0);
    ddr3_odt_o                                : out   std_logic_vector(c_ddr_odt_width-1 downto 0);

    -- PCIe transceivers
    pci_exp_rxp_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_rxn_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txp_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txn_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);

    -- Necessity signals
    ddr_clk_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    ddr_rst_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    pcie_clk_p_i                              : in std_logic; --100 MHz PCIe Clock (connect directly to input pin)
    pcie_clk_n_i                              : in std_logic; --100 MHz PCIe Clock
    pcie_rst_n_i                              : in std_logic; --Reset to PCIe core

    -- DDR memory controller interface --
    ddr_aximm_sl_aclk_o                       : out std_logic;
    ddr_aximm_sl_aresetn_o                    : out std_logic;
    ddr_aximm_w_sl_awid_i                     : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awaddr_i                   : in std_logic_vector (31 downto 0);
    ddr_aximm_w_sl_awlen_i                    : in std_logic_vector (7 downto 0);
    ddr_aximm_w_sl_awsize_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_w_sl_awburst_i                  : in std_logic_vector (1 downto 0);
    ddr_aximm_w_sl_awlock_i                   : in std_logic;
    ddr_aximm_w_sl_awcache_i                  : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awprot_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_w_sl_awqos_i                    : in std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_awvalid_i                  : in std_logic;
    ddr_aximm_w_sl_awready_o                  : out std_logic;
    ddr_aximm_w_sl_wdata_i                    : in std_logic_vector (c_ddr_payload_width-1 downto 0);
    ddr_aximm_w_sl_wstrb_i                    : in std_logic_vector (c_ddr_payload_width/8-1 downto 0);
    ddr_aximm_w_sl_wlast_i                    : in std_logic;
    ddr_aximm_w_sl_wvalid_i                   : in std_logic;
    ddr_aximm_w_sl_wready_o                   : out std_logic;
    ddr_aximm_w_sl_bready_i                   : in std_logic;
    ddr_aximm_w_sl_bid_o                      : out std_logic_vector (3 downto 0);
    ddr_aximm_w_sl_bresp_o                    : out std_logic_vector (1 downto 0);
    ddr_aximm_w_sl_bvalid_o                   : out std_logic;
    ddr_aximm_r_sl_arid_i                     : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_araddr_i                   : in std_logic_vector (31 downto 0);
    ddr_aximm_r_sl_arlen_i                    : in std_logic_vector (7 downto 0);
    ddr_aximm_r_sl_arsize_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_r_sl_arburst_i                  : in std_logic_vector (1 downto 0);
    ddr_aximm_r_sl_arlock_i                   : in std_logic;
    ddr_aximm_r_sl_arcache_i                  : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_arprot_i                   : in std_logic_vector (2 downto 0);
    ddr_aximm_r_sl_arqos_i                    : in std_logic_vector (3 downto 0);
    ddr_aximm_r_sl_arvalid_i                  : in std_logic;
    ddr_aximm_r_sl_arready_o                  : out std_logic;
    ddr_aximm_r_sl_rready_i                   : in std_logic;
    ddr_aximm_r_sl_rid_o                      : out std_logic_vector (3 downto 0 );
    ddr_aximm_r_sl_rdata_o                    : out std_logic_vector (c_ddr_payload_width-1 downto 0);
    ddr_aximm_r_sl_rresp_o                    : out std_logic_vector (1 downto 0 );
    ddr_aximm_r_sl_rlast_o                    : out std_logic;
    ddr_aximm_r_sl_rvalid_o                   : out std_logic;

    -- Wishbone interface --
    wb_clk_i                                  : in std_logic;
    wb_rst_i                                  : in std_logic;
    wb_ma_adr_o                               : out std_logic_vector(c_wishbone_address_width-1 downto 0);
    wb_ma_dat_o                               : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_ma_sel_o                               : out std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_ma_cyc_o                               : out std_logic;
    wb_ma_stb_o                               : out std_logic;
    wb_ma_we_o                                : out std_logic;
    wb_ma_dat_i                               : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := cc_dummy_data;
    wb_ma_err_i                               : in  std_logic                                             := '0';
    wb_ma_rty_i                               : in  std_logic                                             := '0';
    wb_ma_ack_i                               : in  std_logic                                             := '0';
    wb_ma_stall_i                             : in  std_logic                                             := '0';
    -- Additional exported signals for instantiation
    wb_ma_pcie_rst_o                          : out std_logic;
    pcie_clk_o                                : out std_logic;
    ddr_rdy_o                                 : out std_logic
  );
  end component;

  component xwb_bpm_pcie
  generic (
    g_ma_interface_mode                       : t_wishbone_interface_mode := PIPELINED;
    g_ma_address_granularity                  : t_wishbone_address_granularity := BYTE;
    g_simulation                              : string  := "FALSE"
  );
  port (
    -- DDR3 memory pins
    ddr3_dq_b                                 : inout std_logic_vector(c_ddr_dq_width-1 downto 0);
    ddr3_dqs_p_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_dqs_n_b                              : inout std_logic_vector(c_ddr_dqs_width-1 downto 0);
    ddr3_addr_o                               : out   std_logic_vector(c_ddr_row_width-1 downto 0);
    ddr3_ba_o                                 : out   std_logic_vector(c_ddr_bank_width-1 downto 0);
    ddr3_cs_n_o                               : out   std_logic_vector(0 downto 0);
    ddr3_ras_n_o                              : out   std_logic;
    ddr3_cas_n_o                              : out   std_logic;
    ddr3_we_n_o                               : out   std_logic;
    ddr3_reset_n_o                            : out   std_logic;
    ddr3_ck_p_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_ck_n_o                               : out   std_logic_vector(c_ddr_ck_width-1 downto 0);
    ddr3_cke_o                                : out   std_logic_vector(c_ddr_cke_width-1 downto 0);
    ddr3_dm_o                                 : out   std_logic_vector(c_ddr_dm_width-1 downto 0);
    ddr3_odt_o                                : out   std_logic_vector(c_ddr_odt_width-1 downto 0);

    -- PCIe transceivers
    pci_exp_rxp_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_rxn_i                             : in  std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txp_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);
    pci_exp_txn_o                             : out std_logic_vector(c_pcielanes - 1 downto 0);

    -- Necessity signals
    ddr_clk_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    ddr_rst_i                                 : in std_logic; --200 MHz DDR core clock (connect through BUFG or PLL)
    pcie_clk_p_i                              : in std_logic; --100 MHz PCIe Clock (connect directly to input pin)
    pcie_clk_n_i                              : in std_logic; --100 MHz PCIe Clock
    pcie_rst_n_i                              : in std_logic; --Reset to PCIe core

    -- DDR memory controller interface --
    ddr_aximm_sl_aclk_o                       : out std_logic;
    ddr_aximm_sl_aresetn_o                    : out std_logic;
    -- AXIMM Read Channel
    ddr_aximm_r_sl_i                          : in t_aximm_r_slave_in := cc_dummy_aximm_r_slave_in;
    ddr_aximm_r_sl_o                          : out t_aximm_r_slave_out;
    -- AXIMM Write Channel
    ddr_aximm_w_sl_i                          : in t_aximm_w_slave_in := cc_dummy_aximm_w_slave_in;
    ddr_aximm_w_sl_o                          : out t_aximm_w_slave_out;

    -- Wishbone interface --
    wb_clk_i                                  : in std_logic;
    wb_rst_i                                  : in std_logic;
    wb_ma_i                                   : in  t_wishbone_master_in := cc_dummy_slave_out;
    wb_ma_o                                   : out t_wishbone_master_out;

    -- Additional exported signals for instantiation
    wb_ma_pcie_rst_o                          : out std_logic;
    pcie_clk_o                                : out std_logic;
    ddr_rdy_o                                 : out std_logic
  );
  end component;

  component wb_fmc_active_clk
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false
  );
  port
  (
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

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

    -----------------------------
    -- General ADC output signals and status
    -----------------------------

    -- General board status
    fmc_pll_status_o                          : out std_logic;

    -- fmc_fpga_clk_*_i bypass signals
    fmc_fpga_clk_p_o                          : out std_logic;
    fmc_fpga_clk_n_o                          : out std_logic
  );
  end component;

  component xwb_fmc_active_clk
  generic
  (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false
  );
  port
  (
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------

    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

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

    -----------------------------
    -- General ADC output signals and status
    -----------------------------

    -- General board status
    fmc_pll_status_o                          : out std_logic;

    -- fmc_fpga_clk_*_i bypass signals
    fmc_fpga_clk_p_o                          : out std_logic;
    fmc_fpga_clk_n_o                          : out std_logic
  );
  end component;

  component wb_trigger_mux
  generic (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_sync_edge                               : string                         := "positive";
    g_trig_num                                : natural range 1 to 24          := 8;
    g_intern_num                              : natural range 1 to 24          := 8;
    g_rcv_intern_num                          : natural range 1 to 24          := 2);
  port (
    clk_i                                     : in    std_logic;
    rst_n_i                                   : in    std_logic;
    fs_clk_i                                  : in    std_logic;
    fs_rst_n_i                                : in    std_logic;
    wb_adr_i                                  : in    std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_dat_i                                  : in    std_logic_vector(c_wishbone_data_width-1 downto 0)    := (others => '0');
    wb_dat_o                                  : out   std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_sel_i                                  : in    std_logic_vector(c_wishbone_data_width/8-1 downto 0)  := (others => '0');
    wb_we_i                                   : in    std_logic                                             := '0';
    wb_cyc_i                                  : in    std_logic                                             := '0';
    wb_stb_i                                  : in    std_logic                                             := '0';
    wb_ack_o                                  : out   std_logic;
    wb_err_o                                  : out   std_logic;
    wb_rty_o                                  : out   std_logic;
    wb_stall_o                                : out   std_logic;

    trig_out_o                                : out   t_trig_channel_array(g_trig_num-1 downto 0);
    trig_in_i                                 : in    t_trig_channel_array(g_trig_num-1 downto 0);
    trig_rcv_intern_i                         : in    t_trig_channel_array(g_rcv_intern_num-1 downto 0);
    trig_pulse_transm_i                       : in    t_trig_channel_array(g_intern_num-1 downto 0);
    trig_pulse_rcv_o                          : out   t_trig_channel_array(g_intern_num-1 downto 0)
  );
  end component;

  component xwb_trigger_mux
  generic (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_sync_edge                               : string                         := "positive";
    g_trig_num                                : natural range 1 to 24          := 8;
    g_intern_num                              : natural range 1 to 24          := 8;
    g_rcv_intern_num                          : natural range 1 to 24          := 2);
  port (
    rst_n_i                                   : in    std_logic;
    clk_i                                     : in    std_logic;
    fs_clk_i                                  : in    std_logic;
    fs_rst_n_i                                : in    std_logic;
    wb_slv_i                                  : in    t_wishbone_slave_in;
    wb_slv_o                                  : out   t_wishbone_slave_out;

    trig_out_o                                : out t_trig_channel_array(g_trig_num-1 downto 0);
    trig_in_i                                 : in  t_trig_channel_array(g_trig_num-1 downto 0);
    trig_rcv_intern_i                         : in  t_trig_channel_array(g_rcv_intern_num-1 downto 0);
    trig_pulse_transm_i                       : in  t_trig_channel_array(g_intern_num-1 downto 0);
    trig_pulse_rcv_o                          : out t_trig_channel_array(g_intern_num-1 downto 0));
  end component;

  component wb_trigger_iface
  generic (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_sync_edge                               : string                         := "positive";
    g_trig_num                                : natural range 1 to 24          := 8; -- channels facing outside the FPGA. Limit defined by wb_slave_trigger.vhd
    g_trigger_tristate                        : boolean                        := true
  );
  port (
    clk_i                                     : in std_logic;
    rst_n_i                                   : in std_logic;

    ref_clk_i                                 : in std_logic;
    ref_rst_n_i                               : in std_logic;

    -------------------------------
    ---- Wishbone Control Interface signals
    -------------------------------

    wb_adr_i                                  : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_dat_i                                  : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := (others => '0');
    wb_dat_o                                  : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_sel_i                                  : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0)  := (others => '0');
    wb_we_i                                   : in  std_logic                                             := '0';
    wb_cyc_i                                  : in  std_logic                                             := '0';
    wb_stb_i                                  : in  std_logic                                             := '0';
    wb_ack_o                                  : out std_logic;
    wb_err_o                                  : out std_logic;
    wb_rty_o                                  : out std_logic;
    wb_stall_o                                : out std_logic;

    -------------------------------
    ---- External ports
    -------------------------------

    -- only used if g_trigger_tristate = true
    trig_b                                    : inout std_logic_vector(g_trig_num-1 downto 0);
    -- only used if g_trigger_tristate = false
    trig_i                                    : in    std_logic_vector(g_trig_num-1 downto 0) := (others => '0');
    trig_o                                    : out   std_logic_vector(g_trig_num-1 downto 0);
    trig_dir_o                                : out   std_logic_vector(g_trig_num-1 downto 0);

    -------------------------------
    ---- Internal ports
    -------------------------------

    trig_out_o                                : out t_trig_channel_array(g_trig_num-1 downto 0);
    trig_in_i                                 : in  t_trig_channel_array(g_trig_num-1 downto 0);

    -------------------------------
    ---- Debug ports
    -------------------------------
    trig_dbg_o                                : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_sync_o                           : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_degliteched_o                    : out std_logic_vector(g_trig_num-1 downto 0)
  );
  end component;

  component xwb_trigger_iface
  generic
    (
      g_interface_mode                        : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity                   : t_wishbone_address_granularity := WORD;
      g_sync_edge                             : string                         := "positive";
      g_trig_num                              : natural range 1 to 24          := 8;
      g_trigger_tristate                      : boolean                        := true
  );
  port
  (
    rst_n_i                                   : in std_logic;
    clk_i                                     : in std_logic;

    ref_clk_i                                 : in std_logic;
    ref_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone signals
    -----------------------------

    wb_slv_i                                  : in  t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

    -- only used if g_trigger_tristate = true
    trig_b                                    : inout std_logic_vector(g_trig_num-1 downto 0);
    -- only used if g_trigger_tristate = false
    trig_i                                    : in    std_logic_vector(g_trig_num-1 downto 0) := (others => '0');
    trig_o                                    : out   std_logic_vector(g_trig_num-1 downto 0);
    trig_dir_o                                : out   std_logic_vector(g_trig_num-1 downto 0);

    -----------------------------
    -- Internal ports
    -----------------------------

    trig_out_o                                : out t_trig_channel_array(g_trig_num-1 downto 0);
    trig_in_i                                 : in  t_trig_channel_array(g_trig_num-1 downto 0);

    -------------------------------
    ---- Debug ports
    -------------------------------
    trig_dbg_o                                : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_sync_o                           : out std_logic_vector(g_trig_num-1 downto 0);
    dbg_data_degliteched_o                    : out std_logic_vector(g_trig_num-1 downto 0)
  );
  end component;

  component wb_trigger
  generic (
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    -- Set to true if the trigger interface is done externally. Triggers
    -- will be passed directly to the clock domain synchronizers.
    g_with_external_iface                     : boolean                        := false;
    g_sync_edge                               : string                         := "positive";
    g_trig_num                                : natural range 1 to 24          := 8; -- channels facing outside the FPGA. Limit defined by wb_trigger_regs.vhd
    g_trigger_tristate                        : boolean                        := true; -- enable trigger tristate buffer or not
    g_intern_num                              : natural range 1 to 24          := 8; -- channels facing inside the FPGA. Limit defined by wb_trigger_regs.vhd
    g_rcv_intern_num                          : natural range 1 to 24          := 2; -- signals from inside the FPGA that can be used as input at a rcv mux.
                                                                                     -- Limit defined by wb_trigger_regs.vhd
    g_num_mux_interfaces                      : natural                        := 2;  -- Number of wb_trigger_mux modules
    g_out_resolver                            : string                         := "fanout"; -- Resolver policy for output triggers
    g_in_resolver                             : string                         := "or";     -- Resolver policy for input triggers
    g_with_input_sync                         : boolean                        := true;
    g_with_output_sync                        : boolean                        := true
  );
  port (
    clk_i                                     : in std_logic;
    rst_n_i                                   : in std_logic;

    ref_clk_i                                 : in std_logic;
    ref_rst_n_i                               : in std_logic;

    fs_clk_array_i                            : in std_logic_vector(g_num_mux_interfaces-1 downto 0);
    fs_rst_n_array_i                          : in std_logic_vector(g_num_mux_interfaces-1 downto 0);

    -------------------------------
    ---- Wishbone Control Interface signals
    -------------------------------

    wb_trigger_iface_adr_i                    : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_trigger_iface_dat_i                    : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := (others => '0');
    wb_trigger_iface_dat_o                    : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_trigger_iface_sel_i                    : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0)  := (others => '0');
    wb_trigger_iface_we_i                     : in  std_logic                                             := '0';
    wb_trigger_iface_cyc_i                    : in  std_logic                                             := '0';
    wb_trigger_iface_stb_i                    : in  std_logic                                             := '0';
    wb_trigger_iface_ack_o                    : out std_logic;
    wb_trigger_iface_err_o                    : out std_logic;
    wb_trigger_iface_rty_o                    : out std_logic;
    wb_trigger_iface_stall_o                  : out std_logic;

    wb_trigger_mux_adr_i                      : in  std_logic_vector(g_num_mux_interfaces*c_wishbone_address_width-1 downto 0) := (others => '0');
    wb_trigger_mux_dat_i                      : in  std_logic_vector(g_num_mux_interfaces*c_wishbone_data_width-1 downto 0)    := (others => '0');
    wb_trigger_mux_dat_o                      : out std_logic_vector(g_num_mux_interfaces*c_wishbone_data_width-1 downto 0);
    wb_trigger_mux_sel_i                      : in  std_logic_vector(g_num_mux_interfaces*c_wishbone_data_width/8-1 downto 0)  := (others => '0');
    wb_trigger_mux_we_i                       : in  std_logic_vector(g_num_mux_interfaces-1 downto 0)                          := (others => '0');
    wb_trigger_mux_cyc_i                      : in  std_logic_vector(g_num_mux_interfaces-1 downto 0)                          := (others => '0');
    wb_trigger_mux_stb_i                      : in  std_logic_vector(g_num_mux_interfaces-1 downto 0)                          := (others => '0');
    wb_trigger_mux_ack_o                      : out std_logic_vector(g_num_mux_interfaces-1 downto 0);
    wb_trigger_mux_err_o                      : out std_logic_vector(g_num_mux_interfaces-1 downto 0);
    wb_trigger_mux_rty_o                      : out std_logic_vector(g_num_mux_interfaces-1 downto 0);
    wb_trigger_mux_stall_o                    : out std_logic_vector(g_num_mux_interfaces-1 downto 0);

    -------------------------------
    ---- External ports
    -------------------------------

    -- only used if g_trigger_tristate = true
    trig_b                                    : inout std_logic_vector(g_trig_num-1 downto 0);
    -- only used if g_trigger_tristate = false
    trig_i                                    : in    std_logic_vector(g_trig_num-1 downto 0) := (others => '0');
    trig_o                                    : out   std_logic_vector(g_trig_num-1 downto 0);
    trig_dir_o                                : out   std_logic_vector(g_trig_num-1 downto 0);

    -------------------------------
    ---- Trigger Interface ports if g_with_external_iface is true
    -------------------------------

    trig_in_i                                 : in  t_trig_channel_array(g_trig_num-1 downto 0) := (others => c_trig_channel_dummy);
    trig_out_o                                : out t_trig_channel_array(g_trig_num-1 downto 0);

    -------------------------------
    ---- Internal ports
    -------------------------------

    trig_rcv_intern_i                         : in  t_trig_channel_array(g_num_mux_interfaces*g_rcv_intern_num-1 downto 0);  -- signals from inside the FPGA that can be used as input at a rcv mux

    trig_pulse_transm_i                       : in  t_trig_channel_array(g_num_mux_interfaces*g_intern_num-1 downto 0);
    trig_pulse_rcv_o                          : out t_trig_channel_array(g_num_mux_interfaces*g_intern_num-1 downto 0);

      -------------------------------
      ---- Debug ports
      -------------------------------
      trig_dbg_o                              : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_sync_o                         : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_degliteched_o                  : out std_logic_vector(g_trig_num-1 downto 0);
      trig_out_resolved_o                     : out t_trig_channel_array(g_trig_num-1 downto 0);
      trig_out_int_array2d_o                  : out t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_trig_num-1 downto 0)
  );
  end component;

  component xwb_trigger
  generic
    (
      g_interface_mode                        : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity                   : t_wishbone_address_granularity := WORD;
      -- Set to true if the trigger interface is done externally. Triggers
      -- will be passed directly to the clock domain synchronizers.
      g_with_external_iface                   : boolean                        := false;
      g_sync_edge                             : string                         := "positive";
      g_trig_num                              : natural range 1 to 24          := 8; -- channels facing outside the FPGA. Limit defined by wb_trigger_regs.vhd
      g_trigger_tristate                      : boolean                        := true; -- enable trigger tristate buffer or not
      g_intern_num                            : natural range 1 to 24          := 8; -- channels facing inside the FPGA. Limit defined by wb_trigger_regs.vhd
      g_rcv_intern_num                        : natural range 1 to 24          := 2; -- signals from inside the FPGA that can be used as input at a rcv mux.
                                                                                     -- Limit defined by wb_trigger_regs.vhd
      g_num_mux_interfaces                    : natural                        := 2;  -- Number of wb_trigger_mux modules
      g_out_resolver                          : string                         := "fanout"; -- Resolver policy for output triggers
      g_in_resolver                           : string                         := "or";     -- Resolver policy for input triggers
      g_with_input_sync                       : boolean                        := true;
      g_with_output_sync                      : boolean                        := true
    );
  port
    (
      clk_i                                   : in std_logic;
      rst_n_i                                 : in std_logic;

      ref_clk_i                               : in std_logic;
      ref_rst_n_i                             : in std_logic;

      fs_clk_array_i                          : in std_logic_vector(g_num_mux_interfaces-1 downto 0);
      fs_rst_n_array_i                        : in std_logic_vector(g_num_mux_interfaces-1 downto 0);

      -----------------------------
      -- Wishbone signals
      -----------------------------

      wb_slv_trigger_iface_i                  : in  t_wishbone_slave_in := c_dummy_wb_slave_in;
      wb_slv_trigger_iface_o                  : out t_wishbone_slave_out;

      wb_slv_trigger_mux_i                    : in  t_wishbone_slave_in_array(g_num_mux_interfaces-1 downto 0);
      wb_slv_trigger_mux_o                    : out t_wishbone_slave_out_array(g_num_mux_interfaces-1 downto 0);

      -----------------------------
      -- External ports
      -----------------------------

      -- only used if g_trigger_tristate = true
      trig_b                                  : inout std_logic_vector(g_trig_num-1 downto 0);
      -- only used if g_trigger_tristate = false
      trig_i                                  : in    std_logic_vector(g_trig_num-1 downto 0) := (others => '0');
      trig_o                                  : out   std_logic_vector(g_trig_num-1 downto 0);
      trig_dir_o                              : out   std_logic_vector(g_trig_num-1 downto 0);

      -------------------------------
      ---- Trigger Interface ports if g_with_external_iface is true
      -------------------------------

      trig_in_i                               : in  t_trig_channel_array(g_trig_num-1 downto 0) := (others => c_trig_channel_dummy);
      trig_out_o                              : out t_trig_channel_array(g_trig_num-1 downto 0);

      -----------------------------
      -- Internal ports
      -----------------------------

      trig_rcv_intern_i                       : in  t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_rcv_intern_num-1 downto 0);  -- signals from inside the FPGA that can be used as input at a rcv mux

      trig_pulse_transm_i                     : in  t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_intern_num-1 downto 0);
      trig_pulse_rcv_o                        : out t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_intern_num-1 downto 0);

      -------------------------------
      ---- Debug ports
      -------------------------------
      trig_dbg_o                              : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_sync_o                         : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_degliteched_o                  : out std_logic_vector(g_trig_num-1 downto 0);
      trig_out_resolved_o                     : out t_trig_channel_array(g_trig_num-1 downto 0);
      trig_out_int_array2d_o                  : out t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_trig_num-1 downto 0)
    );
  end component;

  component wb_afc_mgmt
  generic(
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false
  );
  port(
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

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

    -- Si57x clock gen
    si57x_scl_pad_b                           : inout std_logic;
    si57x_sda_pad_b                           : inout std_logic;
    si57x_oe_o                                : out std_logic
  );
  end component;

  component xwb_afc_mgmt
  generic(
    g_interface_mode                          : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity                     : t_wishbone_address_granularity := WORD;
    g_with_extra_wb_reg                       : boolean := false
  );
  port(
    sys_clk_i                                 : in std_logic;
    sys_rst_n_i                               : in std_logic;

    -----------------------------
    -- Wishbone Control Interface signals
    -----------------------------
    wb_slv_i                                  : in t_wishbone_slave_in;
    wb_slv_o                                  : out t_wishbone_slave_out;

    -----------------------------
    -- External ports
    -----------------------------

    -- Si57x clock gen
    si57x_scl_pad_b                           : inout std_logic;
    si57x_sda_pad_b                           : inout std_logic;
    si57x_oe_o                                : out std_logic
  );
  end component;

  component xwb_evt_cnt is
  generic (
    g_INTERFACE_MODE      : t_wishbone_interface_mode      := CLASSIC;
    g_ADDRESS_GRANULARITY : t_wishbone_address_granularity := WORD;
    g_WITH_EXTRA_WB_REG   : boolean := false
    );
  port (
    -- System clock (for wishbone).
    clk_i                 : in  std_logic;
    -- Reset (clk_i domain)
    rst_clk_n_i           : in  std_logic;
    -- Wishbone interface.
    wb_slv_i              : in  t_wishbone_slave_in;
    wb_slv_o              : out t_wishbone_slave_out;
    -- Clock signal to be used for the counter.
    clk_evt_i             : in  std_logic;
    -- Reset (clk_evt_i domain)
    rst_clk_evt_n_i       : in  std_logic;
    -- Event signal. Will be read every clk_evt_i rising edge,
    -- incrementing the internal counter if is '1'.
    evt_i                 : in  std_logic;
    -- External trigger input. Function depends of the
    -- configuration in ctl.trig_act bit (clk_evt_i domain).
    ext_trig_i            : in  std_logic
    );
  end component;

  --------------------------------------------------------------------
  -- SDB Devices Structures
  --------------------------------------------------------------------

  -- Simple GPIO interface device
  constant c_xwb_gpio32_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",     -- Max of 256 pins. Max of 8 32-bit registers
    product => (
    vendor_id     => x"0000000000000651",     -- GSI
    device_id     => x"35aa6b95",
    version       => x"00000001",
    date          => x"20120305",
    name          => "GSI_GPIO_32        ")));

  -- IRQ manager interface device
  constant c_xwb_irqmngr_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"15ff65e1",
    version       => x"00000001",
    date          => x"20120903",
    name          => "LNLS_IRQMNGR       ")));

  -- FMC150 Interface
  constant c_xwb_fmc150_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"f8c150c1",
    version       => x"00000001",
    date          => x"20121010",
    name          => "LNLS_FMC150        ")));

  -- FMC516 Interface
  --constant c_xwb_fmc516_sdb : t_sdb_device := (
  --  abi_class     => x"0000",                 -- undocumented device
  --  abi_ver_major => x"01",
  --  abi_ver_minor => x"00",
  --  wbd_endian    => c_sdb_endian_big,
  --  wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
  --  sdb_component => (
  --  addr_first    => x"0000000000000000",
  --  addr_last     => x"0000000000000FFF",   -- Too much addresses? Probably...
  --  product => (
  --  vendor_id     => x"1000000000001215",     -- LNLS
  --  device_id     => x"64f2a9ba",
  --  version       => x"00000001",
  --  date          => x"20121124",
  --  name          => "LNLS_FMC516        ")));

  -- UART Interface
  constant c_xwb_uart_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"1",                     -- 8-bit port granularity (0001)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"000000000000CE42",     -- CERN
    device_id     => x"8a5719ae",
    version       => x"00000001",
    date          => x"20121011",
    name          => "CERN_SIMPLE_UART   ")));

  -- Simple TICs counter Interface
  constant c_xwb_tics_counter_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                     -- 8/16/32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"000000000000000F",
    product => (
    vendor_id     => x"000000000000CE42",     -- CERN
    device_id     => x"FDAFB9DD",
    version       => x"00000001",
    date          => x"20130225",
    name          => "CERN_TICS_COUNTER  ")));

  -- FMC ADC Common
  constant c_xwb_fmc_adc_common_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                   -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                      -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",       -- LNLS
    device_id     => x"2403f569",
    version       => x"00000001",
    date          => x"20160418",
    name          => "LNLS_ACOMMON_REGS  ")));

  -- FMC Active Clock
  constant c_xwb_fmc_active_clk_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                   -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                      -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",       -- LNLS
    device_id     => x"88c67d9c",
    version       => x"00000001",
    date          => x"20160418",
    name          => "LNLS_ACLK_REGS     ")));

  -- Trigger interface device
  constant c_xwb_trigger_mux_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000003FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"84b6a5ac",
    version       => x"00000001",
    date          => x"20160512",
    name          => "LNLS_TRIGGER_MUX   ")));

  -- Trigger Interface
  constant c_xwb_trigger_iface_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7",                     -- 8/16/32-bit port granularity (0111)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000003FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"bcbb78d2",
    version       => x"00000001",
    date          => x"20160203",
    name          => "LNLS_TRIGGER_IFACE ")));

  -- fmcpico_1m_4CH
  constant c_xwb_fmcpico_1m_4ch_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                 -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                     -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",     -- LNLS
    device_id     => x"669f7e38",
    version       => x"00000001",
    date          => x"20171603",
    name          => "LNLS_FMCPICO_REGS  ")));

  -- AFC MGMT
  constant c_xwb_afc_mgmt_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                   -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                      -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",       -- LNLS
    device_id     => x"e7146ebe",
    version       => x"00000001",
    date          => x"20170825",
    name          => "LNLS_AFC_MGMT_REGS ")));

  -- Event Counter
  constant c_xwb_evt_cnt_regs_sdb : t_sdb_device := (
    abi_class     => x"0000",                   -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"4",                      -- 32-bit port granularity (0100)
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"00000000000000FF",
    product => (
    vendor_id     => x"1000000000001215",       -- LNLS
    device_id     => x"df6ba91f",
    version       => x"00000001",
    date          => x"20220718",
    name          => "LNLS_EVT_CNT_REGS  ")));


end ifc_wishbone_pkg;
