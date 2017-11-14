-------------------------------------------------------------------------------
-- Title      : Dynamic Delay Generator
-- Project    :
-------------------------------------------------------------------------------
-- File       : delay_gen_dyn.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-11-13
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Dynamic delay generator based on counters. It receives an
-- incoming pulse, counts up to the specified amount of clock cycles and
-- outputs the output pulse.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-11-13  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_gen_dyn is
generic
(
  -- delay counter width
  g_delay_cnt_width                        : natural := 32
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -- Incoming pulse
  pulse_i                                  : in std_logic;
  -- '1' when the module is ready to receive another the pulse
  rdy_o                                    : out std_logic;
  -- Number of clock cycles to delay the incoming pulse
  delay_cnt_i                              : in unsigned(g_delay_cnt_width-1 downto 0);

  -- Output pulse
  pulse_o                                  : out std_logic
);
end delay_gen_dyn;

architecture rtl of delay_gen_dyn is

  -- Types declarations
  type t_delay_fsm_state is (WAIT_FOR_PULSE, COUNTING, CLR_OUTPUT_PULSE);

  -- Signals
  signal delay_fsm_current_state           : t_delay_fsm_state;
  signal delay_cnt                         : unsigned(g_delay_cnt_width-1 downto 0) :=
                                                to_unsigned(0, g_delay_cnt_width);
  signal delay_cnt_max                     : unsigned(g_delay_cnt_width-1 downto 0) :=
                                                to_unsigned(0, g_delay_cnt_width);
  signal pulse                             : std_logic;
  signal rdy                               : std_logic;

begin

  -- FSM transitions + outputs
  p_delay_pulse_fsm : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        delay_fsm_current_state <= WAIT_FOR_PULSE;
        delay_cnt <= to_unsigned(0, delay_cnt'length);
        delay_cnt_max <= to_unsigned(0, delay_cnt_max'length);
        pulse <= '0';
        rdy <= '1';
      else
        case delay_fsm_current_state is

          when WAIT_FOR_PULSE =>
            if pulse_i = '1' then
              delay_cnt <= to_unsigned(0, delay_cnt'length);
              rdy <= '0';

              -- If we are in bypass mode (delay_cnt_i = 0), generate the pulse
              -- and just go to the end of the FSM
              delay_cnt_max <= delay_cnt_i - 1;
              if delay_cnt_i = to_unsigned(0, delay_cnt_i'length) then
                delay_cnt_max <= to_unsigned(0, delay_cnt_max'length);
                pulse <= '1';
                delay_fsm_current_state <= CLR_OUTPUT_PULSE;
              else
                delay_fsm_current_state <= COUNTING;
              end if;

            end if;

          when COUNTING =>
            if delay_cnt /= delay_cnt_max then
              delay_cnt <= delay_cnt + 1;
              rdy <= '0';
            else
              pulse <= '1';
              delay_fsm_current_state <= CLR_OUTPUT_PULSE;
            end if;

          when CLR_OUTPUT_PULSE =>
            pulse <= '0';
            rdy <= '1';
            delay_fsm_current_state <= WAIT_FOR_PULSE;

          when others =>
            pulse <= '0';
            rdy <= '1';
            delay_fsm_current_state <= WAIT_FOR_PULSE;

        end case;
      end if;
    end if;
  end process;

  rdy_o <= rdy;
  pulse_o <= pulse;

end rtl;

