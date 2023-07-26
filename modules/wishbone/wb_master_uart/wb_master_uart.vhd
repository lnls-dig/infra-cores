-------------------------------------------------------------------------------
-- Title      : Wishbone master interface controlled via UART
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero <augusto.fraga@lnls.br>
-- Platform   : FPGA-generic
-- Standard   : VHDL 93
-------------------------------------------------------------------------------
-- Description: Expose an wishbone master interface via UART using simple text
--              commands.
--              Protocol:
--              - Read
--                - Command: "R00001FF000\n" (read one word from address
--                  0x00001FF0, the last byte represents the number of words
--                  to be read plus 1)
--                - Response: "O00007300\n" (data read is 0x00007300), "E\n"
--                  if an error occurred or "T\n" if a timeout has occurred
--                - Command: "R00001FF002\n"
--                - Response: "O000073000000770000008300\n" (data read is
--                  0x00007300 0x00007700 0x00008300)
--              - Write:
--                - Command: "W00001A002E000000\n" (write 0x2E000000 to address
--                  0x00001A00)
--                - Response: "O\n" (ok), "E\n" if an error occurred or "T\n"
--                  if an timeout has occurred
--
--              It doesn't have configurable granularity and address / data
--              size. It also doesn't support byte access, only word access.
--
--              Notes:
--              - The m_wb_stall_i signal is ignored because of the surprising
--                behavior of xwb_sdb_crossbar always keeping it at '1' and
--                only changing it to '0' if both m_wb_cyc_o and m_wb_stb_o are
--                set '1'. I don't know if this is compliant with the Wishbone
--                specification, but I had no alternative other than only
--                listen for ack, err and rty signals;
--              - An timeout will occurr if no ack, err or rty signals are set
--                to '1' 255 cyles after setting m_wb_cyc_o and m_wb_stb_o to
--                '1'.
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2023-07-25  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;

entity wb_master_uart is
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
    m_wb_adr_o:      out std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
    m_wb_sel_o:      out std_logic_vector(c_wishbone_data_width/8-1 downto 0) := (others => '0');
    m_wb_we_o:       out std_logic := '0';
    m_wb_dat_o:      out std_logic_vector(c_wishbone_data_width-1 downto 0) := (others => '0');
    m_wb_dat_i:      in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    m_wb_cyc_o:      out std_logic := '0';
    m_wb_stb_o:      out std_logic := '0';
    m_wb_ack_i:      in  std_logic;
    m_wb_err_i:      in  std_logic;
    m_wb_stall_i:    in  std_logic;
    m_wb_rty_i:      in  std_logic
  );
end entity wb_master_uart;

architecture arch of wb_master_uart is
  type t_wb_uart_state is (
    IDLE,
    READING_READ_ADDR,
    WAIT_READ_DATA,
    SENDING_READ_DATA,
    READING_WRITE_ADDR_DATA,
    WAIT_WRITE_DATA,
    SENDING_WRITE_OK,
    SENDING_ERROR,
    SENDING_TIMEOUT,
    INVALID_CMD_WAIT_LINEFEED
  );

  type t_wb_transaction_state is (
    IDLE,
    IDLE_ERR,
    IDLE_TIMEOUT,
    START_READ,
    START_WRITE
  );

  -- Check if the character is a valid hexadecimal digit
  function f_check_hex_char(hex_char: std_logic_vector(7 downto 0))
    return boolean is
  begin
    if unsigned(hex_char) >= x"30" and unsigned(hex_char) <= x"39" then
      return true;
    elsif unsigned(hex_char) >= x"41" and unsigned(hex_char) <= x"46" then
      return true;
    elsif unsigned(hex_char) >= x"61" and unsigned(hex_char) <= x"66" then
      return true;
    else
      return false;
    end if;
  end function;

  -- Convert one hexadecimal ascii character [0-9a-fA-F] to its binary
  -- representation
  function f_hex_char_to_nibble(hex_char: std_logic_vector(7 downto 0))
    return unsigned is
  begin
    if unsigned(hex_char) >= x"30" and unsigned(hex_char) <= x"39" then
      return unsigned(hex_char(3 downto 0));
    else
      -- Assume that any characters that are not numbers from 0 to 9
      -- are in the [a-fA-F] range (i.e. don't check for invalid hex
      -- characters)
      return unsigned(hex_char(3 downto 0)) + 9;
    end if;
  end function;

  function f_hex_char_to_nibble(hex_char: std_logic_vector(7 downto 0))
    return std_logic_vector is
    variable nibble: unsigned(3 downto 0);
  begin
    nibble := f_hex_char_to_nibble(hex_char);
    return std_logic_vector(nibble);
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

  signal tx_data:       std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy:       std_logic;
  signal tx_start:      std_logic := '0';
  signal rx_data:       std_logic_vector(7 downto 0);
  signal rx_data_valid: std_logic;
  signal wb_uart_sts:   t_wb_uart_state := IDLE;
  signal wb_trans_sts:  t_wb_transaction_state := IDLE;
  signal char_cnt:      natural range 0 to 32 := 0;
  signal word_cnt:      unsigned(7 downto 0) := (others => '0');
  signal wb_data:       std_logic_vector(c_wishbone_data_width-1 downto 0) := (others => '0');
  signal wb_addr:       std_logic_vector(c_wishbone_address_width-1 downto 0) := (others => '0');
  signal timeout_cnt:   unsigned(7 downto 0);
