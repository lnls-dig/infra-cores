------------------------------------------------------------------------------
-- Title      : FOFB Controller Wrapper
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2020-12-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Silabs Si57x series oscillator hardware interface, allowing
-- it to configure Si57x via an external interface and/or via init parameters (generics).
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2020-12-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

-- This was heavily based on the wr_si57x_interface by the WR project available
-- here: https://ohwr.org/project/wr-cores/blob/proposed_master/modules/wr_si57x_interface/wr_si57x_interface.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity si57x_interface is
generic (
  g_SYS_CLOCK_FREQ                           : integer := 100000000;
  g_I2C_FREQ                                 : integer := 100000;
  -- Whether or not to initialize oscilator with the specified values
  g_INIT_OSC                                 : boolean := true;
  -- Init Oscillator values
  g_INIT_RFREQ_VALUE                         : std_logic_vector(37 downto 0) := "00" & x"3017a66ad";
  g_INIT_N1_VALUE                            : std_logic_vector(6 downto 0) := "0000011";
  g_INIT_HS_VALUE                            : std_logic_vector(2 downto 0) := "111"
);
port (
  ---------------------------------------------------------------------------
  -- clock and reset interface
  ---------------------------------------------------------------------------
  clk_sys_i                                  : in std_logic;
  rst_n_i                                    : in std_logic;

  ---------------------------------------------------------------------------
  -- Optional external RFFREQ interface
  ---------------------------------------------------------------------------
  ext_wr_i                                   : in std_logic := '0';
  ext_rfreq_value_i                          : in std_logic_vector(37 downto 0) := (others => '0');
  ext_n1_value_i                             : in std_logic_vector(6 downto 0) := (others => '0');
  ext_hs_value_i                             : in std_logic_vector(2 downto 0) := (others => '0');

  ---------------------------------------------------------------------------
  -- Status pins
  ---------------------------------------------------------------------------
  sta_reconfig_done_o                        : out std_logic;

  ---------------------------------------------------------------------------
  -- I2C bus: output enable (active low)
  ---------------------------------------------------------------------------
  scl_pad_oen_o                              : out std_logic;
  sda_pad_oen_o                              : out std_logic;

  ---------------------------------------------------------------------------
  -- SI57x pins
  ---------------------------------------------------------------------------
  -- Optional OE control
  si57x_oe_i                                 : in std_logic := '1';
  -- Si57x slave address. Default is (slave address & '0')
  si57x_addr_i                               : in std_logic_vector(7 downto 0) := "10101010";
  si57x_oe_o                                 : out std_logic

);
end si57x_interface;

