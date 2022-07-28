------------------------------------------------------------------------------
-- Title      : XWB Clock Counter Interface
------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GCA
-- Created    : 2022-07-18
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Clock pulse counter with external trigger for clearing and
-- reading.
-------------------------------------------------------------------------------
-- Copyright (c) 2022 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2022-07-18  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity xwb_evt_cnt is
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
end xwb_evt_cnt;

architecture rtl of xwb_evt_cnt is
  signal cnt: unsigned(31 downto 0) := (others => '0');
  signal cnt_snap: unsigned(31 downto 0) := (others => '0');
  signal cnt_snap_sync: std_logic_vector(31 downto 0) := (others => '0');
  signal trig_act: std_logic;
  signal trig_act_sync: std_logic;

  -----------------------------
  -- Wishbone slave adapter signals/structures
  -----------------------------
  signal wb_slv_adp_out                      : t_wishbone_master_out;
  signal wb_slv_adp_in                       : t_wishbone_master_in;
  signal resized_addr                        : std_logic_vector(c_wishbone_address_width-1 downto 0);

  -- Extra Wishbone registering stage
  signal wb_slave_in                         : t_wishbone_slave_in_array (0 downto 0);
  signal wb_slave_out                        : t_wishbone_slave_out_array(0 downto 0);
  signal wb_slave_in_reg0                    : t_wishbone_slave_in_array (0 downto 0);
  signal wb_slave_out_reg0                   : t_wishbone_slave_out_array(0 downto 0);

  -----------------------------
  -- General Constants
  -----------------------------
  -- Number of bits in Wishbone register interface. Plus 2 to account for BYTE addressing
  constant c_PERIPH_ADDR_SIZE                : natural := 8+2;

  -----------------------------
  -- Functions
  -----------------------------

  -- Map Wishbone MODE/GRANULARITY to all components
  -- according to this module generics
  type t_wb_generics is record
    reg_in_mode         : t_wishbone_interface_mode;
    reg_in_granularity  : t_wishbone_address_granularity;
    reg_out_mode        : t_wishbone_interface_mode;
    reg_out_granularity : t_wishbone_address_granularity;
    slave_mode          : t_wishbone_interface_mode;
    slave_granularity   : t_wishbone_address_granularity;
  end record;

  function f_wb_generics (with_reg_link : boolean; mode : t_wishbone_interface_mode; granularity : t_wishbone_address_granularity)
    return t_wb_generics is
      variable v_wb_generic : t_wb_generics;
   begin
      if with_reg_link then
        v_wb_generic.reg_in_mode := mode;
        v_wb_generic.reg_in_granularity := granularity;
        -- Use CLASSIC/BYTE as xwb_register_links needs them, so convert
        -- only once in our wb_slave_adapter
        -- Otherwise a wb_slave adapter will convert them to CLASSIC/BYTE.
        v_wb_generic.reg_out_mode := CLASSIC;
        v_wb_generic.reg_out_granularity := BYTE;
        v_wb_generic.slave_mode := CLASSIC;
        v_wb_generic.slave_granularity := BYTE;
      else
        -- Unused
        v_wb_generic.reg_in_mode := CLASSIC;
        v_wb_generic.reg_in_granularity := BYTE;
        v_wb_generic.reg_out_mode := CLASSIC;
        v_wb_generic.reg_out_granularity := BYTE;
        -- Use the passed generics
        v_wb_generic.slave_mode := mode;
        v_wb_generic.slave_granularity := granularity;
      end if;
      return v_wb_generic;
   end f_wb_generics;

   constant c_WB_GENERICS : t_wb_generics :=
      f_wb_generics (g_WITH_EXTRA_WB_REG, g_INTERFACE_MODE, g_ADDRESS_GRANULARITY);
