-------------------------------------------------------------------------------
-- Title      : Si57x controller core
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: This core provides an abstract interface for the Si57x
--              programmable oscillators.
--
--              Supported features:
--              - Writing to HSDIV, N1 and RFREQ;
--              - Obtain the startup values of HSDIV, N1 and RFREQ to be able
--                to calculate the calibrated internal XTAL frequency;
--              - Check for I2C errors (arbitration lost, slave not
--                responding).
--
--              Unsupported features:
--              - VCADC freeze control (for Si571 devices);
--              - Freeze M, to be able to write to RFREQ registers for smooth
--                clock frequency change +- 3500 ppm from center frequency;
--              - Internal reset via RST_REG, though I don't think this is
--                useful anyway.
-------------------------------------------------------------------------------
-- Copyright (c) 2024 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2024-06-04  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity si57x_ctrl is
  generic (
    -- Si57x I2C slave address
    g_SI57X_I2C_ADDR: std_logic_vector(6 downto 0);

    -- Divide the input clock to 4x SCL
    g_SCL_CLK_DIV: natural range 1 to 65536;

    -- Set this true if you are using the Si57x 7PPM variant
    g_SI57X_7PPM_VARIANT: boolean
  );
  port (
    -- Input clock
    clk_i: std_logic;

    -- Synchronous reset, active low
    rst_n_i: std_logic;

    -- Si57x HSDIV value to be written
    hs_div_i: in std_logic_vector(2 downto 0);

    -- Si57x N1 register value to be written
    n1_i: in std_logic_vector(6 downto 0);

    -- Si57x RFREQ register value to be written
    rfreq_i: in std_logic_vector(37 downto 0);

    -- Write registers to the device
    apply_cfg_i: in std_logic;

    -- Indicates if the last configuration written is in sync with the
    -- configuration presented in the inputs hs_div_i, n1_i, rfreq_i
    cfg_in_sync_o: out std_logic;

    -- Obtain the startup register values, this can be used to compute
    -- the internal crystal frequency precisely. WARNING: writing '1'
    -- to this WILL change the output frequency of the Si57x device
    read_startup_regs_i: in std_logic;

    -- Si57x HSDIV startup register value
    hs_div_startup_o: out std_logic_vector(2 downto 0);

    -- Si57x N1 startup register value
    n1_startup_o: out std_logic_vector(6 downto 0);

    -- Si57x RFREQ startup register value
    rfreq_startup_o: out std_logic_vector(37 downto 0);

    -- Startup values read successfuly
    startup_complete_o: out std_logic;

    -- I2C SDA Master input
    sda_i: in std_logic;

    -- I2C SDA Master output
    sda_o: out std_logic;

    -- I2C SDA Master output enable, active high
    sda_oe_o: out std_logic;

    -- I2C SCL Master input
    scl_i: in std_logic;

    -- I2C SCL Master output
    scl_o: out std_logic;

    -- I2C SCL Master output enable, active high
    scl_oe_o: out std_logic;

    -- I2C error detected (no response from slave or I2C busy)
    i2c_err_o: out std_logic;

    -- Core is busy, new commands will be ignored
    busy_o: out std_logic
  );
end entity;

architecture rtl of si57x_ctrl is
  type t_byte_arr is array (integer range <>) of std_logic_vector(7 downto 0);
  type t_si57x_state is (IDLE, WRITE_REGS, READ_REGS, WAIT_READ_REGS, UNFREEZE_DCO, APPLY_NEWFREQ);
  type t_i2c_state is (IDLE, SEND_START_ADDR_WRITE, SEND_START_ADDR_READ, WAIT_SEND_START_ADDR_READ, SEND_REG_ADDR, WRITE_BYTES, READ_BYTES, WAIT_STOP);
  type t_i2c_trans_mode is (WRITE_DATA, READ_DATA);
  signal i2c_start: std_logic;
  signal i2c_stop: std_logic;
  signal i2c_read: std_logic;
  signal i2c_write: std_logic;
  signal i2c_ack_in: std_logic;
  signal i2c_cmd_ack: std_logic;
  signal i2c_ack_out: std_logic;
  signal i2c_busy: std_logic;
  signal i2c_al: std_logic;
  signal i2c_din: std_logic_vector(7 downto 0);
  signal i2c_dout: std_logic_vector(7 downto 0);
  signal scl_oen: std_logic;
  signal sda_oen: std_logic;

  signal i2c_err: std_logic;
  signal si57x_state: t_si57x_state;
  signal i2c_state: t_i2c_state;
  signal i2c_buff: t_byte_arr(0 to 5);
  signal i2c_buff_size: integer range 0 to 6;
  signal i2c_buff_cnt: integer range 0 to 6;
  signal i2c_si57x_reg_addr: std_logic_vector(7 downto 0);
  signal i2c_trans_mode: t_i2c_trans_mode;
  signal hs_div_cpy: std_logic_vector(2 downto 0);
  signal n1_cpy: std_logic_vector(6 downto 0);
  signal rfreq_cpy: std_logic_vector(37 downto 0);
  signal cpy_valid: boolean;