architecture rtl of si57x_interface is

  -- constants

  -- number of ticks per I2C state
  constant c_NUM_TICKS_PER_CLOCK             : integer := 3;
  constant c_I2C_DIV                         : natural := g_SYS_CLOCK_FREQ/(c_NUM_TICKS_PER_CLOCK*g_I2C_FREQ)-1;

  -- signals
  signal rfreq                               : std_logic_vector(37 downto 0);
  signal n1                                  : std_logic_vector(6 downto 0);
  signal hs                                  : std_logic_vector(2 downto 0);

  signal rfreq_fsm                           : std_logic_vector(37 downto 0);
  signal n1_fsm                              : std_logic_vector(6 downto 0);
  signal hs_fsm                              : std_logic_vector(2 downto 0);

  signal ext_new_p                           : std_logic;
  signal init_new_p                          : std_logic;

  signal i2c_tick                            : std_logic;
  signal i2c_divider                         : unsigned(7 downto 0);

  signal scl_out_fsm                         : std_logic;
  signal sda_out_fsm                         : std_logic;

  signal seq_count                           : unsigned(8 downto 0);

  -- I2C types
  type t_i2c_transaction is (START, STOP, SEND_BYTE);

  type t_state is (IDLE, SI_START0, SI_START1, SI_START2, SI_START3,
    SI_ADDR0, SI_ADDR1, SI_ADDR2, SI_ADDR3,
    SI_REG0, SI_REG1, SI_REG2, SI_REG3,
    SI_HSN1,
    SI_RF0, SI_RF1, SI_RF2, SI_RF3, SI_RF4,
    SI_STOP0, SI_STOP1, SI_STOP2, SI_STOP3,
    SI_FREEZE0, SI_FREEZE2, SI_NEWFREQ);

  signal state                               : t_state;

  procedure f_i2c_iterate(tick : std_logic;
                          signal counter : inout unsigned;
                          value : std_logic_vector(7 downto 0);
                          trans_type : t_i2c_transaction;
                          signal scl : out std_logic;
                          signal sda : out std_logic;
                          signal state_var : out t_state;
                          next_state : t_state) is
    variable last : boolean;
  begin

    last := false;

    if(tick = '0') then
      return;
    end if;

    case trans_type is
      when START =>

        case counter(1 downto 0) is
          -- states 0..2: start condition
          when "00" =>
            scl <= '1';
            sda <= '1';
          when "01" =>
            sda <= '0';
          when "10" =>
            scl  <= '0';
            last := true;
          when others => null;
        end case;

      when STOP =>

        case counter(1 downto 0) is
          -- states 0..2: start condition
          when "00" =>
            sda <= '0';
          when "01" =>
            scl <= '1';
          when "10" =>
            sda  <= '1';
            last := true;
          when others => null;
        end case;

      when SEND_BYTE =>

        case counter(1 downto 0) is
          when "00" =>
            sda <= value(7-to_integer(counter(4 downto 2)));
          when "01" =>
            scl <= '1';
          when "10" =>
            scl <= '0';
            if(counter(5) = '1') then
              last := true;
            end if;
          when others => null;
        end case;
    end case;

    if(last) then
      state_var <= next_state;
      counter   <= "000000000";
    else
      counter <= counter + 1;
    end if;

  end f_i2c_iterate;

  function f_bool_to_std( x : boolean ) return std_logic is
    variable ret : std_logic;
  begin
      if x then
        ret := '1';
      else
        ret := '0';
      end if;

     return ret;
  end f_bool_to_std;