begin

  -----------------------------
  -- Insert extra Wishbone registering stage for ease timing.
  -----------------------------
  gen_with_extra_wb_reg : if g_WITH_EXTRA_WB_REG generate

    cmp_register_link : xwb_register_link -- puts a register of delay between crossbars
    generic map (
      g_WB_IN_MODE                          => c_WB_GENERICS.reg_in_mode,
      g_WB_IN_GRANULARITY                   => c_WB_GENERICS.reg_in_granularity,
      g_WB_OUT_MODE                         => c_WB_GENERICS.reg_out_mode,
      g_WB_OUT_GRANULARITY                  => c_WB_GENERICS.reg_out_granularity
    )
    port map (
      clk_sys_i                             => clk_i,
      rst_n_i                               => rst_clk_n_i,
      slave_i                               => wb_slave_in_reg0(0),
      slave_o                               => wb_slave_out_reg0(0),
      master_i                              => wb_slave_out(0),
      master_o                              => wb_slave_in(0)
    );

    wb_slave_in_reg0(0)  <= wb_slv_i;
    wb_slv_o             <= wb_slave_out_reg0(0);

  end generate;

  gen_without_extra_wb_reg : if not g_WITH_EXTRA_WB_REG generate

    -- External master connection
    wb_slave_in(0)  <= wb_slv_i;
    wb_slv_o        <= wb_slave_out(0);

  end generate;

  -----------------------------
  -- Slave adapter for Wishbone Register Interface
  -----------------------------
  cmp_slave_adapter : wb_slave_adapter
  generic map (
    g_master_use_struct                      => true,
    g_master_mode                            => g_INTERFACE_MODE,
    -- Cheby with default register map requires granularity to be BYTE
    g_master_granularity                     => BYTE,
    g_slave_use_struct                       => false,
    g_slave_mode                             => c_WB_GENERICS.slave_mode,
    g_slave_granularity                      => c_WB_GENERICS.slave_granularity
  )
  port map (
    clk_sys_i                                => clk_i,
    rst_n_i                                  => rst_clk_n_i,
    master_i                                 => wb_slv_adp_in,
    master_o                                 => wb_slv_adp_out,
    sl_adr_i                                 => resized_addr,
    sl_dat_i                                 => wb_slave_in(0).dat,
    sl_sel_i                                 => wb_slave_in(0).sel,
    sl_cyc_i                                 => wb_slave_in(0).cyc,
    sl_stb_i                                 => wb_slave_in(0).stb,
    sl_we_i                                  => wb_slave_in(0).we,
    sl_dat_o                                 => wb_slave_out(0).dat,
    sl_ack_o                                 => wb_slave_out(0).ack,
    sl_rty_o                                 => wb_slave_out(0).rty,
    sl_err_o                                 => wb_slave_out(0).err,
    sl_stall_o                               => wb_slave_out(0).stall
  );

  -- By doing this zeroing we avoid the issue related to BYTE -> WORD  conversion
  -- slave addressing (possibly performed by the slave adapter component)
  -- in which a bit in the MSB of the peripheral addressing part (31 - 5 in our case)
  -- is shifted to the internal register adressing part (4 - 0 in our case).
  -- Therefore, possibly changing the these bits!
  resized_addr(c_PERIPH_ADDR_SIZE-1 downto 0)
                                             <= wb_slave_in(0).adr(c_PERIPH_ADDR_SIZE-1 downto 0);
  resized_addr(c_WISHBONE_ADDRESS_WIDTH-1 downto c_PERIPH_ADDR_SIZE)
                                             <= (others => '0');

  -- Wishbone registers component
  cmp_evt_cnt_regs: entity work.wb_evt_cnt_regs
    port map (
      rst_n_i          => rst_clk_n_i,
      clk_i            => clk_i,
      wb_i             => wb_slv_adp_out,
      wb_o             => wb_slv_adp_in,
      ctl_trig_act_o   => trig_act,
      cnt_snap_i       => cnt_snap_sync
      );

  -- Clock domain crossing for trig_act from clk_i to clk_evt_i
  cmp_gc_sync_ffs_cnv: gc_sync
    port map (
      rst_n_a_i      => rst_clk_evt_n_i,
      clk_i          => clk_evt_i,
      d_i            => trig_act,
      q_o            => trig_act_sync
    );

  -- Clock domain crossing for cnt_snap from clk_evt_i to clk_i
  cmp_sync_cnt: gc_sync_word_wr
    generic map (
      g_AUTO_WR => TRUE,
      g_WIDTH => 32
      )
    port map (
      clk_in_i    => clk_evt_i,
      rst_in_n_i  => rst_clk_evt_n_i,
      data_i      => std_logic_vector(cnt_snap),
      clk_out_i   => clk_i,
      rst_out_n_i => rst_clk_n_i,
      data_o      => cnt_snap_sync
      );

  process(clk_evt_i)
  begin
    if rising_edge(clk_evt_i) then
      if rst_clk_n_i = '0' then
        cnt <= (others => '0');
      else
        -- Incremment cnt for each external event
        if evt_i = '1' then
          cnt <= cnt + 1;
        end if;

        -- When receiving an external trigger pulse clear or take a snapshot of
        -- the counter depending on the state of the ctl.trig_act bit
        if ext_trig_i = '1' then
          if trig_act_sync = '0' then
            cnt <= (others => '0');
          else
            cnt_snap <= cnt;
          end if;
        end if;

      end if;
    end if;
  end process;

end architecture rtl;
