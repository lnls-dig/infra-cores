-------------------------------------------------------------------------------
-- Title      : OBUFDS generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : obufds_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2021-03-01
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Xilinx OBUFDS primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-03-01  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

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

   cmp_xilinx_obufds : obufds
   generic map (
      IOSTANDARD                           => "DEFAULT",
      SLEW                                 => "FAST"
    )
   port map (
      O                                    => buffer_p_o,
      OB                                   => buffer_n_o,
      I                                    => buffer_i
   );

end rtl;
