-------------------------------------------------------------------------------
-- Title      : Si57x simulation model
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Simulation
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: This is a simualtion model for the Si57x programmable
--              oscilator, it provides an slave I2C interface that mimics the
--              register read and write behavior of the IC. Registers RFREQ, N1
--              and HSDIV are exposed to permit checking if the data written
--              via I2C matches. The *_7PPM registers currently do nothing.
--              Freeze M, FreezeVCADC commands are not implemented.
--              RST_REG (reset the oscillator and I2C interface), RECALL
--              (reload calibrated startup registers), Freeze DCO (don't update
--              the output frequency, useful to make frequency updates atomic),
--              NewFreq (apply the new frequency) commands are supported.
-------------------------------------------------------------------------------
-- Copyright (c) 2024 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2024-05-20  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.ifc_common_pkg.all;

entity si57x_model is
  generic (
    -- Internal crystal frequency, used to compute the output frequency
    g_INTERNAL_XTAL_FREQ_HZ: real := 114.285e6;

    -- Startup output frequency, used to compute startup registers values
    -- together with g_INTERNAL_XTAL_FREQ_HZ
    g_STARTUP_FREQ_HZ: real := 100.0e6;

    -- I2C 7 bits slave address
    g_I2C_SLAVE_ADDR: std_logic_vector(6 downto 0) := "1010101"
  );
  port (
    -- Clock input, must be at least 16x scl_i frequency
    clk_i: in std_logic;

    -- Sychronous reset, active low
    rst_n_i: in std_logic;

    -- I2C SCL input
    scl_i: in std_logic;

    -- I2C SDA input
    sda_i: in std_logic;

    -- I2C SDA output
    sda_o: out std_logic;

    -- I2C SDA output enable
    sda_oe: out std_logic;

    -- Si57x HSDIV register value
    hs_div_o: out std_logic_vector(2 downto 0);

    -- Si57x N1 register value
    n1_o: out std_logic_vector(6 downto 0);

    -- Si57x RFREQ register value
    rfreq_o: out std_logic_vector(37 downto 0);

    -- Effective frequency output in Hz
    freq_o: out real
  );
end si57x_model;

