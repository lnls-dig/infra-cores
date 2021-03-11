-------------------------------------------------------------------------------
-- Title      : IOBUF generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : iobuf_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2021-03-11
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Xilinx IOBUF primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-03-11  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity iobuf_generic is
port
(
  -------------------------------
  -- IOBUF facing internal FPGA logic
  -------------------------------
  buffer_i                                  : in  std_logic;
  buffer_o                                  : out std_logic;

  -------------------------------
  -- IOBUF facing external FPGA logic
  -------------------------------
  buffer_b                                  : inout std_logic;

  -------------------------------
  -- IOBUF Controls
  -------------------------------
  buffer_t                                  : in std_logic
);
end entity iobuf_generic;

architecture rtl of iobuf_generic is

begin

   -- buffer_t: 3-state enable input, high=input, low=output
   buffer_b <= buffer_i when buffer_t = '0' else 'Z';
   buffer_o <= buffer_b;

end rtl;
