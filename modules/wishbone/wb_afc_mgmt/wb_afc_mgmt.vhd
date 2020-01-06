------------------------------------------------------------------------------
-- Title      : AFC board management module
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2017-08-25
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: AFC module containing AFC specifities, like clocks, I2C muxes, etc
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2017-08-25  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_common_pkg.all;
use work.ifc_wishbone_pkg.all;
use work.wishbone_pkg.all;
-- AFC MGMT registers
use work.afc_mgmt_wbgen2_pkg.all;

entity wb_afc_mgmt is
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
end wb_afc_mgmt;

architecture rtl of wb_afc_mgmt is

  -- Number of bits in Wishbone register interface. Plus 2 to account for BYTE addressing
  constant c_periph_addr_size               : natural := 1+2;

  -----------------------------
  -- Crossbar component constants
  -----------------------------
  -- Internal crossbar layout
  -- 0 -> AFC MGMT Register Wishbone Interface
  -- 1 -> Si57x I2C Bus.
  -- Number of slaves
  constant c_slaves                         : natural := 2;
  -- Number of masters
  constant c_masters                        : natural := 1;            -- Top master.

  -- Slaves indexes
  constant c_slv_afc_mgmt_regs_id           : natural := 0;
  constant c_slv_si57x_i2c_id               : natural := 1;

  -- AFC MGMT layout
  constant c_layout : t_sdb_record_array(c_slaves-1 downto 0) :=
  ( c_slv_afc_mgmt_regs_id                  => f_sdb_embed_device(c_xwb_afc_mgmt_regs_sdb,
                                                                x"00000000"),   -- AFC MGMT Interface regs
    c_slv_si57x_i2c_id                      => f_sdb_embed_device(c_xwb_i2c_master_sdb,
                                                                x"00000100")    -- VCXO Si57x I2C
  );

  -- Self Describing Bus ROM Address. It will be an addressed slave as well.
  constant c_sdb_address                    : t_wishbone_address := x"00000400";

  -----------------------------
  -- Clock/Reset signals
  -----------------------------
  signal sys_rst_n                          : std_logic;

  -----------------------------
  -- Wishbone Register Interface signals
  -----------------------------
  -- AFC MGMT reg structure
  signal regs_out                           : t_afc_mgmt_out_registers;
  signal regs_in                            : t_afc_mgmt_in_registers;

  -----------------------------
  -- Wishbone slave adapter signals/structures
  -----------------------------
  signal wb_slv_adp_out                     : t_wishbone_master_out;
  signal wb_slv_adp_in                      : t_wishbone_master_in;
  signal resized_addr                       : std_logic_vector(c_wishbone_address_width-1 downto 0);

  -- Extra Wishbone registering stage
  signal cbar_slave_in_reg0                 : t_wishbone_slave_in_array (c_masters-1 downto 0);
  signal cbar_slave_out_reg0                : t_wishbone_slave_out_array(c_masters-1 downto 0);

  -----------------------------
  -- Wishbone crossbar signals
  -----------------------------
  -- Crossbar master/slave arrays
  signal cbar_slave_in                      : t_wishbone_slave_in_array (c_masters-1 downto 0);
  signal cbar_slave_out                     : t_wishbone_slave_out_array(c_masters-1 downto 0);
  signal cbar_master_in                     : t_wishbone_master_in_array(c_slaves-1 downto 0);
  signal cbar_master_out                    : t_wishbone_master_out_array(c_slaves-1 downto 0);

  -----------------------------
  -- VCXO Si57x I2C Signals
  -----------------------------
  signal si57x_i2c_scl_in                   : std_logic_vector(0 downto 0);
  signal si57x_i2c_scl_out                  : std_logic_vector(0 downto 0);
  signal si57x_i2c_scl_oe_n                 : std_logic_vector(0 downto 0);
  signal si57x_i2c_sda_in                   : std_logic_vector(0 downto 0);
  signal si57x_i2c_sda_out                  : std_logic_vector(0 downto 0);
  signal si57x_i2c_sda_oe_n                 : std_logic_vector(0 downto 0);


  -- Components
  component afc_mgmt_regs
  port (
    rst_n_i                                 : in  std_logic;
    clk_sys_i                               : in  std_logic;
    wb_adr_i                                : in  std_logic_vector(0 downto 0);
    wb_dat_i                                : in  std_logic_vector(31 downto 0);
    wb_dat_o                                : out std_logic_vector(31 downto 0);
    wb_cyc_i                                : in  std_logic;
    wb_sel_i                                : in  std_logic_vector(3 downto 0);
    wb_stb_i                                : in  std_logic;
    wb_we_i                                 : in  std_logic;
    wb_ack_o                                : out std_logic;
    wb_stall_o                              : out std_logic;
    regs_i                                  : in  t_afc_mgmt_in_registers;
    regs_o                                  : out t_afc_mgmt_out_registers
  );
  end component;

