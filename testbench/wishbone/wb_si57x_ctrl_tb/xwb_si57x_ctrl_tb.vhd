-------------------------------------------------------------------------------
-- Title      : Testbench for design "xwb_si57x_ctrl"
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2024 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2024-06-13  1.0      augusto	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;
use work.sim_wishbone.all;
use work.ifc_wishbone_pkg.all;
use work.wb_si57x_ctrl_regs_consts_pkg.all;

entity xwb_si57x_ctrl_tb is
end entity xwb_si57x_ctrl_tb;

architecture sim of xwb_si57x_ctrl_tb is

  type t_si57x_dspll_regs is record
    hs_div: std_logic_vector(2 downto 0);
    n1: std_logic_vector(6 downto 0);
    rfreq: std_logic_vector(37 downto 0);
  end record;

  constant c_int_xtal_freq_hz: real := 114.285e6;
  constant c_startup_freq_hz : real := 100.0e6;

  constant c_clk_freq_hz     : real := 10.0e6;
  constant c_i2c_scl_freq_hz : real := 250.0e3;
  constant c_scl_clk_div     : natural range 1 to 65536 := natural(ceil(c_clk_freq_hz / (4.0 * c_i2c_scl_freq_hz)));
  constant c_si57x_i2c_addr  : std_logic_vector(6 downto 0) := "1010101";

  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
  begin
    for i in 1 to cycles loop
      wait until rising_edge(clk);
    end loop;
  end procedure f_wait_cycles;

  procedure f_wait_si57x_ctrl_idle(signal clk: in std_logic;
                                   signal wb_slv_i: out t_wishbone_slave_in;
                                   signal wb_slv_o: in t_wishbone_slave_out;
                                   variable sta_reg: out std_logic_vector(31 downto 0)) is
  begin
    while true loop
      read32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_STA_ADDR, sta_reg);
      if sta_reg(c_WB_SI57X_CTRL_REGS_STA_BUSY_OFFSET) = '0' then
        exit;
      end if;
    end loop;
  end procedure f_wait_si57x_ctrl_idle;

  signal rst_n               : std_logic := '0';
  signal wb_slv_i            : t_wishbone_slave_in;
  signal wb_slv_o            : t_wishbone_slave_out;
  signal sda_mst_i           : std_logic;
  signal sda_mst_o           : std_logic;
  signal sda_mst_oe_o        : std_logic;
  signal scl_mst_i           : std_logic;
  signal scl_mst_o           : std_logic;
  signal scl_mst_oe_o        : std_logic;

  signal scl_slv_i           : std_logic;
  signal sda_slv_i           : std_logic;
  signal sda_slv_o           : std_logic;
  signal sda_slv_oe_o        : std_logic;
  signal freq                : real;
  signal dspll_model         : t_si57x_dspll_regs;

  -- clock
  signal clk                 : std_logic := '0';

