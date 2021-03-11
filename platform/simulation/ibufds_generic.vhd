-------------------------------------------------------------------------------
-- Title      : IBUFDS generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : ibufds_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2021-03-11
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simulation IBUFDS primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-03-11  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    buffer_o <= buffer_p_i;

end rtl;
