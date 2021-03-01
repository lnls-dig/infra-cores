-------------------------------------------------------------------------------
-- Title      : IOBUF generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : iobuf_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-11-14
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Xilinx IOBUF primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-11-14  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

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

   cmp_xilinx_iobuf : iobuf
   generic map (
      DRIVE                                => 12,
      IOSTANDARD                           => "DEFAULT",
      SLEW                                 => "SLOW")
   port map (
      O                                    => buffer_o,     -- Buffer output
      IO                                   => buffer_b,     -- Buffer inout port (connect directly to top-level port)
      I                                    => buffer_i,     -- Buffer input
      T                                    => buffer_t      -- 3-state enable input, high=input, low=output
   );

end rtl;
