--------------------------------------------------------------------------------
-- Title      : Pulse synchronizer
-- Project    :
--------------------------------------------------------------------------------
-- File       : pulse_syncr.vhd
-- Author     : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company    : CNPEM, LNLS - GIE
-- Platform   : Generic
-- Standard   : VHDL'08
--------------------------------------------------------------------------------
-- Description: Holds a pulse and exposes a control signal to release it.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions  :
-- Date         Version  Author              Description
-- 2023-04-19   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_syncr is
  port (
    -- Clock
    clk_i         : in std_logic;

    -- Reset
    rst_n_i       : in std_logic;

    -- Clear held pulse
    clr_i         : in std_logic;

    -- Pulse to hold
    pulse_i       : in std_logic;

    -- Releases held pulse
    -- The held pulse is released in the next clock cycle.
    -- NOTE: A pulse is held even if the last one is being released at the same
    --       clock cycle.
    sync_i        : in std_logic;

    -- Held pulse
    sync_pulse_o  : out std_logic
  );
end pulse_syncr;

architecture beh of pulse_syncr is
  signal pulse : std_logic := '0';
begin
  process (clk_i)
  begin
    if rising_edge(clk_i) then
      sync_pulse_o <= '0';

      if rst_n_i = '0' then
        pulse <= '0';
      else
        if clr_i = '1' then
          pulse <= '0';
        else
          if sync_i = '1' then
            sync_pulse_o <= pulse;
            pulse <= '0';
          end if;

          if pulse_i = '1' then
            pulse <= '1';
          end if;

        end if;
      end if;
    end if;
  end process;
end beh;
