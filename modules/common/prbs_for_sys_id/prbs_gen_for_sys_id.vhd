--------------------------------------------------------------------------------
-- Title      : PRBS for system identification.
-- Project    :
--------------------------------------------------------------------------------
-- File       : prbs_gen_for_sys_id.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Generic
-- Standard   : VHDL'08
--------------------------------------------------------------------------------
-- Description: prbs_gen wrapper adding configurable step duration.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-03-29   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.ifc_common_pkg.all;

entity prbs_gen_for_sys_id is

  port (
    -- Clock
    clk_i           : in std_logic;

    -- Reset
    rst_n_i         : in std_logic;

    -- Enable. This signal enables the PRBS iteration. When en_i = '0', valid_i
    -- is ignored.
    en_i            : in std_logic;

    -- Duration of each PRBS step (in valid_i counts)
    -- NOTE: Changing this signal resets the internal counter. valid_i is ignored
    --       in this cycle.
    step_duration_i : in natural range 1 to 1024 := 1;

    -- Length (in bits) of internal LFSR. This determines the duration of the
    -- generated sequence, which is given by: (2^{lfsr_length_i} - 1)*step_duration_i
    -- NOTE: Changing this signal resets the internal LFSR. valid_i is ignored
    --       in this cycle.
    lfsr_length_i   : in natural range 2 to 32 := 32;

    -- Signal for iterating the PRBS
    valid_i         : in std_logic;

    -- Busy indicator flag. While busy, valid_i is completely ignored.
    busy_o          : out std_logic;

    -- PRBS signal
    prbs_o          : out std_logic;

    -- PRBS valid signal
    valid_o         : out std_logic
  );

end entity prbs_gen_for_sys_id;

architecture beh of prbs_gen_for_sys_id is

  -- types
  type t_state is (DRIVE_PRBS_ITERATION, FETCH_NEXT_PRBS_BIT, WAIT_STEP_DURATION);

  -- signals
  signal step_duration_d1       : natural := 0;
  signal iterate_prbs_gen       : std_logic := '0';
  signal prbs, prbs_d1          : std_logic := '0';
  signal valid_prbs_gen         : std_logic := '0';
  signal state                  : t_state := DRIVE_PRBS_ITERATION;

begin

  -- processes
  process(clk_i) is
    variable v_count : natural := 0;
  begin
    if rising_edge(clk_i) then
      busy_o <= '0';
      iterate_prbs_gen <= '0';
      valid_o <= '0';

      if rst_n_i = '0' or step_duration_i /= step_duration_d1 then
        busy_o <= '1';

        state <= DRIVE_PRBS_ITERATION;
      else
        case state is
          -- This state is only reached after resetting or changing the PRBS
          -- step duration
          when DRIVE_PRBS_ITERATION =>
            busy_o <= '1';
            iterate_prbs_gen <= '1';

            v_count := 0;
            state <= FETCH_NEXT_PRBS_BIT;
          when FETCH_NEXT_PRBS_BIT =>
            if valid_prbs_gen = '1' then
              -- Stores the fetched PRBS bit
              prbs_d1 <= prbs;

              state <= WAIT_STEP_DURATION;
            else
              busy_o <= '1';
            end if;
          when WAIT_STEP_DURATION =>
            if en_i = '1' then
              if valid_i = '1' then
                prbs_o <= prbs_d1;
                valid_o <= '1';

                v_count := v_count + 1;

                if v_count = step_duration_i then
                  busy_o <= '1';
                  iterate_prbs_gen <= '1';

                  v_count := 0;
                  state <= FETCH_NEXT_PRBS_BIT;
                end if;
              end if;
            end if;
        end case;
      end if;

      -- Registers step_duration_i so to check if it changes
      step_duration_d1 <= step_duration_i;
    end if;
  end process;

  inst_prbs_gen : prbs_gen
    port map (
      clk_i     => clk_i,
      rst_n_i   => rst_n_i,
      length_i  => lfsr_length_i,
      valid_i   => iterate_prbs_gen,
      prbs_o    => prbs,
      valid_o   => valid_prbs_gen
    );

end architecture beh;
