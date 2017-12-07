-------------------------------------------------------------------------------
-- Title      : IOBUF generic
-- Project    :
-------------------------------------------------------------------------------
-- File       : iobufds_generic.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-12-07
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Xilinx IOBUFDS primitive generic wrapper
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-12-07  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity iobufds_generic is
--generic
--(
--);
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
  buffer_n_b                                : inout std_logic;

  -------------------------------
  -- IOBUF Controls
  -------------------------------
  buffer_t                                  : in std_logic
);
end entity iobufds_generic;

architecture rtl of iobufds_generic is

begin

   cmp_xilinx_iobufds : iobufds
   generic map (
      DIFF_TERM                            => FALSE,
      IBUF_LOW_PWR                         => TRUE,
      SLEW                                 => "SLOW")
   port map (
      O                                    => buffer_o,     -- Buffer output
      IO                                   => buffer_b,     -- Diff_p inout (connect directly to top-level port)
      IOB                                  => buffer_n_b,   -- Diff_n inout (connect directly to top-level port)
      I                                    => buffer_i,     -- Buffer input
      T                                    => buffer_t      -- 3-state enable input, high=input, low=output
   );

end rtl;
