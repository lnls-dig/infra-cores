------------------------------------------------------------------------------
-- Title      : RTM Serial register interface
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2021-01-18
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: RTM Serial register interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2021 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2021-01-18  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rtm8sfp_ohwr_serial_regs is
generic (
  g_SYS_CLOCK_FREQ                           : integer := 100000000;
  g_SERIAL_FREQ                              : integer := 100000
);
port (
  ---------------------------------------------------------------------------
  -- clock and reset interface
  ---------------------------------------------------------------------------
  clk_sys_i                                  : in std_logic;
  rst_n_i                                    : in std_logic;

  ---------------------------------------------------------------------------
  -- RTM serial interface
  ---------------------------------------------------------------------------
  -- Set to 1 to read and write all SFP parameters listed at the SFP
  -- parallel interface
  sfp_sta_ctl_rw_i                           : in std_logic := '1';

  sfp_status_reg_clk_n_o                     : out std_logic;
  sfp_status_reg_out_i                       : in std_logic;
  sfp_status_reg_pl_o                        : out std_logic;

  sfp_ctl_reg_oe_n_o                         : out std_logic;
  sfp_ctl_reg_din_n_o                        : out std_logic;
  sfp_ctl_reg_str_n_o                        : out std_logic;

  ---------------------------------------------------------------------------
  -- SFP parallel interface
  ---------------------------------------------------------------------------
  sfp_led1_o                                 : out std_logic_vector(7 downto 0);
  sfp_los_o                                  : out std_logic_vector(7 downto 0);
  sfp_txfault_o                              : out std_logic_vector(7 downto 0);
  sfp_detect_n_o                             : out std_logic_vector(7 downto 0);
  sfp_txdisable_i                            : in std_logic_vector(7 downto 0);
  sfp_rs0_i                                  : in std_logic_vector(7 downto 0);
  sfp_rs1_i                                  : in std_logic_vector(7 downto 0);
  sfp_led1_i                                 : in std_logic_vector(7 downto 0);
  sfp_led2_i                                 : in std_logic_vector(7 downto 0)
);
end rtm8sfp_ohwr_serial_regs;

