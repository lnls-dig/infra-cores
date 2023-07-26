------------------------------------------------------------------------------
-- Title      : Wishbone master UART testbench
------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Created    : 2023-07-26
-- Platform   : Simulation
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: Send text commands via UART to write to a Wishbone memory
--              and read it back
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2023-07-26  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.uniform;
use ieee.math_real.floor;

library work;
use work.wishbone_pkg.all;
use work.ifc_wishbone_pkg.all;

entity wb_master_uart_tb is
end entity wb_master_uart_tb;

architecture simu of wb_master_uart_tb is
  type t_cmd_status is (OK_DATA, OK_EMPTY, CMD_ERR, CMD_TIMEOUT, PARSING_ERR);
  type t_data_arr is array (natural range <>) of std_logic_vector(c_wishbone_data_width-1 downto 0);

  constant c_clk_freq:  natural := 160_000_000;
  constant c_baudrate:  natural := 10_000_000;
  constant c_clk_div:   unsigned (15 downto 0) := to_unsigned(c_clk_freq/c_baudrate - 1, 16);

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

  procedure f_write_uart(data:        in  std_logic_vector(7 downto 0);
                         baud:        in  integer;
                         signal tx:   out std_logic) is
  begin
    for bit_cnt in 0 to 9 loop
      if bit_cnt = 0 then
        tx <= '0';
      elsif bit_cnt >= 1 and bit_cnt <= 8 then
        tx <= data(bit_cnt-1);
      else
        tx <= '1';
      end if;
      wait for (1.0 / real(baud)) * 1.0 sec;
    end loop;
  end procedure;

  procedure f_read_uart(data:        out std_logic_vector(7 downto 0);
                        baud:        in  integer;
                        signal rx:   in  std_logic) is
    variable data_tmp: std_logic_vector(7 downto 0) := (others => '0');
  begin
    -- Detect start bit
    wait until rx = '0';
    -- Sync to the middle of the first data bit
    wait for (1.5 / real(baud)) * 1.0 sec;
    for bit_cnt in 0 to 7 loop
      data_tmp(bit_cnt) := rx;
      wait for (1.0 / real(baud)) * 1.0 sec;
    end loop;
    data := data_tmp;
  end procedure;

  -- Convert one hexadecimal ascii character [0-9a-fA-F] to its binary
  -- representation
  function f_hex_char_to_nibble(hex_char: std_logic_vector(7 downto 0))
    return std_logic_vector is
  begin
    -- If numeric, just take the lower 4 bits
    if unsigned(hex_char) >= x"30" and unsigned(hex_char) <= x"39" then
      return hex_char(3 downto 0);
    -- If [a-fA-F], take the lower 4 bits and sum 9
    elsif (unsigned(hex_char) >= x"41" and unsigned(hex_char) <= x"47") or
      (unsigned(hex_char) >= x"61" and unsigned(hex_char) <= x"67") then
      return std_logic_vector(unsigned(hex_char(3 downto 0)) + 9);
    else
      report "Invalid hexadecimal ascii character: 0x" & to_hex_string(hex_char) severity failure;
    end if;
  end function;

  -- Convert a nibble to its hexadecimal ascii representation (upper
  -- case)
  function f_nibble_to_hex_char(nibble: std_logic_vector(3 downto 0))
    return std_logic_vector is
  begin
    if unsigned(nibble) >= x"0" and unsigned(nibble) <= x"9" then
      return x"3" & nibble;
    else
      return std_logic_vector(unsigned(nibble) - x"A" + x"41");
    end if;
  end function;

  -- Send a data write command via UART
  procedure f_send_write_cmd(addr: in std_logic_vector(c_wishbone_address_width-1 downto 0);
                             data: in std_logic_vector(c_wishbone_data_width-1 downto 0);
                             baud: in integer;
                             signal tx: out std_logic
                             ) is
    variable char_data: std_logic_vector(7 downto 0) := (others => '0');
  begin
    -- Write 'W' character (read command)
    f_write_uart(x"57", baud, tx);
    -- Send each nibble encoded as a hexadecimal character (address)
    for i in (c_wishbone_address_width/4) - 1 downto 0 loop
      char_data := f_nibble_to_hex_char(addr((i*4 + 3) downto i*4));
      f_write_uart(char_data, baud, tx);
    end loop;
    -- Send each nibble encoded as a hexadecimal character (data)
    for i in (c_wishbone_data_width/4) - 1 downto 0 loop
      char_data := f_nibble_to_hex_char(data((i*4 + 3) downto i*4));
      f_write_uart(char_data, baud, tx);
    end loop;
    -- Line feed
    f_write_uart(x"0A", baud, tx);
  end procedure;

  -- Send a data read command via UART
  procedure f_send_read_cmd(addr: in std_logic_vector(c_wishbone_address_width-1 downto 0);
                            baud: in integer;
                            words: in natural range 1 to 256;
                            signal tx: out std_logic
                            ) is
    variable char_data: std_logic_vector(7 downto 0) := (others => '0');
    variable words_arg: std_logic_vector(7 downto 0);
  begin
    -- Write 'R' character (read command)
    f_write_uart(x"52", baud, tx);
    -- Send each nibble encoded as a hexadecimal character
    for i in (c_wishbone_address_width/4) - 1 downto 0 loop
      char_data := f_nibble_to_hex_char(addr((i*4 + 3) downto i*4));
      f_write_uart(char_data, baud, tx);
    end loop;
    -- Last byte represents the number of words to be read minus 1
    words_arg := std_logic_vector(to_unsigned(words - 1, 8));
    char_data := f_nibble_to_hex_char(words_arg(7 downto 4));
    f_write_uart(char_data, baud, tx);
    char_data := f_nibble_to_hex_char(words_arg(3 downto 0));
    f_write_uart(char_data, baud, tx);
    -- Line feed
    f_write_uart(x"0A", baud, tx);
  end procedure;

  procedure f_read_word(signal rx_data:  in  std_logic_vector(7 downto 0);
                        signal rx_event: in  boolean;
                        data:            out std_logic_vector(c_wishbone_data_width-1 downto 0)) is
  begin
    for i in 7 downto 0 loop
      wait until rx_event'event;
      data(((i*4) + 3) downto i*4) := f_hex_char_to_nibble(rx_data);
    end loop;
  end procedure;

  -- Read the and decode command answer
  procedure f_read_cmd_ans(signal rx_data:  in  std_logic_vector(7 downto 0);
                           signal rx_event: in  boolean;
                           data:            out std_logic_vector(c_wishbone_data_width-1 downto 0);
                           status:          out t_cmd_status) is
  begin
    wait until rx_event'event;
    -- Check if the first character os the answer is an 'O' (ok), an
    -- 'E' (error) or something else (invalid)
    if rx_data = x"45" then -- 'E'
      status := CMD_ERR;
    elsif rx_data = x"54" then
      status := CMD_TIMEOUT;
    elsif rx_data = x"4F" then -- 'O'
      wait until rx_event'event;
      -- If an "O\n" is received, inform
      if rx_data = x"0A" then
        status := OK_EMPTY;
      else
        -- Read and convert the hex string to binary
        data(31 downto 28) := f_hex_char_to_nibble(rx_data);
        for i in 6 downto 0 loop
          wait until rx_event'event;
          data(((i*4) + 3) downto i*4) := f_hex_char_to_nibble(rx_data);
        end loop;
        status := OK_DATA;
      end if;
    else
      status := PARSING_ERR;
    end if;

    -- Don't try to consume an extra '\n' if the answer is OK_EMPTY
    if status /= OK_EMPTY then
      wait until rx_event'event;
      -- Check if the last received character is a linefeed '\n'
      if rx_data /= x"0A" then
        status := PARSING_ERR;
      end if;
    end if;
  end procedure;

  signal clk:           std_logic := '0';
  signal rst_n:         std_logic := '0';
  signal tx:            std_logic;
  signal rx:            std_logic := '1';
  signal rx_data:       std_logic_vector(7 downto 0) := (others => '0');
  signal rx_data_event: boolean := false;
  signal m_wb_i:        t_wishbone_master_in;
  signal m_wb_o:        t_wishbone_master_out;