begin

  -- Configuration is in sync if the internal registers copy is
  -- initialized and equal to the inputs
  cfg_in_sync_o <= '1' when hs_div_cpy = hs_div_i and
                   n1_cpy = n1_i and rfreq_cpy = rfreq_i and
                   cpy_valid else '0';

  cmp_i2c_master_byte_ctrl: entity work.i2c_master_byte_ctrl
	port map (
	  clk    => clk_i,
	  rst    => not(rst_n_i),
	  nReset => '1',
	  ena    => '1',

	  clk_cnt => to_unsigned(g_SCL_CLK_DIV-1, 16),

      -- Start an I2C transaction. Should be drived to '1' together with the
      -- 'read' signal and the slave address should be feed into 'din'
	  start  => i2c_start,

      -- Send a stop condition to the I2C slave.
	  stop   => i2c_stop,

      -- Read a byte from the slave
	  read   => i2c_read,

      -- Send a byte to the slave
	  write  => i2c_write,

      -- Send an ACK or NACK to the slave when reading a byte, ACK = '0',
      -- NACK = '1'
	  ack_in => i2c_ack_in,

      -- Byte to be sent to the slave
	  din    => i2c_din,

      -- Will go to '1' for one clock cycle to indicate that the last command
      -- has finished
	  cmd_ack  => i2c_cmd_ack,

      -- ACK/NACK received from the slave in the last byte sent, ACK = '0',
      -- NACK = '1'
	  ack_out  => i2c_ack_out,

      -- I2C transaction is active if i2c_busy = '1', it still can receive new
      -- commands, just make sure to wait for the cmd_ack after issuing a new
      -- command
	  i2c_busy => i2c_busy,

      -- Arbitration lost?
	  i2c_al   => i2c_al,

      -- Byte received from the slave
	  dout     => i2c_dout,

	  scl_i   => scl_i,
	  scl_o   => scl_o,
	  scl_oen => scl_oen,
	  sda_i   => sda_i,
	  sda_o   => sda_o,
	  sda_oen => sda_oen
	);

  -- Invert signals here to make the signal interface more consistent
  scl_oe_o <= not(scl_oen);
  sda_oe_o <= not(sda_oen);

  -- Computes the busy condition
  busy_o <= '1' when i2c_state /= IDLE or si57x_state /= IDLE or
            read_startup_regs_i = '1' or apply_cfg_i = '1' else '0';

  -- Use an internal 'i2c_err' signal to be able to read from (VHDL 1993
  -- limitation)
  i2c_err_o <= i2c_err;

  -- Produce an NACK for the last byte to be received
  i2c_ack_in <= '1' when (i2c_buff_cnt + 1) >= i2c_buff_size and i2c_state = READ_BYTES else '0';

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        startup_complete_o <= '0';
        cpy_valid <= false;
        i2c_err <= '0';
        i2c_state <= IDLE;
        si57x_state <= IDLE;
      else

        ---------------------------------------------------------------------
        --                   Si57x control state machine                   --
        ---------------------------------------------------------------------

        -- From the Si57x datasheet:
        --
        -- Writing the New Frequency Configuration
        -- Once the new values for RFREQ, HSDIV, and N1 are determined, they
        -- can be written directly into the device from the serial port using
        -- the following procedure:
        --
        -- 1. Freeze the DCO (bit 4 of Register 137)
        --
        -- 2. Write the new frequency configuration (RFREQ, HSDIV, and N1) to
        --    addresses 7–12 for all Si571 devices and Si570 devices with 20
        --    ppm and 50 ppm temperature stability; or addresses 13–18 for
        --    Si570 devices with 7 ppm temperature stability.
        --
        -- 3. Unfreeze the DCO and assert the NewFreq bit (bit 6 of Register
        --    135) within the maximum Unfreeze to NewFreq timeout specified
        --    in Table 11, "Programming Constraints and Timing," on page 12.
        --
        -- The process of freezing and unfreezing the DCO will cause the
        -- output clock to momentarily stop and start at any arbitrary
        -- point during a clock cycle. This process can take up to 10 ms.
        -- Circuitry that is sensitive to glitches or runt pulses may have
        -- to be reset after the new frequency configuration is written.

        -- Si57x control FSM
        case si57x_state is
          when IDLE =>
            if i2c_state = IDLE then
              if apply_cfg_i = '1' then
                i2c_si57x_reg_addr <= x"89";
                -- Freeze DCO, to avoid frequency changes while writing to the
                -- DSPLL registers
                i2c_buff(0) <= x"10";
                i2c_buff_size <= 1;
                i2c_state <= SEND_START_ADDR_WRITE;
                i2c_trans_mode <= WRITE_DATA;
                si57x_state <= WRITE_REGS;
                -- Make a copy of hsdiv, n1 and rfreq inputs
                hs_div_cpy <= hs_div_i;
                n1_cpy <= n1_i;
                rfreq_cpy <= rfreq_i;
                -- The copy is not valid yet, it isn't transfered to the Si57x
                -- yet
                cpy_valid <= false;
                -- Reset the I2C error flag
                i2c_err <= '0';
              elsif read_startup_regs_i = '1' then
                i2c_si57x_reg_addr <= x"87";
                -- Restore calibrated startup registers (RECALL)
                i2c_buff(0) <= x"01";
                i2c_buff_size <= 1;
                i2c_state <= SEND_START_ADDR_WRITE;
                i2c_trans_mode <= WRITE_DATA;
                si57x_state <= READ_REGS;
                -- Internal copy not valid anymore
                cpy_valid <= false;
                -- Reset the I2C error flag
                i2c_err <= '0';
              end if;
            end if;

          when READ_REGS =>
            if i2c_err = '1' then
              -- I2C error detected, abort!
              si57x_state <= IDLE;
            elsif i2c_state = IDLE then
              -- Read the Si57x DSPLL registers
              if g_SI57X_7PPM_VARIANT then
                i2c_si57x_reg_addr <= x"0D";
              else
                i2c_si57x_reg_addr <= x"07";
              end if;
              i2c_buff_size <= 6;
              i2c_state <= SEND_START_ADDR_WRITE;
              i2c_trans_mode <= READ_DATA;
              si57x_state <= WAIT_READ_REGS;
            end if;

          when WAIT_READ_REGS =>
            if i2c_err = '1' then
              -- I2C error detected, abort!
              si57x_state <= IDLE;
            elsif i2c_state = IDLE then
              -- Decode bytes read
              hs_div_startup_o <= i2c_buff(0)(7 downto 5);
              n1_startup_o <= i2c_buff(0)(4 downto 0) & i2c_buff(1)(7 downto 6);
              rfreq_startup_o <= i2c_buff(1)(5 downto 0) &
                                 i2c_buff(2)(7 downto 0) &
                                 i2c_buff(3)(7 downto 0) &
                                 i2c_buff(4)(7 downto 0) &
                                 i2c_buff(5)(7 downto 0);
              -- Update the internal copy of the DSPLL registers
              hs_div_cpy <= i2c_buff(0)(7 downto 5);
              n1_cpy <= i2c_buff(0)(4 downto 0) & i2c_buff(1)(7 downto 6);
              rfreq_cpy <= i2c_buff(1)(5 downto 0) &
                           i2c_buff(2)(7 downto 0) &
                           i2c_buff(3)(7 downto 0) &
                           i2c_buff(4)(7 downto 0) &
                           i2c_buff(5)(7 downto 0);
              -- Internal copy is valid again
              cpy_valid <= true;
              startup_complete_o <= '1';
              si57x_state <= IDLE;
            end if;

          when WRITE_REGS =>
            if i2c_err = '1' then
              -- I2C error detected, abort!
              si57x_state <= IDLE;
            elsif i2c_state = IDLE then
              -- Start writing the DSPLL registers
              if g_SI57X_7PPM_VARIANT then
                i2c_si57x_reg_addr <= x"0D";
              else
                i2c_si57x_reg_addr <= x"07";
              end if;
              -- Encode the Si57x DSPLL registers
              i2c_buff(0) <= hs_div_cpy & n1_cpy(6 downto 2);
              i2c_buff(1) <= n1_cpy(1 downto 0) & rfreq_cpy(37 downto 32);
              i2c_buff(2) <= rfreq_cpy(31 downto 24);
              i2c_buff(3) <= rfreq_cpy(23 downto 16);
              i2c_buff(4) <= rfreq_cpy(15 downto 8);
              i2c_buff(5) <= rfreq_cpy(7 downto 0);
              i2c_buff_size <= 6;
              i2c_state <= SEND_START_ADDR_WRITE;
              i2c_trans_mode <= WRITE_DATA;
              si57x_state <= UNFREEZE_DCO;
            end if;

          when UNFREEZE_DCO =>
            if i2c_err = '1' then
              -- I2C error detected, abort!
              si57x_state <= IDLE;
            elsif i2c_state = IDLE then
              i2c_si57x_reg_addr <= x"89";
              -- Unfreeze DCO
              i2c_buff(0) <= x"00";
              i2c_buff_size <= 1;
              i2c_state <= SEND_START_ADDR_WRITE;
              i2c_trans_mode <= WRITE_DATA;
              si57x_state <= APPLY_NEWFREQ;
            end if;

          when APPLY_NEWFREQ =>
            if i2c_err = '1' then
              -- I2C error detected, abort!
              si57x_state <= IDLE;
            elsif i2c_state = IDLE then
              i2c_si57x_reg_addr <= x"87";
              -- Apply NewFreq
              i2c_buff(0) <= x"40";
              i2c_buff_size <= 1;
              cpy_valid <= true;
              i2c_state <= SEND_START_ADDR_WRITE;
              i2c_trans_mode <= WRITE_DATA;
              si57x_state <= IDLE;
            end if;

        end case;


        ---------------------------------------------------------------------
        --                   I2C control state machine                     --
        ---------------------------------------------------------------------

        -- Set all command signals to '0' by default
        i2c_start <= '0';
        i2c_stop <= '0';
        i2c_read <= '0';
        i2c_write <= '0';

        -- I2C FSM
        case i2c_state is
          when IDLE =>
            i2c_buff_cnt <= 0;

          when SEND_START_ADDR_WRITE =>
            -- Initiate a I2C master write transaction
            i2c_start <= '1';
            i2c_write <= '1';
            i2c_din <= g_SI57X_I2C_ADDR & '0';
            i2c_state <= SEND_REG_ADDR;

          -- Wait until the start and I2C addr operation finished, then send
          -- the register address byte
          when SEND_REG_ADDR =>
            if i2c_cmd_ack = '1' then
              i2c_din <= i2c_si57x_reg_addr;
              i2c_write <= '1';
              if i2c_trans_mode = WRITE_DATA then
                i2c_state <= WRITE_BYTES;
              else
                i2c_state <= SEND_START_ADDR_READ;
              end if;
            end if;

          -- Write N bytes to the slave (set by i2c_buff_size) from the i2c_buff
          -- register array
          when WRITE_BYTES =>
            if i2c_cmd_ack = '1' then
              if i2c_buff_cnt < i2c_buff_size then
                i2c_din <= i2c_buff(i2c_buff_cnt);
                i2c_write <= '1';
                i2c_buff_cnt <= i2c_buff_cnt + 1;
              else
                i2c_buff_cnt <= 0;
                i2c_stop <= '1';
                i2c_state <= WAIT_STOP;
              end if;
            end if;

          when SEND_START_ADDR_READ =>
            if i2c_cmd_ack = '1' then
              -- Initiate a I2C master read transaction
              i2c_start <= '1';
              i2c_write <= '1';
              i2c_din <= g_SI57X_I2C_ADDR & '1';
              i2c_state <= WAIT_SEND_START_ADDR_READ;
            end if;

          when WAIT_SEND_START_ADDR_READ =>
            if i2c_cmd_ack = '1' then
              i2c_state <= READ_BYTES;
              i2c_read <= '1';
            end if;

          -- Read N bytes from the slave (set by i2c_buff_size) and store it to
          -- the i2c_buff register array
          when READ_BYTES =>
            if i2c_cmd_ack = '1' then
              if (i2c_buff_cnt + 1) < i2c_buff_size then
                i2c_buff(i2c_buff_cnt) <= i2c_dout;
                i2c_read <= '1';
                i2c_buff_cnt <= i2c_buff_cnt + 1;
              else
                i2c_buff(i2c_buff_cnt) <= i2c_dout;
                i2c_buff_cnt <= 0;
                i2c_stop <= '1';
                i2c_state <= WAIT_STOP;
              end if;
            end if;

          when WAIT_STOP =>
            if i2c_cmd_ack = '1' then
              i2c_state <= IDLE;
            end if;

        end case;

        if i2c_cmd_ack = '1' and i2c_state /= WAIT_STOP then
          -- If an arbitration lost condition is detected, go to IDLE, else if
          -- the slave responds with an NACK, send a STOP. On both cases
          -- signals an I2C error.
          if i2c_al = '1' then
            i2c_state <= IDLE;
            i2c_stop <= '0';
            i2c_write <= '0';
            i2c_read <= '0';
            i2c_err <= '1';
          -- I'm forced to check if the i2c_state is not READ_BYTES or IDLE
          -- because the i2c_master_byte_ctrl ack_out signal is asserted when
          -- we send a NACK after the last byte sent by the slave
          elsif i2c_ack_out = '1' and i2c_state /= READ_BYTES and
                i2c_state /= IDLE then
            i2c_stop <= '1';
            i2c_state <= WAIT_STOP;
            i2c_write <= '0';
            i2c_read <= '0';
            i2c_err <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture;
