-------------------------------------------------------------------------------
-- Title      : Si57x simulation model testbench
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
-- Date        Version  Author                Description
-- 2024-05-21  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity si57x_model_tb is
end entity;

architecture sim of si57x_model_tb is
  constant si57x_i2c_addr: std_logic_vector(6 downto 0) := "1010101";
  type t_byte_arr is array (natural range <>) of std_logic_vector(7 downto 0);

  type t_si57x_pll_regs is record
    rfreq: std_logic_vector(37 downto 0);
    n1: std_logic_vector(6 downto 0);
    hs_div: std_logic_vector(2 downto 0);
  end record;

  function f_decode_si57x_regs(regs_arr: t_byte_arr(0 to 5)) return t_si57x_pll_regs is
    variable si57x_regs: t_si57x_pll_regs;
  begin
    si57x_regs.hs_div := regs_arr(0)(7 downto 5);
    si57x_regs.n1 := regs_arr(0)(4 downto 0) & regs_arr(1)(7 downto 6);
    si57x_regs.rfreq := regs_arr(1)(5 downto 0) &
                        regs_arr(2)(7 downto 0) &
                        regs_arr(3)(7 downto 0) &
                        regs_arr(4)(7 downto 0) &
                        regs_arr(5)(7 downto 0);
    return si57x_regs;
  end function;

  function f_encode_si57x_regs(si57x_regs: t_si57x_pll_regs) return t_byte_arr is
    variable regs_arr: t_byte_arr(0 to 5);
  begin
    regs_arr(0)(7 downto 5) := si57x_regs.hs_div;
    regs_arr(0)(4 downto 0) := si57x_regs.n1(6 downto 2);
    regs_arr(1)(7 downto 6) := si57x_regs.n1(1 downto 0);
    regs_arr(1)(5 downto 0) := si57x_regs.rfreq(37 downto 32);
    regs_arr(2)(7 downto 0) := si57x_regs.rfreq(31 downto 24);
    regs_arr(3)(7 downto 0) := si57x_regs.rfreq(23 downto 16);
    regs_arr(4)(7 downto 0) := si57x_regs.rfreq(15 downto 8);
    regs_arr(5)(7 downto 0) := si57x_regs.rfreq(7 downto 0);
    return regs_arr;
  end function;

  procedure f_gen_start(signal scl: out std_logic;
                        signal sda: out std_logic;
                        constant scl_period_us: natural := 10) is
  begin
    scl <= '1';
    sda <= '1';
    wait for scl_period_us/2 * 1 us;
    sda <= '0';
    wait for scl_period_us/2 * 1 us;
    scl <= '0';
  end procedure;

  procedure f_gen_stop(signal scl: out std_logic;
                       signal sda: out std_logic;
                       constant scl_period_us: natural := 10) is
  begin
    scl <= '0';
    sda <= '0';
    wait for scl_period_us/2 * 1 us;
    scl <= '1';
    wait for scl_period_us/2 * 1 us;
    sda <= '1';
  end procedure;

  procedure f_write_byte(signal scl: out std_logic;
                         signal sda: out std_logic;
                         data: in std_logic_vector(7 downto 0);
                         constant scl_period_us: natural := 10) is
  begin
    for i in 7 downto 0 loop
      scl <= '0';
      sda <= data(i);
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      wait for scl_period_us/2 * 1 us;
    end loop;
  end procedure;

  procedure f_send_ack(signal scl: out std_logic;
                       signal sda: out std_logic;
                       ack: in boolean;
                       constant scl_period_us: natural := 10) is
  begin
      scl <= '0';
      sda <= '0' when ack = true else '1';
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      wait for scl_period_us/2 * 1 us;
  end procedure;

  procedure f_read_byte(signal scl: out std_logic;
                        signal sda: in std_logic;
                        data: out std_logic_vector(7 downto 0);
                        constant scl_period_us: natural := 10) is
  begin
    for i in 7 downto 0 loop
      scl <= '0';
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      data(i) := sda;
      wait for scl_period_us/2 * 1 us;
    end loop;
  end procedure;

  procedure f_read_ack(signal scl: out std_logic;
                       signal sda: in std_logic;
                       ack: out boolean;
                       constant scl_period_us: natural := 10) is
  begin
      scl <= '0';
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      ack := true when sda = '0' else false;
      wait for scl_period_us/2 * 1 us;
  end procedure;

  procedure f_check_ack(signal scl: out std_logic;
                         signal sda: in std_logic;
                         constant scl_period_us: natural := 10) is
    variable ack: boolean;
  begin
    f_read_ack(scl, sda, ack);
    assert ack = true report "Ack expected from slave, but not received!"
      severity failure;
  end procedure;

  procedure f_read_regs(signal scl: out std_logic;
                        signal sda_i: in std_logic;
                        signal sda_o: out std_logic;
                        i2c_slv_addr: std_logic_vector(6 downto 0);
                        reg_addr: in natural;
                        bytes_to_read: in natural;
                        data_arr: out t_byte_arr;
                        constant scl_period_us: natural := 10) is
  begin
    f_gen_start(scl, sda_o);
    f_write_byte(scl, sda_o, i2c_slv_addr & "0");

    -- Check if ack is received
    f_check_ack(scl, sda_i);

    f_write_byte(scl, sda_o, std_logic_vector(to_unsigned(reg_addr, 8)));

    -- Check if ack is received
    f_check_ack(scl, sda_i);

    -- Generate restart, start a master read transaction
    f_gen_start(scl, sda_o);
    f_write_byte(scl, sda_o, i2c_slv_addr & "1");

    -- Check if ack is received
    f_check_ack(scl, sda_i);

    -- Read all bytes
    for i in 0 to bytes_to_read-1 loop
      f_read_byte(scl, sda_i, data_arr(i));

      -- Send a NAK if this is the last byte
      if i = bytes_to_read-1 then
        f_send_ack(scl, sda_o, false);
      else
        f_send_ack(scl, sda_o, true);
      end if;
    end loop;

    -- Finish I2C transaction
    f_gen_stop(scl, sda_o);
  end procedure;

  procedure f_write_regs(signal scl: out std_logic;
                         signal sda_i: in std_logic;
                         signal sda_o: out std_logic;
                         i2c_slv_addr: std_logic_vector(6 downto 0);
                         reg_addr: in natural;
                         bytes_to_write: in natural;
                         data_arr: in t_byte_arr;
                         constant scl_period_us: natural := 10) is
  begin
    f_gen_start(scl, sda_o);
    f_write_byte(scl, sda_o, i2c_slv_addr & "0");
    f_check_ack(scl, sda_i);
    f_write_byte(scl, sda_o, std_logic_vector(to_unsigned(reg_addr, 8)));
    f_check_ack(scl, sda_i);
    for i in 0 to bytes_to_write-1 loop
      f_write_byte(scl, sda_o, data_arr(i));
      f_check_ack(scl, sda_i);
    end loop;
    f_gen_stop(scl, sda_o);
  end procedure;

  procedure f_check_freq(desired_freq: in real;
                         out_freq: in real;
                         constant tolerance: real := 1.0e-7) is
    variable err: real;
  begin
    err := abs(1.0 - desired_freq/out_freq);
    assert err < tolerance
      report "Frequency outside tolerance! Desired frequency = " & to_string(desired_freq) &
      " Hz, output frequency = " & to_string(out_freq) & " Hz, relative error = " &
      to_string(err) & ", tolerace = " & to_string(tolerance) severity failure;
  end procedure;

  signal clk: std_logic := '0';
  signal rst_n: std_logic := '0';
  signal scl: std_logic := '1';
  signal sda_i: std_logic := '1';
  signal sda_o: std_logic;
  signal sda_oe: std_logic;
  signal si57x_regs_o: t_si57x_pll_regs;
  signal freq: real;
