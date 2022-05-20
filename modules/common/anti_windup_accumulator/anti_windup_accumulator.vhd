-------------------------------------------------------------------------------
-- Title      :  Anti-windup accumulator
-------------------------------------------------------------------------------
-- Author     :  Guilherme Ricioli
-- Company    :  CNPEM LNLS-GCA
-- Platform   :  FPGA-generic
-------------------------------------------------------------------------------
-- Description:  An accumulator with anti-windup mechanism
-------------------------------------------------------------------------------
-- Copyright (c) 2022 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2022-05-20  1.0      guilherme.ricioli     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity anti_windup_accumulator is
  generic
  (
    g_A_WIDTH                 : natural;                          -- input width
    g_Q_WIDTH                 : natural;                          -- output width
    g_ANTI_WINDUP_UPPER_LIMIT : signed(31 downto 0);              -- anti-windup upper limit
    g_ANTI_WINDUP_LOWER_LIMIT : signed(31 downto 0)               -- anti-windup lower limit
  );
  port
  (
    clk_i                     : in std_logic;                     -- clock
    rst_n_i                   : in std_logic;                     -- reset

    a_i                       : in signed(g_A_WIDTH-1 downto 0);  -- input a
    clear_i                   : in std_logic;                     -- clear
    sum_i                     : in std_logic;                     -- sum
    q_o                       : out signed(g_Q_WIDTH-1 downto 0); -- output q
    valid_o                   : out std_logic                     -- valid

  );
end anti_windup_accumulator;

architecture behave of anti_windup_accumulator is
  -- constants
  constant MAX_Q              : signed(g_Q_WIDTH-1 downto 0)  := ('0', others => '1');
  constant MIN_Q              : signed(g_Q_WIDTH-1 downto 0)  := ('1', others => '0');

begin

  -- assertions
  assert (g_ANTI_WINDUP_UPPER_LIMIT > g_ANTI_WINDUP_LOWER_LIMIT)
    report "g_ANTI_WINDUP_UPPER_LIMIT <= g_ANTI_WINDUP_LOWER_LIMIT!"
    severity error;

  assert (g_ANTI_WINDUP_UPPER_LIMIT <= MAX_Q)
    report "g_ANTI_WINDUP_UPPER_LIMIT > MAX_Q!"
    severity error;

  assert (g_ANTI_WINDUP_LOWER_LIMIT >= MIN_Q)
    report "g_ANTI_WINDUP_LOWER_LIMIT < MIN_Q!"
    severity error;

  -- processes
  process (clk_i)
    -- q_v is one bit larger than q_o
    variable q_v              : signed(q_o'length downto 0)   := (others => '0');

  begin
    if (rising_edge(clk_i)) then

      if (rst_n_i = '0') then
        q_v := (others => '0');
        valid_o <= '0';

      elsif (clear_i = '1') then
        q_v := (others => '0');
        valid_o <= '0';

      elsif (sum_i = '1') then
        q_v := q_v + a_i;
        -- anti-windup
        if (q_v < g_ANTI_WINDUP_LOWER_LIMIT) then
          q_v := g_ANTI_WINDUP_LOWER_LIMIT(q_o'length downto 0);
        elsif (q_v > g_ANTI_WINDUP_UPPER_LIMIT) then
          q_v := g_ANTI_WINDUP_UPPER_LIMIT(q_o'length downto 0);
        end if;
        valid_o <= '1';

      else
        valid_o <= '0';

      end if;

      q_o <= q_v(q_o'length-1 downto 0);

    end if;
  end process;

end architecture behave;
