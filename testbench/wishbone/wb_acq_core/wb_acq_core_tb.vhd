-------------------------------------------------------------------------------
-- Title      : Acquisition core testbench
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Simulation
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2023-03-24  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- General common cores
use work.gencores_pkg.all;
-- Genrams cores
use work.genram_pkg.all;
-- BPM acq core cores
use work.acq_core_pkg.all;
-- DBE wishbone cores
use work.ifc_wishbone_pkg.all;
-- AXI cores
use work.pcie_cntr_axi_pkg.all;

use work.wb_acq_core_regs_consts_pkg.all;
use work.wishbone_tcp_server_pkg.all;
use work.sim_wishbone.all;

entity wb_acq_core_tb is
  generic (
    g_HOSTNAME : string := "127.0.0.1:10022"
  );
end wb_acq_core_tb;

architecture simu of wb_acq_core_tb is
  constant c_interface_mode                        : t_wishbone_interface_mode := CLASSIC;
  constant c_address_granularity                   : t_wishbone_address_granularity := BYTE;
  constant c_acq_addr_width                        : natural := 32;
  constant c_acq_num_channels                      : natural := 5;
  constant c_acq_channels                          : t_acq_chan_param_array := c_default_acq_chan_param_array;
  constant c_ddr_payload_width                     : natural := 256;
  constant c_ddr_dq_width                          : natural := 64;
  constant c_ddr_addr_width                        : natural := 32;
  constant c_multishot_ram_size                    : natural := 2048;
  constant c_fifo_fc_size                          : natural := 64;
  constant c_sim_readback                          : boolean := false;
  constant c_ddr_interface_type                    : string  := "AXIS";
  constant c_max_burst_size                        : natural := 4;

  procedure f_gen_clk(constant freq : in    natural;
                      signal   clk  : inout std_logic) is
  begin
    loop
      wait for (0.5 / real(freq)) * 1 sec;
      clk <= not clk;
    end loop;
  end procedure f_gen_clk;

  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
  begin
    for i in 1 to cycles loop
      wait until rising_edge(clk);
    end loop;
  end procedure f_wait_cycles;

  signal fs_clk                                    : std_logic := '0';
  signal fs_ce                                     : std_logic := '0';
  signal fs_rst_n                                  : std_logic := '0';
  signal sys_clk                                   : std_logic := '0';
  signal sys_rst_n                                 : std_logic := '0';
  signal ext_clk                                   : std_logic := '0';
  signal ext_rst_n                                 : std_logic := '0';
-----------------------------
-- Wishbone Control Interface signals
-----------------------------
  signal wb_mtr_i                                  : t_wishbone_master_in;
  signal wb_mtr_o                                  : t_wishbone_master_out := (
    stb => '0',
    cyc => '0',
    adr => (others => '0'),
    dat => (others => '0'),
    we  => '0',
    sel => (others => '0')
  );
-----------------------------
-- External Interface
-----------------------------
  signal acq_chan_array                            : t_acq_chan_array(c_acq_num_channels-1 downto 0);
-----------------------------
-- DRRAM Interface
-----------------------------
  signal dpram_dout                                : std_logic_vector(f_acq_chan_find_widest(c_acq_channels)-1 downto 0);
  signal dpram_valid                               : std_logic;
-----------------------------
-- External Interface (w/ FLow Control)
-----------------------------
  signal ext_dout                                  : std_logic_vector(c_ddr_payload_width-1 downto 0);
  signal ext_valid                                 : std_logic;
  signal ext_addr                                  : std_logic_vector(c_ddr_addr_width-1 downto 0);
  signal ext_sof                                   : std_logic;
  signal ext_eof                                   : std_logic;
  signal ext_dreq                                  : std_logic; -- for debbuging purposes
  signal ext_stall                                 : std_logic; -- for debbuging purposes