begin
  clk <= not(clk) after 100 ns;
  cmp_si57x_model: entity work.si57x_model
    generic map (
      g_I2C_SLAVE_ADDR => si57x_i2c_addr,
      g_INTERNAL_XTAL_FREQ_HZ => 114.285e6,
      g_STARTUP_FREQ_HZ => 100.0e6
    )
    port map (
      clk_i => clk,
      rst_n_i => rst_n,
      scl_i => scl,
      sda_i => sda_i,
      sda_o => sda_o,
      sda_oe => sda_oe,
      hs_div_o => si57x_regs_o.hs_div,
      n1_o => si57x_regs_o.n1,
      rfreq_o => si57x_regs_o.rfreq,
      freq_o => freq
    );

  process
    variable si57x_data_arr: t_byte_arr(0 to 5);
    variable si57x_reg_new_cfg, si57x_reg_start_cfg: t_si57x_pll_regs;
  begin
    wait for 200 ns;
    rst_n <= '1';
    wait for 200 ns;
    f_read_regs(scl, sda_o, sda_i, si57x_i2c_addr, 7, 6, si57x_data_arr);
    si57x_reg_start_cfg := f_decode_si57x_regs(si57x_data_arr);
    assert si57x_regs_o = si57x_reg_start_cfg
      report "Si57x registers read via I2C don't match the exposed values!" severity failure;

    -- Write new frequency (50 MHz)
    si57x_reg_new_cfg.rfreq := "00" & x"2d8012a30";
    si57x_reg_new_cfg.hs_div := "000";
    si57x_reg_new_cfg.n1 := "0011001";
    si57x_data_arr := f_encode_si57x_regs(si57x_reg_new_cfg);
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 7, 6, si57x_data_arr);
    assert si57x_regs_o = si57x_reg_new_cfg
      report "Si57x registers written via I2C don't match the exposed values!" severity failure;
    f_check_freq(50.0e6, freq);

    -- Restore startup registers
    si57x_data_arr(0) := x"01";
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 135, 1, si57x_data_arr);
    assert si57x_regs_o = si57x_reg_start_cfg
      report "Si57x registers not restored to the original values!" severity failure;
    f_check_freq(100.0e6, freq);

    -- Freeze DCO
    si57x_data_arr(0) := x"10";
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 137, 1, si57x_data_arr);

    -- Write new frequency (148 MHz)
    si57x_reg_new_cfg.rfreq := "00" & x"2e9ecb6a6";
    si57x_reg_new_cfg.hs_div := "101";
    si57x_reg_new_cfg.n1 := "0000011";
    si57x_data_arr := f_encode_si57x_regs(si57x_reg_new_cfg);
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 7, 6, si57x_data_arr);
    assert si57x_regs_o = si57x_reg_new_cfg
      report "Si57x registers written via I2C don't match the exposed values!" severity failure;
    -- Frequency should be kept the same
    f_check_freq(100.0e6, freq);

    -- Unfreeze DCO
    si57x_data_arr(0) := x"00";
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 137, 1, si57x_data_arr);

    -- Frequency should not be updated yet
    f_check_freq(100.0e6, freq);

    -- Apply the new frequency
    si57x_data_arr(0) := x"40";
    f_write_regs(scl, sda_o, sda_i, si57x_i2c_addr, 135, 1, si57x_data_arr);

    -- Frequency should be updated
    f_check_freq(148.0e6, freq);
    wait for 200 ns;
    std.env.finish;
  end process;
end architecture;