architecture rtl of si57x_model is
  type t_si57x_state is (IDLE, FIRST_BYTE, REMAINING_BYTES);

  type t_byte_arr is array (integer range <>) of std_logic_vector(7 downto 0);

  type t_si57x_reg_bytes is record
    pll_reg_arr: t_byte_arr(7 to 18);
    rst_freeze_mem_ctrl_reg: std_logic_vector(7 downto 0);
    freeze_dco_reg: std_logic_vector(7 downto 0);
  end record;

  type t_si57x_regs is record
    hs_div: unsigned(2 downto 0);
    n1: unsigned(6 downto 0);
    rfreq: unsigned(37 downto 0);
    rst_reg: std_logic;
    new_freq: std_logic;
    freeze_m: std_logic;
    freeze_vcadc: std_logic;
    freeze_dco: std_logic;
    recall: std_logic;
  end record;

  function f_decode_si57x_bytes(reg_bytes: t_si57x_reg_bytes) return t_si57x_regs is
    variable si57x_regs: t_si57x_regs;
    variable n1: std_logic_vector(6 downto 0);
    variable rfreq: std_logic_vector(37 downto 0);
  begin
    si57x_regs.hs_div := unsigned(reg_bytes.pll_reg_arr(7)(7 downto 5));
    n1 := reg_bytes.pll_reg_arr(7)(4 downto 0) &
          reg_bytes.pll_reg_arr(8)(7 downto 6);
    si57x_regs.n1 := unsigned(n1);
    rfreq := reg_bytes.pll_reg_arr(8)(5 downto 0) &
             reg_bytes.pll_reg_arr(9)(7 downto 0) &
             reg_bytes.pll_reg_arr(10)(7 downto 0) &
             reg_bytes.pll_reg_arr(11)(7 downto 0) &
             reg_bytes.pll_reg_arr(12)(7 downto 0);
    si57x_regs.rfreq := unsigned(rfreq);
    si57x_regs.rst_reg := reg_bytes.rst_freeze_mem_ctrl_reg(7);
    si57x_regs.new_freq := reg_bytes.rst_freeze_mem_ctrl_reg(6);
    si57x_regs.freeze_m := reg_bytes.rst_freeze_mem_ctrl_reg(5);
    si57x_regs.freeze_vcadc := reg_bytes.rst_freeze_mem_ctrl_reg(4);
    si57x_regs.recall := reg_bytes.rst_freeze_mem_ctrl_reg(0);
    si57x_regs.freeze_dco := reg_bytes.freeze_dco_reg(4);
    return si57x_regs;
  end function;

  function f_encode_si57x_bytes(regs: t_si57x_regs) return t_si57x_reg_bytes is
    variable reg_bytes: t_si57x_reg_bytes;
  begin
    reg_bytes.pll_reg_arr(7)(7 downto 5) := std_logic_vector(regs.hs_div);
    reg_bytes.pll_reg_arr(7)(4 downto 0) := std_logic_vector(regs.n1(6 downto 2));
    reg_bytes.pll_reg_arr(8)(7 downto 6) := std_logic_vector(regs.n1(1 downto 0));

    reg_bytes.pll_reg_arr(8)(5 downto 0) := std_logic_vector(regs.rfreq(37 downto 32));
    reg_bytes.pll_reg_arr(9)(7 downto 0) := std_logic_vector(regs.rfreq(31 downto 24));
    reg_bytes.pll_reg_arr(10)(7 downto 0) := std_logic_vector(regs.rfreq(23 downto 16));
    reg_bytes.pll_reg_arr(11)(7 downto 0) := std_logic_vector(regs.rfreq(15 downto 8));
    reg_bytes.pll_reg_arr(12)(7 downto 0) := std_logic_vector(regs.rfreq(7 downto 0));

    reg_bytes.rst_freeze_mem_ctrl_reg := (others => '0');
    reg_bytes.rst_freeze_mem_ctrl_reg(7) := regs.rst_reg;
    reg_bytes.rst_freeze_mem_ctrl_reg(6) := regs.new_freq;
    reg_bytes.rst_freeze_mem_ctrl_reg(5) := regs.freeze_m;
    reg_bytes.rst_freeze_mem_ctrl_reg(4) := regs.freeze_vcadc;
    reg_bytes.rst_freeze_mem_ctrl_reg(0) := regs.recall;

    reg_bytes.freeze_dco_reg := (others => '0');
    reg_bytes.freeze_dco_reg(4) := regs.freeze_dco;
    return reg_bytes;
  end function;

  -- Compute the output frequency from internal registers
  function f_calc_fout(pll_regs: t_si57x_regs) return real is
    variable v_eff_rfreq, v_eff_hs_div: real;
    variable v_eff_n1: natural;
  begin
    v_eff_rfreq := real(to_integer(pll_regs.rfreq(30 downto 0))) +
                   real(to_integer(pll_regs.rfreq(37 downto 31))) * 2.0**31;
    v_eff_hs_div := real(to_integer(pll_regs.hs_div) + 4);
    v_eff_n1 := to_integer(pll_regs.n1) + 1;
    if v_eff_n1 > 1 and (v_eff_n1 mod 2) = 1 then
      v_eff_n1 := v_eff_n1 + 1;
    end if;
    return (g_INTERNAL_XTAL_FREQ_HZ * v_eff_rfreq * 2.0**(-28)) / (real(v_eff_n1) * v_eff_hs_div);
  end function;

  -- Calculate the best register values that aproximates a given frequency
  function f_calc_pll_regs(freq: real; rst_ctrl_regs: boolean := false) return t_si57x_regs is
    constant c_hsdivs: integer_vector(0 to 5) := (11, 9, 7, 6, 5, 4);
    variable v_best_freq_err: real := 1.0e9;
    variable v_freq_err_now: real := 1.0e9;
    variable v_rfreq_real: real;
    variable v_fdco: real;
    variable v_rfreq_int_tmp: natural;
    variable v_best_si57x_regs: t_si57x_regs;
  begin
    for hs_idx in c_hsdivs'range loop
      for n1 in 1 to 128 loop
        if (n1 mod 2) = 0 or n1 = 1 then
          v_rfreq_real := (freq * real(c_hsdivs(hs_idx)) * real(n1) * 2.0**28) / g_INTERNAL_XTAL_FREQ_HZ;
          v_fdco := v_rfreq_real * g_INTERNAL_XTAL_FREQ_HZ * 2.0**(-28);
          -- The internal digital controlled oscillator frequency should
          -- be between 4.85 GHz and 5.67 GHz
          if v_fdco > 4.85e9 and v_fdco < 5.67e9 then
            v_freq_err_now := abs(freq - (v_fdco / (real(c_hsdivs(hs_idx)) * real(n1))));
            if (v_freq_err_now < v_best_freq_err) then
              v_freq_err_now := v_best_freq_err;
              v_best_si57x_regs.n1 := to_unsigned(n1 - 1, 7);
              v_best_si57x_regs.hs_div := to_unsigned(c_hsdivs(hs_idx) - 4, 3);
              -- We can't convert v_rfreq_real to integer directly, because
              -- VHDL integers are limited to 2^31 - 1, so we convert it in
              -- two steps, the 37 to 7 bit slice first, then the remaining
              -- last 7 bits later
              v_rfreq_int_tmp := integer(v_rfreq_real * 2.0**(-7));
              v_best_si57x_regs.rfreq(37 downto 7) := to_unsigned(v_rfreq_int_tmp, 31);
              v_rfreq_int_tmp := integer(v_rfreq_real - real(v_rfreq_int_tmp) * 2.0**(7));
              v_best_si57x_regs.rfreq(6 downto 0) := to_unsigned(v_rfreq_int_tmp, 7);
            end if;
          end if;
        end if;
      end loop;
    end loop;
    if rst_ctrl_regs then
      v_best_si57x_regs.rst_reg := '0';
      v_best_si57x_regs.new_freq := '0';
      v_best_si57x_regs.freeze_m := '0';
      v_best_si57x_regs.freeze_vcadc := '0';
      v_best_si57x_regs.recall := '0';
      v_best_si57x_regs.freeze_dco := '0';
    end if;
    return v_best_si57x_regs;
  end function;

  -- Translate addresses to fields in a t_si57x_reg_bytes record and
  -- write data to si57x_regs
  procedure f_write_si57x_regs(reg_addr: in integer;
                               data: in std_logic_vector(7 downto 0);
                               signal si57x_regs: out t_si57x_reg_bytes) is
  begin
    if reg_addr >= 7 and reg_addr <= 18 then
      si57x_regs.pll_reg_arr(reg_addr) <= data;
    elsif reg_addr = 135 then
      si57x_regs.rst_freeze_mem_ctrl_reg <= data;
    elsif reg_addr = 137 then
      si57x_regs.freeze_dco_reg <= data;
    else
      report "Register address '" & to_string(reg_addr) &  "' out of rage"
        severity warning;
    end if;
  end procedure;

  -- Translate addresses to fields in a t_si57x_reg_bytes record and
  -- returns the register value
  function f_read_si57x_regs(reg_addr: integer;
                             si57x_regs: t_si57x_reg_bytes) return std_logic_vector is
  begin
    if reg_addr >= 7 and reg_addr <= 18 then
      return si57x_regs.pll_reg_arr(reg_addr);
    elsif reg_addr = 135 then
      return si57x_regs.rst_freeze_mem_ctrl_reg;
    elsif reg_addr = 137 then
      return si57x_regs.freeze_dco_reg;
    else
      report "Register address '" & to_string(reg_addr) &  "' out of rage"
        severity warning;
    end if;
  end function;

  constant c_si57x_regs_startup: t_si57x_regs := f_calc_pll_regs(g_STARTUP_FREQ_HZ, true);
  signal si57x_reg_bytes: t_si57x_reg_bytes := f_encode_si57x_bytes(c_si57x_regs_startup);
  signal si57x_regs: t_si57x_regs := c_si57x_regs_startup;
  signal freq: real := f_calc_fout(c_si57x_regs_startup);
  signal data_from_master, data_to_master: std_logic_vector(7 downto 0);
  signal data_to_master_rq, data_from_master_valid: std_logic;
  signal start, stop: std_logic;
  signal reg_addr: natural := 0;
  signal si57x_state: t_si57x_state := IDLE;
  signal rst_i2c: std_logic := '1';
