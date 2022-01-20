-------------------------------------------------------------------------------
-- Title      : VIO stub
-------------------------------------------------------------------------------
-- File       : vio_din2_w128_dout2_w128.vhd
-- Author     : Augusto Fraga Giachero <augusto.fraga@lnls.br>
-- Company    :
-- Created    : 2022-01-20
-- Last update:
-- Platform   : Simulation
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: VIO stub to avoid simulation errors when testing cores
-- that make optional use of the Xilinx VIO core
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author         Description
-- 2022-01-20  1.0      augusto.fraga  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity vio_din2_w128_dout2_w128 is
  port (
    clk : in std_logic;
    probe_in0 : in std_logic_vector (127 downto 0);
    probe_in1 : in std_logic_vector (127 downto 0);
    probe_out0 : out std_logic_vector (127 downto 0);
    probe_out1 : out std_logic_vector (127 downto 0)
  );
end vio_din2_w128_dout2_w128;

architecture rtl of vio_din2_w128_dout2_w128 is
begin
end architecture rtl;