begin

  sys_rst_n                                 <= sys_rst_n_i;

  -----------------------------
  -- Insert extra Wishbone registering stage for ease timing.
  -- It effectively cuts the bandwidth in half!
  -----------------------------
  gen_with_extra_wb_reg : if g_with_extra_wb_reg generate

    cmp_register_link : xwb_register_link -- puts a register of delay between crossbars
    port map (
      clk_sys_i                             => sys_clk_i,
      rst_n_i                               => sys_rst_n,
      slave_i                               => cbar_slave_in_reg0(0),
      slave_o                               => cbar_slave_out_reg0(0),
      master_i                              => cbar_slave_out(0),
      master_o                              => cbar_slave_in(0)
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

  -- The Internal Wishbone B.4 crossbar
  cmp_interconnect : xwb_sdb_crossbar
  generic map(
    g_num_masters                             => c_masters,
    g_num_slaves                              => c_slaves,
    g_registered                              => true,
    g_wraparound                              => true, -- Should be true for nested buses
    g_layout                                  => c_layout,
    g_sdb_addr                                => c_sdb_address
  )
  port map(
    clk_sys_i                                 => sys_clk_i,
    rst_n_i                                   => sys_rst_n,
    -- Master connections (INTERCON is a slave)
    slave_i                                   => cbar_slave_in,
    slave_o                                   => cbar_slave_out,
    -- Slave connections (INTERCON is a master)
    master_i                                  => cbar_master_in,
    master_o                                  => cbar_master_out
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
    rst_n_i                                 => sys_rst_n,
    master_i                                => wb_slv_adp_in,
    master_o                                => wb_slv_adp_out,
    sl_adr_i                                => resized_addr,
    sl_dat_i                                => cbar_master_out(c_slv_afc_mgmt_regs_id).dat,
    sl_sel_i                                => cbar_master_out(c_slv_afc_mgmt_regs_id).sel,
    sl_cyc_i                                => cbar_master_out(c_slv_afc_mgmt_regs_id).cyc,
    sl_stb_i                                => cbar_master_out(c_slv_afc_mgmt_regs_id).stb,
    sl_we_i                                 => cbar_master_out(c_slv_afc_mgmt_regs_id).we,
    sl_dat_o                                => cbar_master_in(c_slv_afc_mgmt_regs_id).dat,
    sl_ack_o                                => cbar_master_in(c_slv_afc_mgmt_regs_id).ack,
    sl_rty_o                                => cbar_master_in(c_slv_afc_mgmt_regs_id).rty,
    sl_err_o                                => cbar_master_in(c_slv_afc_mgmt_regs_id).err,
    sl_stall_o                              => cbar_master_in(c_slv_afc_mgmt_regs_id).stall
  );

  -- By doing this zeroing we avoid the issue related to BYTE -> WORD  conversion
  -- slave addressing (possibly performed by the slave adapter component)
  -- in which a bit in the MSB of the peripheral addressing part (31 - 5 in our case)
  -- is shifted to the internal register adressing part (4 - 0 in our case).
  -- Therefore, possibly changing the these bits!
  -- See afc_mgmt_port.vhd for register bank addresses
  resized_addr(c_periph_addr_size-1 downto 0)
                                            <= cbar_master_out(c_slv_afc_mgmt_regs_id).adr(c_periph_addr_size-1 downto 0);
  resized_addr(c_wishbone_address_width-1 downto c_periph_addr_size)
                                            <= (others => '0');

  -----------------------------
  -- AFC MGMT Register Wishbone Interface. Word addressed!
  -----------------------------
  --AFC MGMT register interface is the slave number 0, word addressed
  cmp_afc_mgmt_regs : afc_mgmt_regs
  port map(
    rst_n_i                                 => sys_rst_n,
    clk_sys_i                               => sys_clk_i,
    wb_adr_i                                => wb_slv_adp_out.adr(0 downto 0),
    wb_dat_i                                => wb_slv_adp_out.dat,
    wb_dat_o                                => wb_slv_adp_in.dat,
    wb_cyc_i                                => wb_slv_adp_out.cyc,
    wb_sel_i                                => wb_slv_adp_out.sel,
    wb_stb_i                                => wb_slv_adp_out.stb,
    wb_we_i                                 => wb_slv_adp_out.we,
    wb_ack_o                                => wb_slv_adp_in.ack,
    wb_stall_o                              => wb_slv_adp_in.stall,
    regs_i                                  => regs_in,
    regs_o                                  => regs_out
  );

  -- Unused wishbone signals
  wb_slv_adp_in.err                         <= '0';
  wb_slv_adp_in.rty                         <= '0';

  -- Wishbone Interface Register input assignments.
  regs_in.clk_distrib_reserved_i            <= (others => '0');
  regs_in.dummy_reserved_i                  <= (others => '0');

  -- Wishbone Interface Register output assignments.
  si57x_oe_o                                <= regs_out.clk_distrib_si57x_oe_o;

  -----------------------------
  -- I2C Programmable Si57x VCXO
  -----------------------------
  -- I2C Programmable VCXO control interface.
  -- Note: I2C registers are 8-bit wide, but accessed as 32-bit registers

  cmp_si57x_i2c : xwb_i2c_master
  generic map(
    g_interface_mode                        => g_interface_mode,
    g_address_granularity                   => g_address_granularity
  )
  port map (
    clk_sys_i                               => sys_clk_i,
    rst_n_i                                 => sys_rst_n,

    slave_i                                 => cbar_master_out(c_slv_si57x_i2c_id),
    slave_o                                 => cbar_master_in(c_slv_si57x_i2c_id),
    desc_o                                  => open,

    scl_pad_i                               => si57x_i2c_scl_in,
    scl_pad_o                               => si57x_i2c_scl_out,
    scl_padoen_o                            => si57x_i2c_scl_oe_n,
    sda_pad_i                               => si57x_i2c_sda_in,
    sda_pad_o                               => si57x_i2c_sda_out,
    sda_padoen_o                            => si57x_i2c_sda_oe_n
  );

  si57x_scl_pad_b  <= si57x_i2c_scl_out(0) when si57x_i2c_scl_oe_n(0) = '0' else 'Z';
  si57x_i2c_scl_in(0) <= si57x_scl_pad_b;

  si57x_sda_pad_b  <= si57x_i2c_sda_out(0) when si57x_i2c_sda_oe_n(0) = '0' else 'Z';
  si57x_i2c_sda_in(0) <= si57x_sda_pad_b;

  -- Unused used wishbone signals
  --cbar_master_in(c_slv_si57x_i2c_id).err    <= '0';
  --cbar_master_in(c_slv_si57x_i2c_id).err    <= '0';
  --cbar_master_in(c_slv_si57x_i2c_id).rty    <= '0';

end rtl;
