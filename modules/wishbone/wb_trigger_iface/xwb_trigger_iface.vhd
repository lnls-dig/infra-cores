library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- Custom Wishbone Modules
use work.ifc_wishbone_pkg.all;
-- Trigger definitions
use work.trigger_common_pkg.all;

entity xwb_trigger_iface is
  generic
    (
      g_interface_mode       : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity  : t_wishbone_address_granularity := WORD;
      g_sync_edge            : string                         := "positive";
      g_trig_num             : natural range 1 to 24          := 8;
      g_trigger_tristate     : boolean                        := true
    );
  port
    (
      rst_n_i    : in std_logic;
      clk_i      : in std_logic;

      ref_clk_i   : in std_logic;
      ref_rst_n_i : in std_logic;

      -----------------------------
      -- Wishbone signals
      -----------------------------

      wb_slv_i : in  t_wishbone_slave_in;
      wb_slv_o : out t_wishbone_slave_out;

      -----------------------------
      -- External ports
      -----------------------------

      -- only used if g_trigger_tristate = true
      trig_b     : inout std_logic_vector(g_trig_num-1 downto 0);
      -- only used if g_trigger_tristate = false
      trig_i     : in    std_logic_vector(g_trig_num-1 downto 0) := (others => '0');
      trig_o     : out   std_logic_vector(g_trig_num-1 downto 0);
      trig_dir_o : out   std_logic_vector(g_trig_num-1 downto 0);

      -----------------------------
      -- Internal ports
      -----------------------------

      trig_out_o : out t_trig_channel_array(g_trig_num-1 downto 0);
      trig_in_i  : in  t_trig_channel_array(g_trig_num-1 downto 0);

    -------------------------------
    ---- Debug ports
    -------------------------------
      trig_dbg_o : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_sync_o        : out std_logic_vector(g_trig_num-1 downto 0);
      dbg_data_degliteched_o : out std_logic_vector(g_trig_num-1 downto 0)
      );

end xwb_trigger_iface;

architecture rtl of xwb_trigger_iface is
begin

  cmp_wb_trigger_iface : wb_trigger_iface
    generic map (
      g_interface_mode       => g_interface_mode,
      g_address_granularity  => g_address_granularity,
      g_sync_edge            => g_sync_edge,
      g_trig_num             => g_trig_num,
      g_trigger_tristate     => g_trigger_tristate
    )
    port map (
      clk_i       => clk_i,
      rst_n_i     => rst_n_i,
      ref_clk_i   => ref_clk_i,
      ref_rst_n_i => ref_rst_n_i,

      wb_adr_i   => wb_slv_i.adr,
      wb_dat_i   => wb_slv_i.dat,
      wb_dat_o   => wb_slv_o.dat,
      wb_sel_i   => wb_slv_i.sel,
      wb_we_i    => wb_slv_i.we,
      wb_cyc_i   => wb_slv_i.cyc,
      wb_stb_i   => wb_slv_i.stb,
      wb_ack_o   => wb_slv_o.ack,
      wb_err_o   => wb_slv_o.err,
      wb_rty_o   => wb_slv_o.rty,
      wb_stall_o => wb_slv_o.stall,

      trig_b      => trig_b,
      trig_i      => trig_i,
      trig_o      => trig_o,
      trig_dir_o  => trig_dir_o,
      trig_out_o  => trig_out_o,
      trig_in_i   => trig_in_i,
      trig_dbg_o  => trig_dbg_o,
      dbg_data_sync_o        => dbg_data_sync_o,
      dbg_data_degliteched_o => dbg_data_degliteched_o
    );

end rtl;
