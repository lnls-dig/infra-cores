library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package platform_generic_pkg is

  --------------------------------------------------------------------
  -- Components
  --------------------------------------------------------------------
  component iobuf_generic
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
  end component;

end platform_generic_pkg;
