-------------------------------------------------------------------------------
-- Title      : I2C slave interface testbench
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
-- 2024-05-16  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ifc_common_pkg.all;

entity i2c_slave_iface_tb is
end i2c_slave_iface_tb;

architecture tb of i2c_slave_iface_tb is
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
                        signal data: out std_logic_vector(7 downto 0);
                        constant scl_period_us: natural := 10) is
  begin
    for i in 7 downto 0 loop
      scl <= '0';
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      data(i) <= sda;
      wait for scl_period_us/2 * 1 us;
    end loop;
  end procedure;

  procedure f_read_ack(signal scl: out std_logic;
                       signal sda: in std_logic;
                       signal ack: out boolean;
                       constant scl_period_us: natural := 10) is
  begin
      scl <= '0';
      wait for scl_period_us/2 * 1 us;
      scl <= '1';
      ack <= true when sda = '0' else false;
      wait for scl_period_us/2 * 1 us;
  end procedure;

  signal clk: std_logic := '0';
  signal sda_i: std_logic := '1';
  signal sda_o: std_logic := '1';
  signal scl: std_logic := '1';
  signal data_i: std_logic_vector(7 downto 0) := (others => '0');
  signal rd: std_logic;
  signal data_o: std_logic_vector(7 downto 0) := (others => '0');
  signal wr: std_logic;
  signal sda_oe: std_logic;
  signal rst_n: std_logic := '0';
  signal ack: boolean := false;
  signal read_data: std_logic_vector(7 downto 0) := (others => '0');
  signal data_sampled : std_logic_vector(7 downto 0) := (others => '0');
  signal start: std_logic;
  signal stop: std_logic;
begin
  clk <= not(clk) after 100 ns;

  cmp_i2c_slave: i2c_slave_iface
    generic map (
      g_I2C_SLAVE_ADDR => "1010000"
    )
    port map (
      clk_i   => clk,
      rst_n_i => rst_n,
      scl_i   => scl,
      sda_i   => sda_i,
      sda_o   => sda_o,
      sda_oe  => sda_oe,
      data_i  => data_i,
      rd_o    => rd,
      wr_o    => wr,
      data_o  => data_o,
      start_o => start,
      stop_o  => stop
    );

  process
  begin
    wait for 200 ns;
    rst_n <= '1';

    -- Send a different I2C address, expects an NACK
    f_gen_start(scl, sda_i);
    f_write_byte(scl, sda_i, "10110000");
    f_read_ack(scl, sda_o, ack);
    assert ack = false report "Different address sent, expected a NACK, got an ACK!"
      severity failure;
    f_gen_stop(scl, sda_i);

    -- Start a master write (slave read) transaction
    f_gen_start(scl, sda_i);
    f_write_byte(scl, sda_i, "10100000");
    f_read_ack(scl, sda_o, ack);
    assert ack report "Expected an ACK, got an NACK!"
      severity failure;

    -- Send data to slave
    f_write_byte(scl, sda_i, x"A5");
    f_read_ack(scl, sda_o, ack);
    assert ack report "Expected an ACK, got an NACK!"
      severity failure;
    assert data_sampled = x"A5" report "Expected 0xA5, got 0x" & to_hstring(data_sampled)
      severity failure;

    -- Send a restart (master read, slave write)
    f_gen_start(scl, sda_i);
    f_write_byte(scl, sda_i, "10100001");
    f_read_ack(scl, sda_o, ack);
    assert ack report "Expected an ACK, got an NACK!"
      severity failure;

    -- Read data from slave
    data_i <= x"B9";
    f_read_byte(scl, sda_o, read_data);
    assert data_i = read_data report "Expected 0x" & to_hstring(data_i) &
      ", got 0x" & to_hstring(read_data)
      severity failure;

    -- Master send a NACK and STOP (last byte)
    f_send_ack(scl, sda_i, false);
    f_gen_stop(scl, sda_i);
    wait for 1 us;
    std.env.finish;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      -- Read data_o only when data_o is valid
      if wr = '1' then
        data_sampled <= data_o;
      end if;
    end if;
  end process;

end architecture;