-----------------------------
-- AXIS DDR3 SDRAM Interface (choose between UI and AXIS with c_ddr_interface_type)
-----------------------------
-- AXIS Read Channel
  signal axis_mm2s_cmd_ma_i                        : t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
  signal axis_mm2s_cmd_ma_o                        : t_axis_cmd_master_out;
  signal axis_mm2s_pld_sl_i                        : t_axis_pld_slave_in := cc_dummy_axis_pld_slave_in;
  signal axis_mm2s_pld_sl_o                        : t_axis_pld_slave_out;
-- AXIMM Write Channel
  signal axis_s2mm_cmd_ma_i                        : t_axis_cmd_master_in := cc_dummy_axis_cmd_master_in;
  signal axis_s2mm_cmd_ma_o                        : t_axis_cmd_master_out;
  signal axis_s2mm_pld_ma_i                        : t_axis_pld_master_in := cc_dummy_axis_pld_master_in;
  signal axis_s2mm_pld_ma_o                        : t_axis_pld_master_out;
-----------------------------
-- Debug Interface
-----------------------------
  signal dbg_ddr_rb_start_p                        : std_logic := '0';
  signal dbg_ddr_rb_rdy                            : std_logic;
  signal dbg_ddr_rb_data                           : std_logic_vector(c_ddr_payload_width-1 downto 0);
  signal dbg_ddr_rb_addr                           : std_logic_vector(c_acq_addr_width-1 downto 0);
  signal dbg_ddr_rb_valid                          : std_logic;
