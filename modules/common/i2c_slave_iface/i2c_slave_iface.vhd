-------------------------------------------------------------------------------
-- Title      : I2C slave interface
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Generic
-- Standard   : VHDL 1993
-------------------------------------------------------------------------------
-- Description: This is a synthesizable I2C slave interface that samples the
--              SDA and SCL lines with the clk_i internal clock. It doesn't
--              checks for master ACK/NACK, can't do clock streching, only
--              supports a single fixed I2C address and answers with an ACK
--              every byte received after the I2C address.
--              Master data is always sampled at the rising edge of SCL, slave
--              data is always written at the SCL falling edge
-------------------------------------------------------------------------------
-- Copyright (c) 2024 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2024-05-15  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.gencores_pkg.all;

entity i2c_slave_iface is
  generic (
    -- 7 bits slave address
    g_I2C_SLAVE_ADDR: std_logic_vector(6 downto 0)
  );
  port (
    -- Synchronous reset (active low)
    rst_n_i  : in std_logic;

    -- Clock input (should be at least 16x the maximum bitrate)
    clk_i    : in std_logic;

    -- I2C SCL input
    scl_i    : in std_logic;

    -- I2C SDA input
    sda_i    : in std_logic;

    -- I2C SDA output
    sda_o    : out std_logic := '1';

    -- I2C SDA output enable
    sda_oe   : out std_logic := '0';

    -- Data input (to be sent to master), non registered, should only be
    -- updated after a read request signal (rd_o) is asserted
    data_i   : in std_logic_vector(7 downto 0);

    -- Data request signal, will be '1' for one clk_i cycle, data should be
    -- available in data_i in the next clk_i cycle
    rd_o     : out std_logic := '0';

    -- Data output (data received from master), should only be sampled when
    -- wr_o is asserted
    data_o   : out std_logic_vector(7 downto 0);

    -- Data available, will be '1' for one clk_i cycle, data_o will have the
    -- data received from master
    wr_o     : out std_logic := '0';

    -- I2C start / restart detected
    start_o  : out std_logic := '0';

    -- I2C stop detected
    stop_o  : out std_logic := '0'
  );
end i2c_slave_iface;

architecture syn of i2c_slave_iface is
  function f_rising_edge_sig(prev: std_logic; now: std_logic) return boolean is
  begin
    if prev = '0' and now = '1' then
      return true;
    else
      return false;
    end if;
  end function;

  function f_falling_edge_sig(prev: std_logic; now: std_logic) return boolean is
  begin
    if prev = '1' and now = '0' then
      return true;
    else
      return false;
    end if;
  end function;

  type i2c_state_t is (IDLE, READING_ADDR, READING_BYTE, WRITING_BYTE, ASSERTING_ACK, DEASSERTING_ACK, READING_ACK, WAIT_LAST_BIT_WRITE);
  signal i2c_state: i2c_state_t := IDLE;
  signal sda_slave_ctrl: boolean := false;
  signal slave_write_mode: boolean := false;
  signal bit_cnt: natural range 0 to 7 := 0;
  signal data: std_logic_vector(7 downto 0) := (others => '0');
  signal scl_sync, sda_sync: std_logic;
  signal scl_sync_prev, sda_sync_prev: std_logic;