begin

  -- Simple bypass OE
  si57x_oe_o <= si57x_oe_i;

  -- Si57x values to be written
  p_si57x_values : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        rfreq <= g_INIT_RFREQ_VALUE;
        n1 <= g_INIT_N1_VALUE;
        hs <= g_INIT_HS_VALUE;
        ext_new_p <= '0';
      else
        ext_new_p <= ext_wr_i;

        if ext_wr_i = '1' then
          rfreq <= ext_rfreq_value_i;
          n1 <= ext_n1_value_i;
          hs <= ext_hs_value_i;
        end if;

      end if;
    end if;
  end process;

  p_i2c_divider : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        i2c_divider <= (others => '0');
        i2c_tick    <= '0';
      else
        if(i2c_divider = to_unsigned(c_I2C_DIV, i2c_divider'length)) then
          i2c_tick <= '1';
          i2c_divider <= (others => '0');
        else
          i2c_tick <= '0';
          i2c_divider <= i2c_divider + 1;
        end if;
      end if;
    end if;
  end process;

   p_i2c_fsm : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        init_new_p  <= f_bool_to_std(g_INIT_OSC);
        state       <= IDLE;
        seq_count   <= (others => '0');
        sta_reconfig_done_o <= '1';
        rfreq_fsm <= (others => '0');
        n1_fsm <= (others => '0');
        hs_fsm <= (others => '0');
        scl_out_fsm <= '1';
        sda_out_fsm <= '1';
      else
        case state is
          when IDLE =>
            -- Write new values if on boot or when requested
            if(ext_new_p = '1' or init_new_p = '1') then
              state <= SI_START0;
              sta_reconfig_done_o <= '0';
              -- Avoid chaning values in the middle of a transaction
              rfreq_fsm <= rfreq;
              n1_fsm <= n1;
              hs_fsm <= hs;
            end if;

          -- Freeze registers
          when SI_START0 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", START, scl_out_fsm, sda_out_fsm, state, SI_ADDR1);
          when SI_ADDR0 =>
            f_i2c_iterate(i2c_tick, seq_count, si57x_addr_i, SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_REG0);
          when SI_REG0 =>
            -- Register "Freeze DCO"
            f_i2c_iterate(i2c_tick, seq_count, x"89", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_FREEZE0);
          when SI_FREEZE0 =>
            -- "Freeze DCO" bit
            f_i2c_iterate(i2c_tick, seq_count, x"10", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_STOP0);
          when SI_STOP0 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", STOP, scl_out_fsm, sda_out_fsm, state, SI_START1);

          -- Write N1/HS/RFREQ registers
          when SI_START1 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", START, scl_out_fsm, sda_out_fsm, state, SI_ADDR1);
          when SI_ADDR1 =>
            f_i2c_iterate(i2c_tick, seq_count, si57x_addr_i, SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_REG1);
          when SI_REG1 =>
            f_i2c_iterate(i2c_tick, seq_count, x"07", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_HSN1);

          when SI_HSN1 =>
            f_i2c_iterate(i2c_tick, seq_count, hs_fsm & n1_fsm(6 downto 2), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF0);

          when SI_RF0 =>
            f_i2c_iterate(i2c_tick, seq_count, n1_fsm(1 downto 0) & rfreq_fsm(37 downto 32), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF1);

          when SI_RF1 =>
            f_i2c_iterate(i2c_tick, seq_count, rfreq_fsm(31 downto 24), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF2);

          when SI_RF2 =>
            f_i2c_iterate(i2c_tick, seq_count, rfreq_fsm(23 downto 16), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF3);

          when SI_RF3 =>
            f_i2c_iterate(i2c_tick, seq_count, rfreq_fsm(15 downto 8), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_RF4);

          when SI_RF4 =>
            f_i2c_iterate(i2c_tick, seq_count, rfreq_fsm(7 downto 0), SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_STOP1);

          when SI_STOP1 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", STOP, scl_out_fsm, sda_out_fsm, state, SI_START2);

          -- Unfreeze registers
          when SI_START2 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", START, scl_out_fsm, sda_out_fsm, state, SI_ADDR2);
          when SI_ADDR2 =>
            f_i2c_iterate(i2c_tick, seq_count, si57x_addr_i, SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_REG2);
          when SI_REG2 =>
            -- Register "Freeze DCO"
            f_i2c_iterate(i2c_tick, seq_count, x"89", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_FREEZE2);
          when SI_FREEZE2 =>
            -- "Freeze DCO" bit
            f_i2c_iterate(i2c_tick, seq_count, x"00", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_STOP2);
          when SI_STOP2 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", STOP, scl_out_fsm, sda_out_fsm, state, SI_START3);

          -- New frequency bit
          when SI_START3 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", START, scl_out_fsm, sda_out_fsm, state, SI_ADDR3);
          when SI_ADDR3 =>
            f_i2c_iterate(i2c_tick, seq_count, si57x_addr_i, SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_REG3);
          when SI_REG3 =>
            -- "Reset/Freeze/Memory Control" register
            f_i2c_iterate(i2c_tick, seq_count, x"87", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_NEWFREQ);
          when SI_NEWFREQ =>
            -- "NewFreq" bit
            f_i2c_iterate(i2c_tick, seq_count, x"40", SEND_BYTE, scl_out_fsm, sda_out_fsm, state, SI_STOP3);
          when SI_STOP3 =>
            f_i2c_iterate(i2c_tick, seq_count, x"00", STOP, scl_out_fsm, sda_out_fsm, state, IDLE);

            sta_reconfig_done_o <= '1';
            -- Signal that we have made at least one pass through the FSM
            init_new_p <= '0';

          when others =>
            null;

        end case;
      end if;
    end if;
  end process;

  -- Assign outputs
  scl_pad_oen_o <= scl_out_fsm;
  sda_pad_oen_o <= sda_out_fsm;

end rtl;
