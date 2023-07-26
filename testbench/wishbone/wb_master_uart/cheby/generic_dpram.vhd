------------------------------------------------------------------------------
-- Title      : Dual port RAM mockup (simulation only)
------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Created    : 2023-10-19
-- Platform   : Simulation
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: Dual port RAM mockup to be used by cheby's generated code.
--              It doesn't support dual clock, if both sides try to write
--              at the same cycle, it gives preference to port 'A'.
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2023-10-19  1.0      augusto.fraga   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_dpram is

  generic (
    -- standard parameters
    g_data_width : natural := 32;
    g_size       : natural := 16384;

    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := "";
    g_dual_clock               : boolean := true;
    g_fail_if_file_not_found   : boolean := true
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO

    -- Port A
    clka_i : in  std_logic;
    bwea_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qa_o   : out std_logic_vector(g_data_width-1 downto 0) := (others => '0');
    -- Port B

    clkb_i : in  std_logic;
    bweb_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    web_i  : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    db_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0) := (others => '0')
    );

end generic_dpram;

architecture rtl of generic_dpram is
  type t_ram_array is array(natural range <>) of std_logic_vector(g_data_width-1 downto 0);
  signal ram_array: t_ram_array(g_size-1 downto 0) := (others => (others => '0'));
begin
  assert g_dual_clock = false report "Dual clock RAM not supported!"  severity failure;
  process(clka_i)
  begin
    if rising_edge(clka_i) then
      if wea_i = '1' then
        ram_array(to_integer(unsigned(aa_i))) <= da_i;
      elsif web_i = '1' then
        ram_array(to_integer(unsigned(aa_i))) <= db_i;
      end if;
      qa_o <= ram_array(to_integer(unsigned(aa_i)));
      qb_o <= ram_array(to_integer(unsigned(ab_i)));
    end if;
  end process;
end architecture;