begin
  si57x_regs <= f_decode_si57x_bytes(si57x_reg_bytes);
  rfreq_o <= std_logic_vector(si57x_regs.rfreq);
  hs_div_o <= std_logic_vector(si57x_regs.hs_div);
  n1_o <= std_logic_vector(si57x_regs.n1);
  freq_o <= freq;

  cmp_i2c_slave: i2c_slave_iface
    generic map (
      g_I2C_SLAVE_ADDR => g_I2C_SLAVE_ADDR
    )
    port map (
      clk_i   => clk_i,
      -- Reset the I2C slave interface if an external reset is issued
      -- or an write to RST_REG via I2C is issued
      rst_n_i => rst_n_i and rst_i2c,
      scl_i   => scl_i,
      sda_i   => sda_i,
      sda_o   => sda_o,
      sda_oe  => sda_oe,
      data_i  => data_to_master,
      rd_o    => data_to_master_rq,
      wr_o    => data_from_master_valid,
      data_o  => data_from_master,
      start_o => start,
      stop_o  => stop
    );

  process(clk_i)
    variable update_freq: boolean := true;
  begin
    if rising_edge(clk_i) then
      -- Set rst_i2c to '1' so we don't need to manually set it back
      -- to '1' after a RST_REG command is issued
      rst_i2c <= '1';

      if start = '1' then
        -- I2C start condition detected, wait for the first data byte to
        -- be received or for an send request
        si57x_state <= FIRST_BYTE;
      elsif stop = '1' then
        -- I2C stop condition detected, set state machine to idle
        si57x_state <= IDLE;
        reg_addr <= 0;
      else
        case si57x_state is
          when IDLE =>

          when FIRST_BYTE =>
            -- The first byte in ther I2C transaction (after sending the slave
            -- address) can mean different things if this is a master write
            -- (register address) or a master read (register value pointed by
            -- the last write to the register address)
            if data_from_master_valid = '1' then
              reg_addr <= to_integer(unsigned(data_from_master));
              si57x_state <= REMAINING_BYTES;
            elsif data_to_master_rq = '1' then
              data_to_master <= f_read_si57x_regs(reg_addr, si57x_reg_bytes);
              reg_addr <= reg_addr + 1;
            end if;

          when REMAINING_BYTES =>
            -- Remaining bytes, reading / writing, incrementing the internal
            -- register address pointer on each valid byte sent / received
            if data_from_master_valid = '1' then
              f_write_si57x_regs(reg_addr, data_from_master, si57x_reg_bytes);
              reg_addr <= reg_addr + 1;
            elsif data_to_master_rq = '1' then
              data_to_master <= f_read_si57x_regs(reg_addr, si57x_reg_bytes);
              reg_addr <= reg_addr + 1;
            end if;
        end case;
      end if;

      -- This is my understanding of how the Si57x control works:
      --
      -- Before updating the HSDIV, N1 and RFREQ registers, you should write
      -- '1' to the Freeze DCO bit. The frequency output will not change while
      -- writing to these registers in this case;
      --
      -- After you write to the HSDIV, N1 and RFREQ registers, you should
      -- unfreeze the DCO (write '0' to the Freeze DCO bit) and, within a
      -- window of 10 ms max, you should write '1' to the NewFreq bit.
      --
      -- This 10 ms timout is not implemented here, but the requirement of
      -- writing '1' to the NewFreq bit is enforced.

      if si57x_regs.new_freq = '1' and si57x_regs.freeze_dco = '0' then
        si57x_reg_bytes.rst_freeze_mem_ctrl_reg(6) <= '0';
        update_freq := true;
      end if;

      -- If DCO is not froozen, update the output frequency
      if si57x_regs.freeze_dco = '1' then
        update_freq := false;
      end if;

      -- Only update the frequency if conditions are met
      if update_freq then
        freq <= f_calc_fout(si57x_regs);
      end if;

      -- Restore internal registers startup configuration
      if si57x_regs.recall = '1' then
        si57x_reg_bytes <= f_encode_si57x_bytes(c_si57x_regs_startup);
        update_freq := true;
      end if;

      -- Restore internal registers startup configuration and reset the I2C
      -- controller
      if si57x_regs.rst_reg = '1' then
        si57x_reg_bytes <= f_encode_si57x_bytes(c_si57x_regs_startup);
        update_freq := true;
        rst_i2c <= '0';
      end if;

    -- TODO: Freeze M and Freeze VCADC commands
    end if;
  end process;
end architecture;
