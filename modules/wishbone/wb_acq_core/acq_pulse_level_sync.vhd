------------------------------------------------------------------------------
-- Title      : BPM Pulse to Level and Synchronization
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2015-08-18
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Pulse to level and synchronizer circuits
-------------------------------------------------------------------------------
-- Copyright (c) 2015 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2015-08-18  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- General common cores
use work.gencores_pkg.all;
-- DBE Common cores
use work.ifc_common_pkg.all;
-- Acquisition cores
use work.acq_core_pkg.all;

entity acq_pulse_level_sync is
generic
(
  g_num_inputs                              : natural := 1;
  g_with_pulse_sync                         : t_acq_bool_array;
  g_with_pulse2level                        : t_acq_bool_array
);
port
(
  -- Input pulse clock
  clk_in_i                                  : in  std_logic_vector(g_num_inputs-1 downto 0);
  -- Input pulse reset
  rst_in_n_i                                : in  std_logic_vector(g_num_inputs-1 downto 0);
  -- Synched pulse clock
  clk_out_i                                 : in  std_logic_vector(g_num_inputs-1 downto 0);
  -- Input pulse reset
  rst_out_n_i                               : in  std_logic_vector(g_num_inputs-1 downto 0);

  -- Pulse input
  pulse_i                                   : in std_logic_vector(g_num_inputs-1 downto 0);
  -- Clear level_o
  clr_i                                     : in std_logic_vector(g_num_inputs-1 downto 0);

  -- clk_out_i synched pulse (using full feedback synchronizer)
  pulse_synched_o                           : out std_logic_vector(g_num_inputs-1 downto 0);
  -- level generated by pulse_i and synched with clk_out_i
  level_synched_o                           : out std_logic_vector(g_num_inputs-1 downto 0)
);
end acq_pulse_level_sync;

architecture rtl of acq_pulse_level_sync is

    signal pulse_synched : std_logic_vector(g_num_inputs-1 downto 0);
    signal level_synched : std_logic_vector(g_num_inputs-1 downto 0);

begin

  gen_pulse_synchronizer : for i in 0 to g_num_inputs-1 generate

    gen_with_sync : if (g_with_pulse_sync(i)) generate
      cmp_gc_pulse_synchronizer : gc_pulse_synchronizer
      port map (
        clk_in_i                              => clk_in_i(i),
        rst_n_i                               => rst_in_n_i(i),
        clk_out_i                             => clk_out_i(i),
        d_ready_o                             => open,
        d_p_i                                 => pulse_i(i), -- pulse input
        q_p_o                                 => pulse_synched(i) -- pulse output
      );
    end generate;

    gen_without_sync : if (not g_with_pulse_sync(i)) generate
      pulse_synched(i) <= pulse_i(i);
    end generate;

    pulse_synched_o(i) <= pulse_synched(i);

    gen_with_level : if (g_with_pulse2level(i)) generate
      cmp_pulse_to_level : pulse2level
      port map
      (
        clk_i                                  => clk_out_i(i),
        rst_n_i                                => rst_out_n_i(i),

        pulse_i                                => pulse_synched(i),
        clr_i                                  => clr_i(i),
        level_o                                => level_synched(i)
      );
    end generate;

    gen_without_level : if (not g_with_pulse2level(i)) generate
      level_synched(i) <= pulse_synched(i);
    end generate;

    level_synched_o(i) <= level_synched(i);

  end generate;

end rtl;
