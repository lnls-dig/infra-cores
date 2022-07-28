------------------------------------------------------------------------------
-- Title      : Clock counter wishbone module testbench
------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GCA
-- Created    : 2022-07-19
-- Platform   : Simulation
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2022 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2022-07-19  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.wishbone_pkg.all;
use work.ifc_wishbone_pkg.all;
use work.wb_evt_cnt_regs_consts_pkg.all;
use work.sim_wishbone.all;

entity xwb_evt_cnt_tb is
end entity xwb_evt_cnt_tb;

architecture xwb_evt_cnt_tb_arch of xwb_evt_cnt_tb is
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

  procedure f_gen_random_evt(signal   clk    : in  std_logic;
                             constant cycles : in  natural;
                             signal   evt    : out std_logic) is
    variable seed1, seed2 : integer := 12207031;
    variable rand_num : real;
  begin
    for i in 1 to cycles loop
      uniform(seed1, seed2, rand_num);
      evt <= '1' when rand_num > 0.5 else '0';
      wait until rising_edge(clk);
    end loop;
  end procedure f_gen_random_evt;

  type t_trigger_action is (TRIG_ACT_CLEAR, TRIG_ACT_SNAP);
  signal trig_act        : t_trigger_action := TRIG_ACT_CLEAR;
  signal clk_sys         : std_logic := '0';
  signal clk_evt         : std_logic := '0';
  signal ext_trig        : std_logic := '0';
  signal rst_clk_n       : std_logic := '0';
  signal rst_clk_evt_n   : std_logic := '0';
  signal wb_slave_i      : t_wishbone_slave_in;
  signal wb_slave_o      : t_wishbone_slave_out;
  signal cnt_test_snap   : std_logic_vector(31 downto 0) := (others => '0');
  signal cnt_test        : std_logic_vector(31 downto 0) := (others => '0');
  signal evt             : std_logic := '0';
begin
  -- Generate 100 MHz system clock
  f_gen_clk(100_000_000, clk_sys);
  -- Generate 69.444 MHz for the counter
  f_gen_clk(69_444_444, clk_evt);

  process
    variable v_cnt_snap   : std_logic_vector(31 downto 0) := (others => '0');
  begin
    -- Initialize wishbone signals
    init(wb_slave_i);

    -- Reset cores
    f_wait_cycles(clk_sys, 10);
    rst_clk_n <= '1';
    rst_clk_evt_n <= '1';
    f_wait_cycles(clk_sys, 10);

    -- Set trigger action to clear the counter
    write32_pl(clk_sys, wb_slave_i, wb_slave_o, c_WB_EVT_CNT_REGS_CTL_ADDR,
               (c_WB_EVT_CNT_REGS_CTL_TRIG_ACT_OFFSET => '0',
               others => '0'));
    trig_act <= TRIG_ACT_CLEAR;

    -- Synchronize with clk_evt
    f_wait_cycles(clk_evt, 1);

    -- Send trigger (clear the counter)
    ext_trig <= '1';
    f_wait_cycles(clk_evt, 1);
    ext_trig <= '0';

    -- Synchronize with clk_sys
    f_wait_cycles(clk_sys, 1);

    -- Set trigger action to snapshot mode
    write32_pl(clk_sys, wb_slave_i, wb_slave_o, c_WB_EVT_CNT_REGS_CTL_ADDR,
               (c_WB_EVT_CNT_REGS_CTL_TRIG_ACT_OFFSET => '1',
               others => '0'));
    trig_act <= TRIG_ACT_SNAP;

    -- Synchronize with clk_evt
    f_wait_cycles(clk_evt, 1);

    -- Generate random events
    f_gen_random_evt(clk_evt, 100, evt);

    -- Send trigger (take a snapshot of the counter)
    ext_trig <= '1';
    f_wait_cycles(clk_evt, 1);
    ext_trig <= '0';

    -- Synchronize with clk_sys, also wait for cnt_snap to be available
    -- via wishbone
    f_wait_cycles(clk_sys, 20);

    -- Read the counter snapshot
    read32_pl(clk_sys, wb_slave_i, wb_slave_o, c_WB_EVT_CNT_REGS_CNT_SNAP_ADDR,
              v_cnt_snap);

    -- Check if the counters of xwb_evt_cnt and cnt_test_snap match
    assert cnt_test_snap = v_cnt_snap;

    -- Dummy cycles to make visualization easier
    f_wait_cycles(clk_sys, 10);
    std.env.finish;
  end process;

  -- Emulate the counter of xwb_evt_cnt
  process(clk_evt)
  begin
    if rising_edge(clk_evt) then
      -- Incremment cnt_test only if evt = '1' (new event)
      if evt = '1' then
        cnt_test <= std_logic_vector(unsigned(cnt_test) + 1);
      end if;

      if ext_trig = '1' then
        if trig_act = TRIG_ACT_SNAP then
          cnt_test_snap <= cnt_test;
        elsif trig_act = TRIG_ACT_CLEAR then
          cnt_test <= (others => '0');
        end if;
      end if;

    end if;
  end process;

  cmp_xwb_evt_cnt: xwb_evt_cnt
    generic map (
      g_INTERFACE_MODE      => CLASSIC,
      g_ADDRESS_GRANULARITY => BYTE,
      g_WITH_EXTRA_WB_REG   => false
      )
    port map(
      clk_i                 => clk_sys,
      rst_clk_n_i           => rst_clk_n,
      wb_slv_i              => wb_slave_i,
      wb_slv_o              => wb_slave_o,
      clk_evt_i             => clk_evt,
      rst_clk_evt_n_i       => rst_clk_evt_n,
      evt_i                 => evt,
      ext_trig_i            => ext_trig
      );

end architecture;
