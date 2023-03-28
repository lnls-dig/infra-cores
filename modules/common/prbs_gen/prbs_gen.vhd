--------------------------------------------------------------------------------
-- Title      : Pseudo-Random Binary Sequence (PRBS) generator
-- Project    :
--------------------------------------------------------------------------------
-- File       : prbs_gen.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Generic
-- Standard   : VHDL'93/02
--------------------------------------------------------------------------------
-- Description: Pseudo-Random Binary Sequence (PRBS) generator with configurable
--              sequence duration.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-03-15   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity prbs_gen is

  port (
    -- Clock
    clk_i     : in std_logic;

    -- Reset
    rst_n_i   : in std_logic;

    -- Length (in bits) of internal LFSR. This determines the duration of the
    -- generated sequence, which is given by: 2^{length_i} - 1.
    -- NOTE: Changing this signal resets the internal LFSR. valid_i is ignored
    --       in this cycle.
    length_i  : in natural range 2 to 32 := 32;

    -- Signal for iterating the PRBS
    valid_i   : in std_logic;

    -- PRBS signal
    prbs_o    : out std_logic;

    -- PRBS valid signal
    valid_o   : out std_logic
  );

end entity prbs_gen;

architecture beh of prbs_gen is

  -- functions
  function f_max_len_feedback(length : natural range 2 to 32;
                              lfsr   : std_logic_vector) return std_logic is
  begin
    case length is
      -- These were taken from Table 1 on
      -- https://www.digikey.com/en/articles/use-readily-available-components-generate-binary-sequences-white-noise.
      when 2  => return  lfsr(1) xor  lfsr(0);
      when 3  => return  lfsr(2) xor  lfsr(1);
      when 4  => return  lfsr(3) xor  lfsr(2);
      when 5  => return  lfsr(4) xor  lfsr(2);
      when 6  => return  lfsr(5) xor  lfsr(4);
      when 7  => return  lfsr(6) xor  lfsr(5);
      when 8  => return  lfsr(7) xor  lfsr(5) xor  lfsr(4) xor lfsr(3);
      when 9  => return  lfsr(8) xor  lfsr(4);
      when 10 => return  lfsr(9) xor  lfsr(6);
      when 11 => return lfsr(10) xor  lfsr(8);
      when 12 => return lfsr(11) xor  lfsr(5) xor  lfsr(3) xor lfsr(0);
      when 13 => return lfsr(12) xor  lfsr(3) xor  lfsr(2) xor lfsr(0);
      when 14 => return lfsr(13) xor  lfsr(4) xor  lfsr(2) xor lfsr(0);
      when 15 => return lfsr(14) xor lfsr(13);
      when 16 => return lfsr(15) xor lfsr(14) xor lfsr(12) xor lfsr(3);
      when 17 => return lfsr(16) xor lfsr(13);
      when 18 => return lfsr(17) xor lfsr(10);
      when 19 => return lfsr(18) xor lfsr(5)  xor  lfsr(1) xor lfsr(0);
      when 20 => return lfsr(19) xor lfsr(16);
      when 21 => return lfsr(20) xor lfsr(18);
      when 22 => return lfsr(21) xor lfsr(20);
      when 23 => return lfsr(22) xor lfsr(17);
      when 24 => return lfsr(23) xor lfsr(22) xor lfsr(21) xor lfsr(16);
      when 25 => return lfsr(24) xor lfsr(21);
      when 26 => return lfsr(25) xor  lfsr(5) xor  lfsr(1) xor lfsr(0);
      when 27 => return lfsr(26) xor  lfsr(4) xor  lfsr(1) xor lfsr(0);
      when 28 => return lfsr(27) xor lfsr(24);
      when 29 => return lfsr(28) xor lfsr(26);
      when 30 => return lfsr(29) xor  lfsr(5) xor  lfsr(3) xor lfsr(0);
      when 31 => return lfsr(30) xor lfsr(27);
      when 32 => return lfsr(31) xor lfsr(21) xor  lfsr(1) xor lfsr(0);
    end case;
  end function;

  -- constants
  constant c_MAX_LENGTH     : natural := 32;
  -- NOTE: The reset value can't be "0" since it is the forbidden state.
  constant c_LFSR_RESET_VAL : std_logic_vector(c_MAX_LENGTH-1 downto 0) := (0 => '1', others => '0');

  -- signals
  signal lfsr           : std_logic_vector(c_MAX_LENGTH-1 downto 0) := c_LFSR_RESET_VAL;
  signal valid          : std_logic := '0';
  signal length_d1      : natural range 2 to 32 := c_MAX_LENGTH;
  signal length_changed : boolean := false;

begin

  -- Checks if length_i changed
  length_changed <= true when length_i /= length_d1 else false;

  -- processes
  process(clk_i) is
  begin
    if rising_edge(clk_i) then
      valid <= '0';
      if rst_n_i = '0' then
        lfsr <= c_LFSR_RESET_VAL;
      -- This has to be done so LFSR never stucks in the forbidden state
      elsif length_changed = true then
        lfsr <= c_LFSR_RESET_VAL;
      elsif valid_i = '1' then
        lfsr <= lfsr(lfsr'left - 1 downto lfsr'right) & f_max_len_feedback(length_i, lfsr);
        valid <= '1';
      end if;

      -- Register length_i so to check if it changes
      length_d1 <= length_i;
    end if;
  end process;

  prbs_o <= lfsr(length_i-1);
  valid_o <= valid;

end architecture beh;