begin
    uart_inst: entity work.uart
    port map (
      rst_n_i => rst_n_i,
      clk_i => clk_i,
      clk_div_i => clk_div_i,
      tx_data_i => tx_data,
      tx_start_i => tx_start,
      tx_busy_o => tx_busy,
      tx_o => tx_o,
      rx_data_o => rx_data,
      rx_data_valid_o => rx_data_valid,
      rx_i => rx_i
    );

  m_wb_adr_o <= wb_addr;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        m_wb_cyc_o <= '0';
        m_wb_stb_o <= '0';
        m_wb_sel_o <= (others => '0');
        wb_uart_sts <= IDLE;
        wb_trans_sts <= IDLE;
        char_cnt <= 0;
        timeout_cnt <= (others => '0');
        m_wb_sel_o <= (others => '0');
        word_cnt <= (others => '0');
      else
        tx_start <= '0';

        -- Command parsing and execution FSM
        case wb_uart_sts is
          when IDLE =>
            if rx_data_valid = '1' then
              wb_uart_sts <=
                READING_READ_ADDR when rx_data = x"52" else -- 'R'
                READING_WRITE_ADDR_DATA when rx_data = x"57" else -- 'W'
                SENDING_ERROR when rx_data = g_END_LINE_CHAR else -- '\n'
                INVALID_CMD_WAIT_LINEFEED;
            end if;
          when READING_READ_ADDR =>
            if rx_data_valid = '1' then
              if char_cnt >= 0 and char_cnt <= 7 then
                -- Read the starting address
                -- Check if the received character is a valid
                -- hexadecimal digit
                if f_check_hex_char(rx_data) then
                  char_cnt <= char_cnt + 1;
                  wb_addr((31 - 4*char_cnt)
                             downto
                             (28 - 4*char_cnt)) <= f_hex_char_to_nibble(rx_data);
                else
                  if rx_data = g_END_LINE_CHAR then
                    wb_uart_sts <= SENDING_ERROR;
                  else
                    wb_uart_sts <= INVALID_CMD_WAIT_LINEFEED;
                  end if;
                end if;
              elsif char_cnt >= 8 and char_cnt <= 9 then
                -- The last byte represents the number of words to be
                -- read plus 1

                -- Check if the received character is a valid
                -- hexadecimal digit
                if f_check_hex_char(rx_data) then
                  char_cnt <= char_cnt + 1;
                  word_cnt(7 - 4*(char_cnt - 8)
                           downto
                           4 - 4*(char_cnt - 8)) <= f_hex_char_to_nibble(rx_data);

                else
                  if rx_data = g_END_LINE_CHAR then
                    wb_uart_sts <= SENDING_ERROR;
                  else
                    wb_uart_sts <= INVALID_CMD_WAIT_LINEFEED;
                  end if;
                end if;
              else
                -- Expects a line feed and start a wishbone read
                -- sequence, otherwise returns an error
                if rx_data = g_END_LINE_CHAR then
                  wb_uart_sts <= WAIT_READ_DATA;
                  wb_trans_sts <= START_READ;
                else
                  wb_uart_sts <= INVALID_CMD_WAIT_LINEFEED;
                end if;
                char_cnt <= 0;
              end if;
            end if;
          -- Wait until the wishbone transaction is finished, if it
          -- fails, send an error message, if it succeeds, start
          -- sending the read data
          when WAIT_READ_DATA =>
            if wb_trans_sts = IDLE then
              wb_uart_sts <= SENDING_READ_DATA;
            elsif wb_trans_sts = IDLE_ERR then
              wb_uart_sts <= SENDING_ERROR;
              wb_trans_sts <= IDLE;
            elsif wb_trans_sts = IDLE_TIMEOUT then
              wb_uart_sts <= SENDING_TIMEOUT;
              wb_trans_sts <= IDLE;
            end if;
          -- Send the read data as an hexadecimal string starting with
          -- an 'O' to indicate that the command executed successfully
          when SENDING_READ_DATA =>
            if tx_busy = '0' then
              if char_cnt = 0 then
                tx_data <= x"4F";
                tx_start <= '1';
                char_cnt <= 1;
              elsif char_cnt >= 1 and char_cnt <= 8 then
                tx_data <= f_nibble_to_hex_char(
                  wb_data((35 - 4*char_cnt)
                          downto
                          (32 - 4*char_cnt)));
                tx_start <= '1';
                char_cnt <= char_cnt + 1;
              elsif char_cnt >= 9 then
                -- Check if there are more words to be sent
                if word_cnt = x"00" then
                  tx_data <= g_END_LINE_CHAR;
                  tx_start <= '1';
                  wb_uart_sts <= IDLE;
                  char_cnt <= 0;
                else
                  word_cnt <= word_cnt - 1;
                  wb_trans_sts <= START_READ;
                  wb_uart_sts <= WAIT_READ_DATA;
                  -- Set char_cnt to 1 to avoid sending an 'O' again
                  char_cnt <= 1;
                  wb_addr <= std_logic_vector(unsigned(wb_addr) + 4);
                end if;
              end if;
            end if;

          when READING_WRITE_ADDR_DATA =>
            if rx_data_valid = '1' then
              if char_cnt >= 0 and char_cnt <= 15 then
                -- Check if the received character is a valid
                -- hexadecimal digit
                if f_check_hex_char(rx_data) then
                  char_cnt <= char_cnt + 1;
                  if char_cnt >= 0 and char_cnt <= 7 then
                  -- Read and decode address
                    wb_addr((31 - 4*char_cnt)
                               downto
                               (28 - 4*char_cnt)) <= f_hex_char_to_nibble(rx_data);
                  else
                  -- Read and decode data
                    m_wb_dat_o((63 - 4*char_cnt)
                               downto
                               (60 - 4*char_cnt)) <= f_hex_char_to_nibble(rx_data);
                  end if;
                else
                  if rx_data = g_END_LINE_CHAR then
                    wb_uart_sts <= SENDING_ERROR;
                  else
                    wb_uart_sts <= INVALID_CMD_WAIT_LINEFEED;
                  end if;
                end if;
              else
                if rx_data = g_END_LINE_CHAR then
                  wb_uart_sts <= WAIT_WRITE_DATA;
                  wb_trans_sts <= START_WRITE;
                else
                  wb_uart_sts <= INVALID_CMD_WAIT_LINEFEED;
                end if;
                char_cnt <= 0;
              end if;
            end if;

          when WAIT_WRITE_DATA =>
            if wb_trans_sts = IDLE then
              wb_uart_sts <= SENDING_WRITE_OK;
            elsif wb_trans_sts = IDLE_ERR then
              wb_uart_sts <= SENDING_ERROR;
              wb_trans_sts <= IDLE;
            elsif wb_trans_sts = IDLE_TIMEOUT then
              wb_uart_sts <= SENDING_TIMEOUT;
              wb_trans_sts <= IDLE;
            end if;

          when SENDING_WRITE_OK =>
            -- Send "O\n"
            if tx_busy = '0' then
              if char_cnt = 0 then
                tx_data <= x"4F";
                tx_start <= '1';
                char_cnt <= 1;
              elsif char_cnt = 1 then
                tx_data <= g_END_LINE_CHAR;
                tx_start <= '1';
                char_cnt <= 0;
                wb_uart_sts <= IDLE;
              end if;
            end if;

          when INVALID_CMD_WAIT_LINEFEED =>
            -- Wait for a linefeed before sending an error
            if rx_data_valid = '1' and rx_data = g_END_LINE_CHAR then
              wb_uart_sts <= SENDING_ERROR;
            end if;

          when SENDING_ERROR =>
            -- Send "E\n"
            if tx_busy = '0' then
              if char_cnt = 0 then
                tx_data <= x"45";
                tx_start <= '1';
                char_cnt <= 1;
              elsif char_cnt = 1 then
                tx_data <= g_END_LINE_CHAR;
                tx_start <= '1';
                char_cnt <= 0;
                wb_uart_sts <= IDLE;
              end if;
            end if;

          when SENDING_TIMEOUT =>
            -- Send "T\n"
            if tx_busy = '0' then
              if char_cnt = 0 then
                tx_data <= x"54";
                tx_start <= '1';
                char_cnt <= 1;
              elsif char_cnt = 1 then
                tx_data <= g_END_LINE_CHAR;
                tx_start <= '1';
                char_cnt <= 0;
                wb_uart_sts <= IDLE;
              end if;
            end if;
        end case;

        -- Wishbone transaction FSM
        case wb_trans_sts is
          -- Do nothing while idle, wb_trans_sts should be set to
          -- START_READ or START_WRITE to start a new wishbone
          -- transaction
          when IDLE =>
          when IDLE_ERR =>
          when IDLE_TIMEOUT =>

          when START_READ =>
            -- Start a data read transaction
            m_wb_cyc_o <= '1';
            m_wb_stb_o <= '1';
            m_wb_sel_o <= (others => '1');
            if m_wb_ack_i = '1' then
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE;
              wb_data <= m_wb_dat_i;
              timeout_cnt <= (others => '0');
            elsif m_wb_err_i = '1' or m_wb_rty_i = '1' then
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE_ERR;
              timeout_cnt <= (others => '0');
            elsif timeout_cnt = to_unsigned(255, 8) then
              -- If 255 cycles has passed without an response (error,
              -- retry or ack), abort the transaction and go to the
              -- IDLE_TIMEOUT state
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE_TIMEOUT;
              timeout_cnt <= (others => '0');
            else
              timeout_cnt <= timeout_cnt + 1;
            end if;

          when START_WRITE =>
            -- Start a data write transaction
            m_wb_cyc_o <= '1';
            m_wb_stb_o <= '1';
            m_wb_we_o <= '1';
            m_wb_sel_o <= (others => '1');
            if m_wb_ack_i = '1' then
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_we_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE;
              timeout_cnt <= (others => '0');
            elsif m_wb_err_i = '1' or m_wb_rty_i = '1' then
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_we_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE_ERR;
              timeout_cnt <= (others => '0');
            elsif timeout_cnt = to_unsigned(255, 8) then
              -- If 255 cycles has passed without an response (error,
              -- retry or ack), abort the transaction and go to the
              -- IDLE_TIMEOUT state
              m_wb_cyc_o <= '0';
              m_wb_stb_o <= '0';
              m_wb_we_o <= '0';
              m_wb_sel_o <= (others => '0');
              wb_trans_sts <= IDLE_TIMEOUT;
              timeout_cnt <= (others => '0');
            else
              timeout_cnt <= timeout_cnt + 1;
            end if;
        end case;
      end if;
    end if;
  end process;

end architecture;
