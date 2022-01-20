-------------------------------------------------------------------------------
-- Title      : ILA stub
-------------------------------------------------------------------------------
-- File       : ila_t8_d256_s8192_cap.vhd
-- Author     : Augusto Fraga Giachero <augusto.fraga@lnls.br>
-- Company    :
-- Created    : 2022-01-20
-- Last update:
-- Platform   : Simulation
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: ILA stub to avoid simulation errors when testing cores
-- that make optional use of the Xilinx ILA core
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author         Description
-- 2022-01-20  1.0      augusto.fraga  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity ila_t8_d256_s8192_cap is
  port (
    clk : in std_logic;
    probe0 : in std_logic_vector (255 downto 0);
    probe1 : in std_logic_vector (7 downto 0)
  );
end ila_t8_d256_s8192_cap;

architecture rtl of ila_t8_d256_s8192_cap is
begin
end architecture rtl;