begin

  f_gen_clk(c_clk_freq, clk);

  cmp_xwb_master_uart: xwb_master_uart
    port map (
      clk_i       => clk,
      rst_n_i     => rst_n,
      clk_div_i   => c_clk_div,
      tx_o        => tx,
      rx_i        => rx,
      wb_master_i => m_wb_i,
      wb_master_o => m_wb_o
    );

  cmp_wb_ram: entity work.wb_ram
    port map (
      rst_n_i         => rst_n,
      clk_i           => clk,
      wb_i            => m_wb_o,
      wb_o            => m_wb_i,
      ram_adr_i       => (others => '0'),
      ram_data_rd_i   => '0',
      ram_data_dat_o  => open
    );

  process
    variable cmd_ans_status: t_cmd_status;
    variable data_read: std_logic_vector(c_wishbone_data_width-1 downto 0);
    variable data_written: std_logic_vector(c_wishbone_data_width-1 downto 0);
    variable data_gen_arr: t_data_arr(2047 downto 0);
    variable address: std_logic_vector(c_wishbone_address_width-1 downto 0);
    variable seed1: natural := 5860317;
    variable seed2: natural := 1102456;
    variable rand:  real;
  begin
    f_wait_cycles(clk, 2);
    rst_n <= '1';
    f_wait_cycles(clk, 2);

    -- Send an empty command and check if it produces an error
    f_write_uart(x"0A", c_baudrate, rx);
    f_read_cmd_ans(rx_data, rx_data_event, data_read, cmd_ans_status);
    assert cmd_ans_status = CMD_ERR
        report "Expected cmd_err, got " & to_string(cmd_ans_status) severity failure;

    -- Write 2048 random words
    for i in 0 to 2047 loop
      -- Generate a random 32 bit word
      uniform(seed1, seed2, rand);
      data_written := std_logic_vector(
        to_signed(integer(floor((rand - 0.5) * 4294967296.0)), 32)
      );

      -- Store generated data to compare it later
      data_gen_arr(i) := data_written;

      -- Ignore last two bits (word-aligned access)
      address := std_logic_vector(to_unsigned(i, 30)) & "00";

      -- Write to the wishbone memory
      f_send_write_cmd(address, data_written, c_baudrate, rx);
      f_read_cmd_ans(rx_data, rx_data_event, data_read, cmd_ans_status);
      assert cmd_ans_status = OK_EMPTY
        report "Expected ok_empty, got " & to_string(cmd_ans_status) severity failure;
    end loop;

    -- Check if all words were written correctly
    for i in 0 to 2047 loop
      -- Ignore last two bits (word-aligned access)
      address := std_logic_vector(to_unsigned(i, 30)) & "00";

      -- Read one word from the wishbone memory
      f_send_read_cmd(address, c_baudrate, 1, rx);
      f_read_cmd_ans(rx_data, rx_data_event, data_read, cmd_ans_status);
      assert cmd_ans_status = OK_DATA
        report "Expected ok_data, got " & to_string(cmd_ans_status) severity failure;
      assert data_read = data_gen_arr(i)
        report "Data written differs from data read!" & LF &
        "Read: 0x" & to_hex_string(data_read) & " expected: 0x" & to_hex_string(data_written)
        severity failure;
    end loop;

    -- Multi-word read command
    f_send_read_cmd(x"000000AC", c_baudrate, 256, rx);

    -- Check if the command response begins with an 'O' (ok)
    wait until rx_data_event'event;
    assert rx_data = x"4F"
      report "Expected ok_data, got " & to_hex_string(rx_data) severity failure;

    -- Check if the 256 words match starting from address 0x000000AC
    for i in 43 to 298 loop
      -- Read 8 hexadecimal characters and convert it to 32 bit word
      f_read_word(rx_data, rx_data_event, data_read);
      assert data_read = data_gen_arr(i)
        report "Data written differs from data read!" & LF &
        "Read: 0x" & to_hex_string(data_read) & " expected: 0x" & to_hex_string(data_written)
        severity failure;
    end loop;

    -- After reading all words, expect an linefeed
    wait until rx_data_event'event;
    assert rx_data = x"0A"
      report "Expected linefeed, got " & to_hex_string(rx_data) severity failure;

    -- Extra cycles to help visualizing final register states
    f_wait_cycles(clk, 10);
    std.env.finish;
  end process;

  process
    variable data: std_logic_vector(7 downto 0);
  begin
    f_read_uart(data, c_baudrate, tx);
    rx_data <= data;
    -- Just update this signal to generate a new event
    rx_data_event <= not(rx_data_event);
  end process;

  process
  begin
    wait for 100 ms;
    report "Timeout failure!" severity failure;
  end process;
end architecture simu;