begin  -- architecture sim

  cmp_si57x_model: entity work.si57x_model
    generic map (
      g_INTERNAL_XTAL_FREQ_HZ => c_int_xtal_freq_hz,
      g_STARTUP_FREQ_HZ       => c_startup_freq_hz,
      g_I2C_SLAVE_ADDR        => c_si57x_i2c_addr
    )
    port map (
      clk_i    => clk,
      rst_n_i  => rst_n,
      scl_i    => scl_slv_i,
      sda_i    => sda_slv_i,
      sda_o    => sda_slv_o,
      sda_oe   => sda_slv_oe_o,
      hs_div_o => dspll_model.hs_div,
      n1_o     => dspll_model.n1,
      rfreq_o  => dspll_model.rfreq,
      freq_o   => freq
    );

  cmp_xwb_si57x_ctrl: xwb_si57x_ctrl
    generic map (
      g_SI57X_I2C_ADDR      => c_si57x_i2c_addr,
      g_SCL_CLK_DIV         => c_scl_clk_div,
      g_SI57X_7PPM_VARIANT  => false,
      g_INTERFACE_MODE      => CLASSIC,
      g_ADDRESS_GRANULARITY => BYTE
    )
    port map (
      clk_i     => clk,
      rst_n_i   => rst_n,
      wb_slv_i  => wb_slv_i,
      wb_slv_o  => wb_slv_o,
      sda_i     => sda_mst_i,
      sda_o     => sda_mst_o,
      sda_oe_o  => sda_mst_oe_o,
      scl_i     => scl_mst_i,
      scl_o     => scl_mst_o,
      scl_oe_o  => scl_mst_oe_o
    );

  -- clock generation
  clk <= not clk after (0.5 / c_clk_freq_hz) * 1.0 sec;

  process
    variable dspll_read, dspll_strp, dspll_new: t_si57x_dspll_regs;
    variable freq_strp: real;
    variable sta_reg, tmp_reg: std_logic_vector(31 downto 0);
  begin
    -- Wishbone initialization
    init(wb_slv_i);
    f_wait_cycles(clk, 2);
    rst_n <= '1';
    f_wait_cycles(clk, 2);

    -- Get the startup DSPLL registers and frequency
    dspll_strp := dspll_model;
    freq_strp := freq;

    -- Write a new DSPLL configurarion, this should result in a 220 MHz output
    dspll_new.rfreq := "00" & x"2E33461FA";
    dspll_new.hs_div := "010";
    dspll_new.n1 := "0000011";

    write32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_ADDR,
               x"0000" &  dspll_new.hs_div & dspll_new.n1 &  dspll_new.rfreq(37 downto 32));
    write32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_RFREQ_LSB_ADDR,
               dspll_new.rfreq(31 downto 0));
    write32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_CTL_ADDR,
              (c_WB_SI57X_CTRL_REGS_CTL_APPLY_CFG_OFFSET => '1',
               others => '0'));

    -- Wait for the Si57x controller to finish operations
    f_wait_si57x_ctrl_idle(clk, wb_slv_i, wb_slv_o, sta_reg);

    -- Check if the output frequency was updated to the expected value
    assert abs((freq / 220.0e6) - 1.0) < 1.0e-7
      report "Expected the output frequency to be 220 MHz +- 0.001%, but it is " &
      to_string(freq/1.0e6) & " MHz"
      severity failure;

    -- Check if the status flags are correct
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_I2C_ERR_OFFSET) = '0'
      report "Unexpected I2C error occured!" severity failure;
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_CFG_IN_SYNC_OFFSET) = '1'
      report "Si57x DSPLL registers are not in sync!" severity failure;
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_STRP_COMPLETE_OFFSET) = '0'
      report "Si57x DSPLL startup registers weren't read yet, the STRP_COMPLETE flag should be false!"
      severity failure;
    assert dspll_new = dspll_model
      report "DSPLL registers of the Si57x model don't match the new values!"
      severity failure;

    -- Restore startup registers
    write32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_CTL_ADDR,
              (c_WB_SI57X_CTRL_REGS_CTL_READ_STRP_REGS_OFFSET => '1',
               others => '0'));

    -- Wait for the Si57x controller to finish operations
    f_wait_si57x_ctrl_idle(clk, wb_slv_i, wb_slv_o, sta_reg);

    -- Check if the status flags are correct
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_I2C_ERR_OFFSET) = '0'
      report "Unexpected I2C error occured!" severity failure;
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_CFG_IN_SYNC_OFFSET) = '0'
      report "Si57x DSPLL should not be in sync, but the STA_CFG_IN_SYNC flag says otherwise!"
      severity failure;
    assert sta_reg(c_WB_SI57X_CTRL_REGS_STA_STRP_COMPLETE_OFFSET) = '1'
      report "Si57x DSPLL startup registers were read, the STRP_COMPLETE flag should be true!"
      severity failure;

    -- Check if the restored DSPLL configuration matches the initial state
    assert dspll_strp = dspll_model
      report "Startup DSPLL registers of the Si57x model don't match the value read before!"
      severity failure;
    assert freq_strp = freq
      report "Startup frequency of the Si57x model doesn't match the value read before!"
      severity failure;

    -- Read the startup DSPLL registers via wishbone
    read32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_HSDIV_N1_RFREQ_MSB_STRP_ADDR, tmp_reg);
    dspll_read.hs_div := tmp_reg(15 downto 13);
    dspll_read.n1 := tmp_reg(12 downto 6);
    dspll_read.rfreq(37 downto 32) := tmp_reg(5 downto 0);
    read32_pl(clk, wb_slv_i, wb_slv_o, c_WB_SI57X_CTRL_REGS_RFREQ_LSB_STRP_ADDR, tmp_reg);
    dspll_read.rfreq(31 downto 0) := tmp_reg;

    -- Check if the registers read via wishbone match the expected values
    assert dspll_strp = dspll_read
      report "Startup registers read via wishbone don't match the expected values!" & LF &
      "HSDIV read = 0x" & to_hex_string(dspll_read.hs_div) & LF &
      "N1 read = 0x" & to_hex_string(dspll_read.n1) & LF &
      "RFREQ read = 0x" & to_hex_string(dspll_read.rfreq) & LF
      severity failure;

    f_wait_cycles(clk, 2);
    std.env.finish;
  end process;

  -- Solves the I2C signals direction and values
  proc_i2c_dir_solver:
  process(all)
  begin
    if sda_mst_oe_o = '1' and sda_slv_oe_o = '0' then
      -- Master takes control of the SDA line
      sda_mst_i <= sda_mst_o;
      sda_slv_i <= sda_mst_o;
    elsif sda_mst_oe_o = '0' and sda_slv_oe_o = '1' then
      -- Slave takes control of the SDA line
      sda_mst_i <= sda_slv_o;
      sda_slv_i <= sda_slv_o;
    elsif sda_mst_oe_o = '0' and sda_slv_oe_o = '0' then
      -- No one is driving the SDA line, make it high
      sda_mst_i <= '1';
      sda_slv_i <= '1';
    elsif sda_mst_oe_o = '1' and sda_slv_oe_o = '1' then
      -- Both master and slave are driving the SDA line, logic-low wins
      if sda_slv_o = '0' or sda_mst_o = '0' then
        sda_mst_i <= '0';
        sda_slv_i <= '0';
      else
        sda_mst_i <= '1';
        sda_slv_i <= '1';
      end if;
    end if;

    -- If the I2C master controller takes control of the SCL line, connects its
    -- SCL output signal to the SCL inputs (slave and master). Else, makes both
    -- SCL inputs high
    if scl_mst_oe_o = '1' then
      scl_slv_i <= scl_mst_o;
      scl_mst_i <= scl_mst_o;
    else
      scl_slv_i <= '1';
      scl_mst_i <= '1';
    end if;
  end process;

end architecture sim;
