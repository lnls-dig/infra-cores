-------------------------------------------------------------------------------
-- Title      : Trigger I/O
-- Project    :
-------------------------------------------------------------------------------
-- File       : pulse_train_gen.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-12-11
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Generates a pulse train for each incoming pulse, with the same
-- length as the input pulse, with 50% duty cycle
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-12-11  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_common_pkg.all;

entity pulse_train_gen is
generic
(
  -- Length of input pulse counter. This is used internally and is used
  -- to determine the maximum width for the input counter. This effectively
  -- limits the maximum input pulse width
  g_input_pulse_max_width                  : natural := 32;
  -- Length of pulse generator
  g_pulse_train_gen_width                  : natural := 16
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -------------------------------
  -- Trigger configuration
  -------------------------------
  pulse_i                                  : in std_logic;
  pulse_train_num_i                        : in unsigned(g_pulse_train_gen_width-1 downto 0);
  pulse_train_o                            : out std_logic;
  pulse_rdy_o                              : out std_logic
);
end entity pulse_train_gen;

architecture rtl of pulse_train_gen is

  -- Types declarations
  type t_pulse_train_fsm_state is (WAIT_FOR_PULSE, PULSE_MEAS, GEN_PULSE_HIGH,
                                    GEN_PULSE_LOW, CHECK_END_TRAIN);

  -- Signals
  signal pulse_train_fsm_current_state     : t_pulse_train_fsm_state;
  signal pulse_train_cnt                   : unsigned(g_pulse_train_gen_width-1 downto 0) :=
                                               to_unsigned(0, g_pulse_train_gen_width);
  signal pulse_train_cnt_max               : unsigned(g_pulse_train_gen_width-1 downto 0) :=
                                               to_unsigned(0, g_pulse_train_gen_width);
  signal pulse_cycles_cnt                  : unsigned(g_input_pulse_max_width-1 downto 0) :=
                                               to_unsigned(0, g_input_pulse_max_width);
  signal pulse_cycles_cnt_max              : unsigned(g_input_pulse_max_width-1 downto 0) :=
                                               to_unsigned(0, g_input_pulse_max_width);
  signal pulse_train                       : std_logic;
  signal rdy                               : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Main FSM
  ----------------------------------------------------------------------------
  -- FSM transitions + outputs
  p_pulse_train_pulse_fsm : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        pulse_train_fsm_current_state <= WAIT_FOR_PULSE;
        pulse_train_cnt <= to_unsigned(0, pulse_train_cnt'length);
        pulse_train_cnt_max <= to_unsigned(0, pulse_train_cnt_max'length);
        pulse_cycles_cnt <= to_unsigned(0, pulse_cycles_cnt'length);
        pulse_cycles_cnt_max <= to_unsigned(0, pulse_cycles_cnt_max'length);
        pulse_train <= '0';
        rdy <= '1';
      else
        case pulse_train_fsm_current_state is

          when WAIT_FOR_PULSE =>
            if pulse_i = '1' then
              pulse_train_cnt <= to_unsigned(0, pulse_train_cnt'length);
              -- Pulse is at least 1 clock cycle
              pulse_cycles_cnt <= to_unsigned(0, pulse_cycles_cnt'length);
              pulse_cycles_cnt_max <= to_unsigned(0, pulse_cycles_cnt_max'length);
              rdy <= '0';

              -- If we are in bypass mode (pulse_train_num_i = 0), don't generate
              -- anything and wait for next pulse
              pulse_train_cnt_max <= pulse_train_num_i - 1;
              if pulse_train_num_i = to_unsigned(0, pulse_train_num_i'length) then
                pulse_train <= '0';
                rdy <= '1';
                pulse_train_fsm_current_state <= WAIT_FOR_PULSE;
              else
                pulse_train_fsm_current_state <= PULSE_MEAS;
              end if;

            end if;

          when PULSE_MEAS =>
            if pulse_i = '0' then
              pulse_train_fsm_current_state <= GEN_PULSE_HIGH;
            else
              pulse_cycles_cnt_max <= pulse_cycles_cnt_max + 1;
            end if;

          when GEN_PULSE_HIGH =>
            pulse_train <= '1';

            if pulse_cycles_cnt = pulse_cycles_cnt_max then
              pulse_cycles_cnt <= to_unsigned(0, pulse_cycles_cnt'length);
              pulse_train_fsm_current_state <= GEN_PULSE_LOW;
            else
              pulse_cycles_cnt <= pulse_cycles_cnt + 1;
            end if;

          when GEN_PULSE_LOW =>
            pulse_train <= '0';

            if pulse_cycles_cnt = pulse_cycles_cnt_max then
              pulse_cycles_cnt <= to_unsigned(0, pulse_cycles_cnt'length);
              -- Do we need to keep generating pulses or not?
              if pulse_train_cnt = pulse_train_cnt_max then
                rdy <= '1';
                pulse_train_fsm_current_state <= WAIT_FOR_PULSE;
              else
                pulse_train_cnt <= pulse_train_cnt + 1;
                pulse_train_fsm_current_state <= GEN_PULSE_HIGH;
              end if;
            else
              pulse_cycles_cnt <= pulse_cycles_cnt + 1;
            end if;

          when others =>
            pulse_train <= '0';
            rdy <= '1';
            pulse_train_fsm_current_state <= WAIT_FOR_PULSE;

        end case;
      end if;
    end if;
  end process;

  pulse_train_o <= pulse_train;
  pulse_rdy_o <= rdy;

end rtl;
