-------------------------------------------------------------------------------
-- Title      : OBUFDS generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : obufds_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2021-03-11
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation OBUFDS primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-03-11  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity obufds_generic is
port
(
  -------------------------------
  -- OBUFDS facing internal FPGA logic
  -------------------------------
  buffer_i                                  : in    std_logic;

  -------------------------------
  -- OBUFDS facing external FPGA logic
  -------------------------------
  buffer_p_o                                : out   std_logic;
  buffer_n_o                                : out   std_logic

);
end entity obufds_generic;

architecture rtl of obufds_generic is

begin

   buffer_p_o <= buffer_i;
   buffer_n_o <= not buffer_i;

end rtl;
