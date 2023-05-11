--------------------------------------------------------------------------------
-- Title      : Dynamic moving average filter
-- Project    :
--------------------------------------------------------------------------------
-- File       : mov_avg_dyn.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Generic
-- Standard   : VHDL'08
--------------------------------------------------------------------------------
-- Description: A moving average filter with dynamic order setting.
--
--              This core only supports orders which the number of taps of
--              resulting FIR (order + 1) is a power of 2. The reason for that
--              is so we can perfom divisions by simply shifting the fixed point
--              to the left.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-05-12   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mov_avg_dyn is
  generic (
    -- Maximum order
    -- The maximum order being selected is given by '2**g_MAX_ORDER_SEL - 1'
    g_MAX_ORDER_SEL : natural := 4;

    -- Data width
    g_DATA_WIDTH    : natural := 32
  );
  port (
    -- Clock
    clk_i           : in std_logic;

    -- Reset
    rst_n_i         : in std_logic;

    -- Order selector
    -- The order being selected is given by '2**order_sel_i - 1'
    -- NOTE: Changing this resets the internal state.
    order_sel_i     : in natural range 0 to g_MAX_ORDER_SEL := 0;

    -- Data
    data_i          : in signed(g_DATA_WIDTH-1 downto 0);

    -- Valid for data (data_i)
    valid_i         : in std_logic;

    -- Averaged data
    avgd_data_o     : out signed(g_DATA_WIDTH-1 downto 0);

    -- Valid for averaged data (avgd_data_o)
    valid_o         : out std_logic
  );
end entity mov_avg_dyn;

architecture beh of mov_avg_dyn is
  type t_data_arr is array (natural range <>) of signed(g_DATA_WIDTH-1 downto 0);

  function f_compute_order(order_sel : natural range 0 to g_MAX_ORDER_SEL) return natural is
  begin
    return to_integer(shift_left(to_unsigned(1, g_MAX_ORDER_SEL+1), order_sel)) - 1;
  end function;

  constant c_MAX_ORDER : natural := f_compute_order(g_MAX_ORDER_SEL);

  signal order_sel_d1 : natural range 0 to g_MAX_ORDER_SEL := 0;
  signal valid_d1 : std_logic := '0';

  -- Sample time n:
  --  data[n - 1] + data[n - 2] + ... + data[n - order] + data[n - (order + 1)]
  signal accumulator : signed(g_MAX_ORDER_SEL+g_DATA_WIDTH-1 downto 0) := (others => '0');

  -- Sample time n:
  --  data[n - 1], data[n - 2], ..., data[n - c_MAX_ORDER], data[n - (c_MAX_ORDER + 1)]
  -- NOTE: To simplify things, use index range from 1 to c_MAX_ORDER so
  --       delayed_data_arr[order] holds data[n - order].
  signal delayed_data_arr : t_data_arr(c_MAX_ORDER+1 downto 1) := (others => (others => '0'));
begin
  process(clk_i) is
    variable order : natural := 0;
  begin
    if rising_edge(clk_i) then
      order := f_compute_order(order_sel_i);

      if rst_n_i = '0' then
        valid_d1 <= '0';
        accumulator <= (others => '0');
        delayed_data_arr <= (others => (others => '0'));
      elsif order_sel_i /= order_sel_d1 then
        -- Accumulator and delayed taps must be cleared when order is changed.
        -- Otherwise, we never get rid of accumulated taps when decreasing the
        -- order.
        valid_d1 <= '0';
        accumulator <= (others => '0');
        delayed_data_arr <= (others => (others => '0'));
      elsif valid_i = '1' then
        -- ##################### MOVING AVERAGE 1ST STAGE #####################
        -- Sample time n + 1 cc (clock cycle):
        --  data[n] + data[n - 1] + data[n - 2] + ... + data[n - (order - 1)] + data[n - order]
        accumulator <= accumulator + data_i - delayed_data_arr(order+1);

        -- Sample time n + 1 cc:
        --  data[n], data[n - 1], ..., data[n - (c_MAX_ORDER - 1)], data[n - c_MAX_ORDER]
        delayed_data_arr(1) <= data_i;
        for i in 2 to c_MAX_ORDER+1 loop
          delayed_data_arr(i) <= delayed_data_arr(i-1);
        end loop;
        -- #####################################################################
      end if;
      valid_d1 <= valid_i;

      -- ###################### MOVING AVERAGE 2ND STAGE ######################
      -- Sample time n + 1 cc:
      --  (data[n] + data[n - 1] + data[n - 2] + ... + data[n - order])/(order + 1)
      avgd_data_o <= accumulator(order_sel_i+g_DATA_WIDTH-1 downto order_sel_i);
      valid_o <= valid_d1;
      -- ######################################################################

      -- Registers order_sel_i so to check if it changes
      order_sel_d1 <= order_sel_i;
    end if;
  end process;
end architecture beh;
