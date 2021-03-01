-------------------------------------------------------------------------------
-- Title      : IBUFDS generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : ibufds_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2021-03-01
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Xilinx IBUFDS primitive generic wrapper
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

entity ibufds_generic is
port
(
  -------------------------------
  -- IBUFDS facing internal FPGA logic
  -------------------------------
  buffer_o                                  : out std_logic;

  -------------------------------
  -- IBUFDS facing external FPGA logic
  -------------------------------
  buffer_p_i                                : in    std_logic;
  buffer_n_i                                : in    std_logic

);
end entity ibufds_generic;

architecture rtl of ibufds_generic is

begin

   cmp_xilinx_ibufds : ibufds
   generic map (
      IOSTANDARD                           => "DEFAULT",
      IBUF_LOW_PWR                         => FALSE
    )
   port map (
      O                                    => buffer_o,
      I                                    => buffer_p_i,
      IB                                   => buffer_n_i
   );

end rtl;