architecture rtl of rtm8sfp_ohwr_serial_regs is

  -- constants
  constant c_NUM_TICKS_PER_CLOCK             : integer := 3;
  constant c_SERIAL_DIV                      : natural := g_SYS_CLOCK_FREQ/(c_NUM_TICKS_PER_CLOCK*g_SERIAL_FREQ)-1;

  signal serial_tick                         : std_logic;
  signal serial_divider                      : unsigned(7 downto 0);

  signal seq_count                           : unsigned(8 downto 0);
  signal sfp_reg_to_device                   : std_logic_vector(39 downto 0) := (others => '0');
  signal sfp_reg_from_device                 : std_logic_vector(39 downto 0) := (others => '0');

  -- Serial types
  type t_serial_transaction is (PARALLEL_LOAD, SERIAL_SHIFT, HOLD);

  type t_state is (IDLE, LOAD, READ_WRITE);

  signal state                               : t_state;

  procedure f_serial_iterate(tick : std_logic;
                          signal counter : inout unsigned;
                          signal val_to_device : in std_logic_vector;
                          signal val_from_device : out std_logic_vector;
                          trans_type : t_serial_transaction;
                          signal reg_clk_n : out std_logic;
                          signal reg_din_n : out std_logic;
                          signal reg_pl : out std_logic;
                          signal reg_str_n : out std_logic;
                          signal reg_oe_n : out std_logic;
                          signal reg_dout : in std_logic;
                          signal state_var : out t_state;
                          next_state : t_state) is
    variable last : boolean;
    variable val_num_bits : integer := val_to_device'length;
  begin

    last := false;

    if(tick = '0') then
      return;
    end if;

    case trans_type is
      when PARALLEL_LOAD =>

        case counter(1 downto 0) is
          -- states 1..0: PARALLEL_LOAD
          when "00" =>
            reg_pl <= '0';
          when "01" =>
            reg_pl <= '1';
          when "10" =>
            reg_pl <= '0';
            last := true;
          when others =>
            null;
        end case;

      when SERIAL_SHIFT =>

        case counter(1 downto 0) is
          -- states 1..0: SERIAL_SHIFT
          when "00" =>
            reg_clk_n <= '1';
            -- Send MSB first. Careful to not wrap "counter".
            reg_din_n <= not val_to_device(val_to_device'left-
                                to_integer(counter(counter'left downto 2)));
            -- First otput bit is ready to read after PARALLEL_LOAD
            val_from_device(val_from_device'left -
                to_integer(counter(counter'left downto 2))) <= reg_dout;
            reg_pl <= '0';
            reg_str_n <= '1';
            reg_oe_n <= '0';

            -- last bit needs to assert strobe to serial data is latched
            -- onto parallel output
            if counter(counter'left downto 2) = to_unsigned(val_num_bits, counter'length)-1 then
              reg_str_n <= '0';
            end if;
          when "01" =>
            reg_clk_n <= '0';
          when "10" =>
            reg_clk_n <= '1';
            reg_str_n <= '1';

            if counter(counter'left downto 2) = to_unsigned(val_num_bits, counter'length)-1 then
              last := true;
            end if;
          when others =>
            null;
        end case;

      when HOLD =>

        case counter(1 downto 0) is
          -- states 1..0: HOLD
          when "00" =>
            reg_clk_n <= '0';
          when "01" =>
            null;
          when "10" =>
            last := true;
          when others =>
            null;
        end case;

    end case;

    if(last) then
      state_var <= next_state;
      counter   <= "000000000";
    else
      counter <= counter + 1;
    end if;

  end f_serial_iterate;

begin

  -- Register to be shifted to RTM reg_din pin. See RTM 8SFP schematics for
  -- order
  sfp_reg_to_device(39 downto 32) <= sfp_led2_i;
  sfp_reg_to_device(31)           <= sfp_led1_i(7);
  sfp_reg_to_device(30)           <= sfp_rs1_i(7);
  sfp_reg_to_device(29)           <= sfp_rs0_i(7);
  sfp_reg_to_device(28)           <= sfp_txdisable_i(7);
  sfp_reg_to_device(27)           <= sfp_led1_i(6);
  sfp_reg_to_device(26)           <= sfp_rs1_i(6);
  sfp_reg_to_device(25)           <= sfp_rs0_i(6);
  sfp_reg_to_device(24)           <= sfp_txdisable_i(6);
  sfp_reg_to_device(23)           <= sfp_led1_i(5);
  sfp_reg_to_device(22)           <= sfp_rs1_i(5);
  sfp_reg_to_device(21)           <= sfp_rs0_i(5);
  sfp_reg_to_device(20)           <= sfp_txdisable_i(5);
  sfp_reg_to_device(19)           <= sfp_led1_i(4);
  sfp_reg_to_device(18)           <= sfp_rs1_i(4);
  sfp_reg_to_device(17)           <= sfp_rs0_i(4);
  sfp_reg_to_device(16)           <= sfp_txdisable_i(4);
  sfp_reg_to_device(15)           <= sfp_led1_i(3);
  sfp_reg_to_device(14)           <= sfp_rs1_i(3);
  sfp_reg_to_device(13)           <= sfp_rs0_i(3);
  sfp_reg_to_device(12)           <= sfp_txdisable_i(3);
  sfp_reg_to_device(11)           <= sfp_led1_i(2);
  sfp_reg_to_device(10)           <= sfp_rs1_i(2);
  sfp_reg_to_device(9)            <= sfp_rs0_i(2);
  sfp_reg_to_device(8)            <= sfp_txdisable_i(2);
  sfp_reg_to_device(7)            <= sfp_led1_i(1);
  sfp_reg_to_device(6)            <= sfp_rs1_i(1);
  sfp_reg_to_device(5)            <= sfp_rs0_i(1);
  sfp_reg_to_device(4)            <= sfp_txdisable_i(1);
  sfp_reg_to_device(3)            <= sfp_led1_i(0);
  sfp_reg_to_device(2)            <= sfp_rs1_i(0);
  sfp_reg_to_device(1)            <= sfp_rs0_i(0);
  sfp_reg_to_device(0)            <= sfp_txdisable_i(0);

  sfp_led1_o(7)                   <= sfp_reg_from_device(39);
  sfp_los_o(7)                    <= sfp_reg_from_device(38);
  sfp_txfault_o(7)                <= sfp_reg_from_device(37);
  sfp_detect_n_o(7)               <= sfp_reg_from_device(36);
  sfp_led1_o(6)                   <= sfp_reg_from_device(35);
  sfp_los_o(6)                    <= sfp_reg_from_device(34);
  sfp_txfault_o(6)                <= sfp_reg_from_device(33);
  sfp_detect_n_o(6)               <= sfp_reg_from_device(32);
  sfp_led1_o(5)                   <= sfp_reg_from_device(31);
  sfp_los_o(5)                    <= sfp_reg_from_device(30);
  sfp_txfault_o(5)                <= sfp_reg_from_device(29);
  sfp_detect_n_o(5)               <= sfp_reg_from_device(28);
  sfp_led1_o(4)                   <= sfp_reg_from_device(27);
  sfp_los_o(4)                    <= sfp_reg_from_device(26);
  sfp_txfault_o(4)                <= sfp_reg_from_device(25);
  sfp_detect_n_o(4)               <= sfp_reg_from_device(24);
  sfp_led1_o(3)                   <= sfp_reg_from_device(23);
  sfp_los_o(3)                    <= sfp_reg_from_device(22);
  sfp_txfault_o(3)                <= sfp_reg_from_device(21);
  sfp_detect_n_o(3)               <= sfp_reg_from_device(20);
  sfp_led1_o(2)                   <= sfp_reg_from_device(19);
  sfp_los_o(2)                    <= sfp_reg_from_device(18);
  sfp_txfault_o(2)                <= sfp_reg_from_device(17);
  sfp_detect_n_o(2)               <= sfp_reg_from_device(16);
  sfp_led1_o(1)                   <= sfp_reg_from_device(15);
  sfp_los_o(1)                    <= sfp_reg_from_device(14);
  sfp_txfault_o(1)                <= sfp_reg_from_device(13);
  sfp_detect_n_o(1)               <= sfp_reg_from_device(12);
  sfp_led1_o(0)                   <= sfp_reg_from_device(11);
  sfp_los_o(0)                    <= sfp_reg_from_device(10);
  sfp_txfault_o(0)                <= sfp_reg_from_device(9);
  sfp_detect_n_o(0)               <= sfp_reg_from_device(8);

  p_serial_divider : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        serial_divider <= (others => '0');
        serial_tick    <= '0';
      else
        if(serial_divider = to_unsigned(c_SERIAL_DIV, serial_divider'length)) then
          serial_tick <= '1';
          serial_divider <= (others => '0');
        else
          serial_tick <= '0';
          serial_divider <= serial_divider + 1;
        end if;
      end if;
    end if;
  end process;

  p_serial_fsm : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        seq_count   <= (others => '0');
        state       <= IDLE;
        sfp_reg_from_device <= (others => '0');
        sfp_ctl_reg_str_n_o <= '1';
        sfp_ctl_reg_oe_n_o <= '1';
        sfp_status_reg_clk_n_o <= '1';
        sfp_ctl_reg_din_n_o <= '1';
        sfp_status_reg_pl_o <= '0';
      else
         case state is
            when IDLE =>
              f_serial_iterate(serial_tick, seq_count,
                    sfp_reg_to_device, sfp_reg_from_device,
                          HOLD,
                          sfp_status_reg_clk_n_o,
                          sfp_ctl_reg_din_n_o,
                          sfp_status_reg_pl_o,
                          sfp_ctl_reg_str_n_o,
                          sfp_ctl_reg_oe_n_o,
                          sfp_status_reg_out_i,
                          state,
                          IDLE);

              if sfp_sta_ctl_rw_i = '1' then
                state <= LOAD;
              end if;

            when LOAD =>
              f_serial_iterate(serial_tick, seq_count,
                    sfp_reg_to_device, sfp_reg_from_device,
                          PARALLEL_LOAD,
                          sfp_status_reg_clk_n_o,
                          sfp_ctl_reg_din_n_o,
                          sfp_status_reg_pl_o,
                          sfp_ctl_reg_str_n_o,
                          sfp_ctl_reg_oe_n_o,
                          sfp_status_reg_out_i,
                          state,
                          READ_WRITE);

            when READ_WRITE =>
              f_serial_iterate(serial_tick, seq_count,
                    sfp_reg_to_device, sfp_reg_from_device,
                          SERIAL_SHIFT,
                          sfp_status_reg_clk_n_o,
                          sfp_ctl_reg_din_n_o,
                          sfp_status_reg_pl_o,
                          sfp_ctl_reg_str_n_o,
                          sfp_ctl_reg_oe_n_o,
                          sfp_status_reg_out_i,
                          state,
                          IDLE);

            when others =>
                state <= IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