begin

  f_gen_clk(100_000_000, fs_clk);
  f_gen_clk(100_000_000, sys_clk);
  f_gen_clk(100_000_000, ext_clk);

  process
    variable v_wb_tcp_srv_inst : t_wishbone_tcp_server;
    variable v_msg_type        : t_wishbone_tcp_server_msg_type;
    variable v_addr, v_data    : std_logic_vector(31 downto 0);
  begin
    v_wb_tcp_srv_inst := new_wishbone_tcp_server(g_HOSTNAME);
    init(wb_mtr_o);
    f_wait_cycles(sys_clk, 10);
    fs_rst_n <= '1';
    sys_rst_n <= '1';
    ext_rst_n <= '1';
    f_wait_cycles(sys_clk, 20);
    loop
      wishbone_tcp_server_wait_con(v_wb_tcp_srv_inst);
      loop
        wishbone_tcp_server_wait_data(v_wb_tcp_srv_inst, v_msg_type);
        case (v_msg_type) is
          when READ_DATA =>
            wishbone_tcp_server_get_addr_data(v_wb_tcp_srv_inst, v_addr, v_data);
            read32(sys_clk, wb_mtr_o, wb_mtr_i, v_addr, v_data);
            wishbone_tcp_server_write_data(v_wb_tcp_srv_inst, v_data);

          when WRITE_DATA =>
            wishbone_tcp_server_get_addr_data(v_wb_tcp_srv_inst, v_addr, v_data);
            write32(sys_clk, wb_mtr_o, wb_mtr_i, v_addr, v_data);
            report "Write ADDR: 0x" & to_hex_string(v_addr) & " DATA: 0x" & to_hex_string(v_data);

          when WAIT_EVENT =>
            f_wait_cycles(sys_clk, 100);
            wishbone_tcp_server_write_event(v_wb_tcp_srv_inst, "evt1");

          when DEBUG =>
            report "DEBUG";

          when DISCONNECTED =>
            report "Client disconnected";
            exit;

          when PARSING_ERR => report "PARSING_ERR";

          when EXIT_SIMU =>
            report "Exiting...";
            std.env.finish;
        end case;
      end loop;
    end loop;
    std.env.finish;
  end process;

  axis_s2mm_cmd_ma_i.tready <= '1';
  axis_s2mm_cmd_ma_i.wr_xfer_cmplt <= '1';
  acq_chan_array(0).dvalid <= '1';
  acq_chan_array(0).val_low <= x"00000001" & x"00000000";
  acq_chan_array(0).val_high <= x"00000003" & x"00000002";

  cmp_wb_acq_core: component xwb_acq_core
    generic map
    (
      g_interface_mode                          => c_interface_mode,
      g_address_granularity                     => c_address_granularity,
      g_acq_addr_width                          => c_acq_addr_width,
      g_acq_num_channels                        => c_acq_num_channels,
      g_acq_channels                            => c_acq_channels,
      g_ddr_payload_width                       => c_ddr_payload_width,
      g_ddr_dq_width                            => c_ddr_dq_width,
      g_ddr_addr_width                          => c_ddr_addr_width,
      g_multishot_ram_size                      => c_multishot_ram_size,
      g_fifo_fc_size                            => c_fifo_fc_size,
      g_sim_readback                            => c_sim_readback,
      g_ddr_interface_type                      => c_ddr_interface_type,
      g_max_burst_size                          => c_max_burst_size
    )
    port map
    (
      fs_clk_i                                  => fs_clk,
      fs_ce_i                                   => fs_ce,
      fs_rst_n_i                                => fs_rst_n,

      sys_clk_i                                 => sys_clk,
      sys_rst_n_i                               => sys_rst_n,

      ext_clk_i                                 => ext_clk,
      ext_rst_n_i                               => ext_rst_n,

      -----------------------------
      -- Wishbone Control Interface signals
      -----------------------------
      wb_slv_i                                  => wb_mtr_o,
      wb_slv_o                                  => wb_mtr_i,

      -----------------------------
      -- External Interface
      -----------------------------
      acq_chan_array_i                          => acq_chan_array,

      -----------------------------
      -- DRRAM Interface
      -----------------------------
      dpram_dout_o                              => dpram_dout,
      dpram_valid_o                             => dpram_valid,

      -----------------------------
      -- External Interface (w/ FLow Control)
      -----------------------------
      ext_dout_o                                => ext_dout,
      ext_valid_o                               => ext_valid,
      ext_addr_o                                => ext_addr,
      ext_sof_o                                 => ext_sof,
      ext_eof_o                                 => ext_eof,
      ext_dreq_o                                => ext_dreq,
      ext_stall_o                               => ext_stall,

      -----------------------------
      -- Xilinx UI DDR3 SDRAM Interface (not used)
      -----------------------------
      ui_app_addr_o                             => open,
      ui_app_cmd_o                              => open,
      ui_app_en_o                               => open,
      ui_app_rdy_i                              => '0',

      ui_app_wdf_data_o                         => open,
      ui_app_wdf_end_o                          => open,
      ui_app_wdf_mask_o                         => open,
      ui_app_wdf_wren_o                         => open,
      ui_app_wdf_rdy_i                          => '0',

      ui_app_rd_data_i                          => (others => '0'),
      ui_app_rd_data_end_i                      => '0',
      ui_app_rd_data_valid_i                    => '0',

      ui_app_req_o                              => open,
      ui_app_gnt_i                              => '0',

      -----------------------------
      -- AXIS DDR3 SDRAM Interface (choose betwe
      -----------------------------
      -- AXIS Read Channel
      axis_mm2s_cmd_ma_i                        => axis_mm2s_cmd_ma_i,
      axis_mm2s_cmd_ma_o                        => axis_mm2s_cmd_ma_o,
      axis_mm2s_pld_sl_i                        => axis_mm2s_pld_sl_i,
      axis_mm2s_pld_sl_o                        => axis_mm2s_pld_sl_o,
      -- AXIMM Write Channel
      axis_s2mm_cmd_ma_i                        => axis_s2mm_cmd_ma_i,
      axis_s2mm_cmd_ma_o                        => axis_s2mm_cmd_ma_o,
      axis_s2mm_pld_ma_i                        => axis_s2mm_pld_ma_i,
      axis_s2mm_pld_ma_o                        => axis_s2mm_pld_ma_o,

      -----------------------------
      -- Debug Interface
      -----------------------------
      dbg_ddr_rb_start_p_i                      => dbg_ddr_rb_start_p,
      dbg_ddr_rb_rdy_o                          => dbg_ddr_rb_rdy,
      dbg_ddr_rb_data_o                         => dbg_ddr_rb_data,
      dbg_ddr_rb_addr_o                         => dbg_ddr_rb_addr,
      dbg_ddr_rb_valid_o                        => dbg_ddr_rb_valid
    );

end architecture simu;
