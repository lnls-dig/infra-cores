-------------------------------------------------------------------------------
-- Title      : Wishbone master interface controlled via UART record wrapper
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero <augusto.fraga@lnls.br>
-- Platform   : FPGA-generic
-- Standard   : VHDL 93
-------------------------------------------------------------------------------
-- Description: Expose an wishbone master interface via UART using simple text
--              commands.
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2023-10-23  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.ifc_wishbone_pkg.all;

entity xwb_master_uart is
  generic (
    g_END_LINE_CHAR:  std_logic_vector(7 downto 0) := x"0A";
    g_INTERFACE_MODE: t_wishbone_interface_mode    := CLASSIC
  );
  port (
    -- Core clock
    clk_i:           in  std_logic;
    -- Core reset (active low)
    rst_n_i:         in  std_logic;
    -- Baud-rate divider: baud = freq(clk_i) / (clk_div_i + 1)
    clk_div_i:       in  unsigned (15 downto 0);
    -- UART TX output
    tx_o:            out std_logic;
    -- UART RX input
    rx_i:            in  std_logic;
    -- Wishbone master interface
    wb_master_i:     in  t_wishbone_master_in;
    wb_master_o:     out t_wishbone_master_out
  );
end entity xwb_master_uart;

architecture arch of xwb_master_uart is
begin
  cmp_wb_master_uart: wb_master_uart
    generic map (
      g_END_LINE_CHAR  => g_END_LINE_CHAR,
      g_INTERFACE_MODE => g_INTERFACE_MODE
    )
    port map (
      clk_i        => clk_i,
      rst_n_i      => rst_n_i,
      clk_div_i    => clk_div_i,
      tx_o         => tx_o,
      rx_i         => rx_i,

      m_wb_adr_o   => wb_master_o.adr,
      m_wb_sel_o   => wb_master_o.sel,
      m_wb_we_o    => wb_master_o.we,
      m_wb_dat_o   => wb_master_o.dat,
      m_wb_dat_i   => wb_master_i.dat,
      m_wb_cyc_o   => wb_master_o.cyc,
      m_wb_stb_o   => wb_master_o.stb,
      m_wb_ack_i   => wb_master_i.ack,
      m_wb_err_i   => wb_master_i.err,
      m_wb_stall_i => wb_master_i.stall,
      m_wb_rty_i   => wb_master_i.rty
    );
end architecture;
