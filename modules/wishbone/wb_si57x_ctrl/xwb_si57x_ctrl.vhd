-------------------------------------------------------------------------------
-- Title      : Si57x controller with a wishbone interface
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: A Wishbone wrapper for the si57x_ctrl core
-------------------------------------------------------------------------------
-- Copyright (c) 2024 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2024-05-29  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity xwb_si57x_ctrl is
  generic (
    -- Si57x I2C slave address
    g_SI57X_I2C_ADDR: std_logic_vector(6 downto 0);

    -- Divide the input clock to 4x SCL
    g_SCL_CLK_DIV: natural range 1 to 65536;

    -- Set this true if you are using the Si57x 7PPM variant
    g_SI57X_7PPM_VARIANT: boolean;

    -- Wishbone options
    g_INTERFACE_MODE      : t_wishbone_interface_mode      := CLASSIC;
    g_ADDRESS_GRANULARITY : t_wishbone_address_granularity := WORD
  );
  port (
    -- Input clock
    clk_i: in std_logic;

    -- Synchronous reset, active low
    rst_n_i: in std_logic;

    -- Wishbone interface
    wb_slv_i: in  t_wishbone_slave_in;
    wb_slv_o: out t_wishbone_slave_out;

    -- I2C SDA Master input
    sda_i: in std_logic;

    -- I2C SDA Master output
    sda_o: out std_logic;

    -- I2C SDA Master output enable, active high
    sda_oe_o: out std_logic;

    -- I2C SCL Master input
    scl_i: in std_logic;

    -- I2C SCL Master output
    scl_o: out std_logic;

    -- I2C SCL Master output enable, active high
    scl_oe_o: out std_logic
  );
end entity;

architecture rtl of xwb_si57x_ctrl is
  signal ctl_read_strp_regs  : std_logic;
  signal ctl_apply_cfg       : std_logic;
  signal sta_strp_complete   : std_logic;
  signal sta_cfg_in_sync     : std_logic;
  signal sta_i2c_err         : std_logic;
  signal sta_busy            : std_logic;
  signal n1_strp             : std_logic_vector(6 downto 0);
  signal hsdiv_strp          : std_logic_vector(2 downto 0);
  signal rfreq_strp          : std_logic_vector(37 downto 0);
  signal n1                  : std_logic_vector(6 downto 0);
  signal hsdiv               : std_logic_vector(2 downto 0);
  signal rfreq               : std_logic_vector(37 downto 0);
  signal wb_slv_adp_i        : t_wishbone_slave_in;
  signal wb_slv_adp_o        : t_wishbone_slave_out;
begin
  -- Remember, the 'master' side connects to the cheby-generated wishbone slave
  -- and the 'slave' side connets to an upper level master core
  cmp_wb_slave_adapter: entity work.wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => BYTE,
      g_slave_use_struct   => true,
      g_slave_mode         => g_INTERFACE_MODE,
      g_slave_granularity  => g_ADDRESS_GRANULARITY
    )
    port map (
      clk_sys_i  => clk_i,
      rst_n_i    => rst_n_i,

      slave_i    => wb_slv_i,
      slave_o    => wb_slv_o,

      master_i   => wb_slv_adp_o,
      master_o   => wb_slv_adp_i
    );

  -- Yes, this 'hsdiv_n1_rfreq_msb_strp_' prefix is a bit confusing, but this
  -- is the way cheby generates the registers namespaces for each bit field
  cmp_wb_si57x_ctrl_regs: entity work.wb_si57x_ctrl_regs
    port map (
      rst_n_i                                  => rst_n_i,
      clk_i                                    => clk_i,
      wb_i                                     => wb_slv_adp_i,
      wb_o                                     => wb_slv_adp_o,
      ctl_read_strp_regs_o                     => ctl_read_strp_regs,
      ctl_apply_cfg_o                          => ctl_apply_cfg,
      sta_strp_complete_i                      => sta_strp_complete,
      sta_cfg_in_sync_i                        => sta_cfg_in_sync,
      sta_i2c_err_i                            => sta_i2c_err,
      sta_busy_i                               => sta_busy,
      hsdiv_n1_rfreq_msb_strp_rfreq_msb_strp_i => rfreq_strp(37 downto 32),
      hsdiv_n1_rfreq_msb_strp_n1_strp_i        => n1_strp,
      hsdiv_n1_rfreq_msb_strp_hsdiv_strp_i     => hsdiv_strp,
      rfreq_lsb_strp_i                         => rfreq_strp(31 downto 0),
      hsdiv_n1_rfreq_msb_rfreq_msb_o           => rfreq(37 downto 32),
      hsdiv_n1_rfreq_msb_n1_o                  => n1,
      hsdiv_n1_rfreq_msb_hsdiv_o               => hsdiv,
      rfreq_lsb_o                              => rfreq(31 downto 0)
    );

  cmp_si57x_ctrl: entity work.si57x_ctrl
    generic map (
      g_SI57X_I2C_ADDR     => g_SI57X_I2C_ADDR,
      g_SCL_CLK_DIV        => g_SCL_CLK_DIV,
      g_SI57X_7PPM_VARIANT => g_SI57X_7PPM_VARIANT
    )
    port map (
      clk_i               => clk_i,
      rst_n_i             => rst_n_i,
      hs_div_i            => hsdiv,
      n1_i                => n1,
      rfreq_i             => rfreq,
      apply_cfg_i         => ctl_apply_cfg,
      cfg_in_sync_o       => sta_cfg_in_sync,
      read_startup_regs_i => ctl_read_strp_regs,
      hs_div_startup_o    => hsdiv_strp,
      n1_startup_o        => n1_strp,
      rfreq_startup_o     => rfreq_strp,
      startup_complete_o  => sta_strp_complete,
      sda_i               => sda_i,
      sda_o               => sda_o,
      sda_oe_o            => sda_oe_o,
      scl_i               => scl_i,
      scl_o               => scl_o,
      scl_oe_o            => scl_oe_o,
      i2c_err_o           => sta_i2c_err,
      busy_o              => sta_busy
    );

end architecture;