begin

  -- Syncronizes SDA and SCL signals to the clk_i clock. It is safe to do this
  -- with an N bits sync register (no acks necessary) because it doesn't matter
  -- if SDA or SCL have a one clk_i cycle delay between them (provided that
  -- clk_i frequency is >> SCL)
  cmp_sync_sda_scl: gc_sync_register
    generic map (
      g_width => 2
    )
    port map (
      clk_i => clk_i,
      rst_n_a_i => rst_n_i,
      d_i(0) => scl_i,
      d_i(1) => sda_i,
      q_o(0) => scl_sync,
      q_o(1) => sda_sync
    );

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      -- Always deassert rd_o and wr_o, so it is not necessary to keep track of
      -- these signals through the state machine
      rd_o <= '0';
      wr_o <= '0';
      start_o <= '0';
      stop_o <= '0';
      if rst_n_i = '0' then
        sda_sync_prev <= '1';
        scl_sync_prev <= '1';
        i2c_state <= IDLE;
        bit_cnt <= 0;
        sda_oe <= '0';
        sda_slave_ctrl <= false;
      else
        -- Update previous sda / scl value (for edge detection)
        sda_sync_prev <= sda_sync;
        scl_sync_prev <= scl_sync;

        -- Detect START and STOP conditions
        if f_falling_edge_sig(sda_sync_prev, sda_sync) and scl_sync = '1' then
          i2c_state <= READING_ADDR;
          bit_cnt <= 0;
          sda_slave_ctrl <= false;
          start_o <= '1';
        elsif f_rising_edge_sig(sda_sync_prev, sda_sync) and scl_sync = '1' then
          i2c_state <= IDLE;
          bit_cnt <= 0;
          sda_slave_ctrl <= false;
          stop_o <= '1';
        end if;

        case i2c_state is
          when IDLE =>
            -- Wait for a start condition

          when READING_ADDR =>
            -- Read the 7 bits slave address and the R/W bit
            data(7 - bit_cnt) <= sda_sync;
            if f_rising_edge_sig(scl_sync_prev, scl_sync) then
              if bit_cnt = 7 then
                if data(7 downto 1) = g_I2C_SLAVE_ADDR then
                  -- Check the R/W bit of the I2C transaction
                  if data(0) = '1' then
                    slave_write_mode <= true;
                  else
                    slave_write_mode <= false;
                  end if;
                  -- If the address matches, send an ACK
                  i2c_state <= ASSERTING_ACK;
                  sda_slave_ctrl <= true;
                else
                  -- If the address doesn't match, go to IDLE
                  i2c_state <= IDLE;
                end if;
                bit_cnt <= 0;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            end if;

          when ASSERTING_ACK =>
            if f_falling_edge_sig(scl_sync_prev, scl_sync) then
              -- Send an ACK
              sda_o <= '0';
              sda_oe <= '1';
              i2c_state <= DEASSERTING_ACK;
              if slave_write_mode then
                -- Request data to be sent to master
                rd_o <= '1';
              end if;
            end if;

          when DEASSERTING_ACK =>
            if f_falling_edge_sig(scl_sync_prev, scl_sync) then
              -- Deassert ACK, if in slave write mode, send the MSB bit and
              -- enters the WRITING_BYTE state, else start reading data from
              -- master
              if slave_write_mode then
                i2c_state <= WRITING_BYTE;
                sda_o <= data_i(7);
                sda_oe <= '1';
                bit_cnt <= 1;
              else
                i2c_state <= READING_BYTE;
                sda_o <= '1';
                sda_oe <= '0';
              end if;
            end if;

          when READING_BYTE =>
            if f_rising_edge_sig(scl_sync_prev, scl_sync) then
              -- Samples the SDA line at the SCL rising edge
              data(7 - bit_cnt) <= sda_sync;
              if bit_cnt = 7 then
                -- All bits received, send an ACK and indicates that new data
                -- is available
                i2c_state <= ASSERTING_ACK;
                bit_cnt <= 0;
                -- This is a bit ugly, but it is necessary otherwise a new
                -- state for writing to data_o would be required
                data_o <= data(7 downto 1) & sda_sync;
                wr_o <= '1';
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            end if;

          when WRITING_BYTE =>
            if f_falling_edge_sig(scl_sync_prev, scl_sync) then
              -- Write each bit from data_i
              sda_oe <= '1';
              sda_o <= data_i(7 - bit_cnt);
              if bit_cnt /= 7 then
                bit_cnt <= bit_cnt + 1;
              else
                bit_cnt <= 0;
                i2c_state <= WAIT_LAST_BIT_WRITE;
              end if;
            end if;

          when WAIT_LAST_BIT_WRITE =>
            -- Wait a SCL falling edge before finishing writing data to master
            if f_falling_edge_sig(scl_sync_prev, scl_sync) then
                i2c_state <= READING_ACK;
                sda_oe <= '0';
                sda_o <= '1';
            end if;

          when READING_ACK =>
            -- Master ACK is ignored here
            if f_rising_edge_sig(scl_sync_prev, scl_sync) then
              -- Request more data to be sent to master
              rd_o <= '1';
              i2c_state <= WRITING_BYTE;
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture syn;
