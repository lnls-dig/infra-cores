------------------------------------------------------------------------------
-- Title      : Top DSP design
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2014-04-30
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Wishbone Wrapper for PCI Core
-------------------------------------------------------------------------------
-- Copyright (c) 2014 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2014-04-30  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.ifc_wishbone_pkg.all;
use work.ipcores_pkg.all;
use work.pcie_cntr_axi_pkg.all;

entity wb_bpm_pcie is
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
end entity wb_bpm_pcie;

architecture rtl of wb_bpm_pcie is

begin

  cmp_wb_pcie_cntr : wb_pcie_cntr
  generic map (
    g_ma_interface_mode                       => g_ma_interface_mode,
    g_ma_address_granularity                  => g_ma_address_granularity,
    g_simulation                              => g_simulation
  )
  port map (
    -- DDR3 memory pins
    ddr3_dq_b                                 => ddr3_dq_b,
    ddr3_dqs_p_b                              => ddr3_dqs_p_b,
    ddr3_dqs_n_b                              => ddr3_dqs_n_b,
    ddr3_addr_o                               => ddr3_addr_o,
    ddr3_ba_o                                 => ddr3_ba_o,
    ddr3_cs_n_o                               => ddr3_cs_n_o,
    ddr3_ras_n_o                              => ddr3_ras_n_o,
    ddr3_cas_n_o                              => ddr3_cas_n_o,
    ddr3_we_n_o                               => ddr3_we_n_o,
    ddr3_reset_n_o                            => ddr3_reset_n_o,
    ddr3_ck_p_o                               => ddr3_ck_p_o,
    ddr3_ck_n_o                               => ddr3_ck_n_o,
    ddr3_cke_o                                => ddr3_cke_o,
    ddr3_dm_o                                 => ddr3_dm_o,
    ddr3_odt_o                                => ddr3_odt_o,

    -- PCIe transceivers
    pci_exp_rxp_i                             => pci_exp_rxp_i,
    pci_exp_rxn_i                             => pci_exp_rxn_i,
    pci_exp_txp_o                             => pci_exp_txp_o,
    pci_exp_txn_o                             => pci_exp_txn_o,

    -- Necessity signals
    ddr_clk_i                                 => ddr_clk_i,
    ddr_rst_i                                 => ddr_rst_i,
    pcie_clk_p_i                              => pcie_clk_p_i,
    pcie_clk_n_i                              => pcie_clk_n_i,
    pcie_rst_n_i                              => pcie_rst_n_i,

    -- DDR memory controller interface
    ddr_aximm_sl_aclk_o                       => ddr_aximm_sl_aclk_o,
    ddr_aximm_sl_aresetn_o                    => ddr_aximm_sl_aresetn_o,
    ddr_aximm_w_sl_awid_i                     => ddr_aximm_w_sl_awid_i,
    ddr_aximm_w_sl_awaddr_i                   => ddr_aximm_w_sl_awaddr_i,
    ddr_aximm_w_sl_awlen_i                    => ddr_aximm_w_sl_awlen_i,
    ddr_aximm_w_sl_awsize_i                   => ddr_aximm_w_sl_awsize_i,
    ddr_aximm_w_sl_awburst_i                  => ddr_aximm_w_sl_awburst_i,
    ddr_aximm_w_sl_awlock_i                   => ddr_aximm_w_sl_awlock_i,
    ddr_aximm_w_sl_awcache_i                  => ddr_aximm_w_sl_awcache_i,
    ddr_aximm_w_sl_awprot_i                   => ddr_aximm_w_sl_awprot_i,
    ddr_aximm_w_sl_awqos_i                    => ddr_aximm_w_sl_awqos_i,
    ddr_aximm_w_sl_awvalid_i                  => ddr_aximm_w_sl_awvalid_i,
    ddr_aximm_w_sl_awready_o                  => ddr_aximm_w_sl_awready_o,
    ddr_aximm_w_sl_wdata_i                    => ddr_aximm_w_sl_wdata_i,
    ddr_aximm_w_sl_wstrb_i                    => ddr_aximm_w_sl_wstrb_i,
    ddr_aximm_w_sl_wlast_i                    => ddr_aximm_w_sl_wlast_i,
    ddr_aximm_w_sl_wvalid_i                   => ddr_aximm_w_sl_wvalid_i,
    ddr_aximm_w_sl_wready_o                   => ddr_aximm_w_sl_wready_o,
    ddr_aximm_w_sl_bready_i                   => ddr_aximm_w_sl_bready_i,
    ddr_aximm_w_sl_bid_o                      => ddr_aximm_w_sl_bid_o,
    ddr_aximm_w_sl_bresp_o                    => ddr_aximm_w_sl_bresp_o,
    ddr_aximm_w_sl_bvalid_o                   => ddr_aximm_w_sl_bvalid_o,
    ddr_aximm_r_sl_arid_i                     => ddr_aximm_r_sl_arid_i,
    ddr_aximm_r_sl_araddr_i                   => ddr_aximm_r_sl_araddr_i,
    ddr_aximm_r_sl_arlen_i                    => ddr_aximm_r_sl_arlen_i,
    ddr_aximm_r_sl_arsize_i                   => ddr_aximm_r_sl_arsize_i,
    ddr_aximm_r_sl_arburst_i                  => ddr_aximm_r_sl_arburst_i,
    ddr_aximm_r_sl_arlock_i                   => ddr_aximm_r_sl_arlock_i,
    ddr_aximm_r_sl_arcache_i                  => ddr_aximm_r_sl_arcache_i,
    ddr_aximm_r_sl_arprot_i                   => ddr_aximm_r_sl_arprot_i,
    ddr_aximm_r_sl_arqos_i                    => ddr_aximm_r_sl_arqos_i,
    ddr_aximm_r_sl_arvalid_i                  => ddr_aximm_r_sl_arvalid_i,
    ddr_aximm_r_sl_arready_o                  => ddr_aximm_r_sl_arready_o,
    ddr_aximm_r_sl_rready_i                   => ddr_aximm_r_sl_rready_i,
    ddr_aximm_r_sl_rid_o                      => ddr_aximm_r_sl_rid_o,
    ddr_aximm_r_sl_rdata_o                    => ddr_aximm_r_sl_rdata_o,
    ddr_aximm_r_sl_rresp_o                    => ddr_aximm_r_sl_rresp_o,
    ddr_aximm_r_sl_rlast_o                    => ddr_aximm_r_sl_rlast_o,
    ddr_aximm_r_sl_rvalid_o                   => ddr_aximm_r_sl_rvalid_o,

    -- Wishbone interface --
    wb_clk_i                                  => wb_clk_i,
    wb_rst_i                                  => wb_rst_i,
    wb_ma_adr_o                               => wb_ma_adr_o,
    wb_ma_dat_o                               => wb_ma_dat_o,
    wb_ma_sel_o                               => wb_ma_sel_o,
    wb_ma_cyc_o                               => wb_ma_cyc_o,
    wb_ma_stb_o                               => wb_ma_stb_o,
    wb_ma_we_o                                => wb_ma_we_o,
    wb_ma_dat_i                               => wb_ma_dat_i,
    wb_ma_err_i                               => wb_ma_err_i,
    wb_ma_rty_i                               => wb_ma_rty_i,
    wb_ma_ack_i                               => wb_ma_ack_i,
    wb_ma_stall_i                             => wb_ma_stall_i,
    -- Additional exported signals for instantiation
    wb_ma_pcie_rst_o                          => wb_ma_pcie_rst_o,
    pcie_clk_o                                => pcie_clk_o,
    ddr_rdy_o                                 => ddr_rdy_o
  );

end rtl;
