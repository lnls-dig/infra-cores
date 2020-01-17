------------------------------------------------------------------------------
-- Title      : Acquisition Select Channel
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2013-06-11
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Simple MUX for selecting an acquisition channel. Basically a
--               1 clock cycle latency MUX
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2014-21-07  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.acq_core_pkg.all;

entity acq_sel_chan is
generic
(
  g_acq_num_channels                        : natural := 1;
  g_acq_data_width                          : natural := c_acq_chan_max_w
);
port
(
  clk_i                                     : in  std_logic;
  rst_n_i                                   : in  std_logic;

-----------------------------
-- Acquisiton Interface
-----------------------------
  acq_val_low_i                             : in t_acq_val_half_array(g_acq_num_channels-1 downto 0);
  acq_val_high_i                            : in t_acq_val_half_array(g_acq_num_channels-1 downto 0);
  acq_dvalid_i                              : in std_logic_vector(g_acq_num_channels-1 downto 0);
  acq_id_i                                  : in t_acq_id_array(g_acq_num_channels-1 downto 0);
  acq_trig_i                                : in std_logic_vector(g_acq_num_channels-1 downto 0);

  -- Current channel selection ID
  lmt_curr_chan_id_i                        : in unsigned(c_chan_id_width-1 downto 0);
  -- Acquisition limits valid signal
  lmt_valid_i                               : in std_logic;

-----------------------------
-- Output Interface.
-----------------------------
  acq_data_o                                : out std_logic_vector(g_acq_data_width-1 downto 0);
  acq_dvalid_o                              : out std_logic;
  acq_id_o                                  : out t_acq_id;
  acq_trig_o                                : out std_logic
);
end acq_sel_chan;

architecture rtl of acq_sel_chan is

  signal lmt_valid                          : std_logic;
  signal lmt_curr_chan_id                   : unsigned(c_chan_id_width-1 downto 0);

  signal acq_data_marsh_demux               : std_logic_vector(g_acq_data_width-1 downto 0);
  signal acq_trig_demux                     : std_logic;
  signal acq_dvalid_demux                   : std_logic;
  signal acq_id_demux                       : t_acq_id;

  signal acq_data_marsh_demux_reg           : std_logic_vector(g_acq_data_width-1 downto 0);
  signal acq_trig_demux_reg                 : std_logic;
  signal acq_dvalid_demux_reg               : std_logic;
  signal acq_id_demux_reg                   : t_acq_id;

begin

  p_reg_lmt_iface : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        lmt_valid <= '0';
        lmt_curr_chan_id <= to_unsigned(0, lmt_curr_chan_id'length);
      else
        lmt_valid <= lmt_valid_i;

        if lmt_valid_i = '1' then
          lmt_curr_chan_id <= lmt_curr_chan_id_i;
        end if;
      end if;
    end if;
  end process;

 acq_data_marsh_demux                   <=
    f_acq_chan_conv_val(f_acq_chan_marshall_val(acq_val_high_i(to_integer(lmt_curr_chan_id)),
                                                acq_val_low_i(to_integer(lmt_curr_chan_id))));
 acq_trig_demux                         <= acq_trig_i(to_integer(lmt_curr_chan_id));
 acq_dvalid_demux                       <= acq_dvalid_i(to_integer(lmt_curr_chan_id));
 acq_id_demux                           <= acq_id_i(to_integer(lmt_curr_chan_id));

 p_reg_demux : process (clk_i)
 begin
   if rising_edge(clk_i) then
     if rst_n_i = '0' then
       acq_data_marsh_demux_reg <= (others => '0');
       acq_dvalid_demux_reg <= '0';
       acq_id_demux_reg <= to_unsigned(0, acq_id_demux_reg'length);
       acq_trig_demux_reg <= '0';
     else
       acq_data_marsh_demux_reg <= acq_data_marsh_demux;
       acq_dvalid_demux_reg <= acq_dvalid_demux;
       acq_id_demux_reg <= acq_id_demux;
       acq_trig_demux_reg <= acq_trig_demux;
     end if;
   end if;
 end process;

 acq_data_o                               <= acq_data_marsh_demux_reg;
 acq_dvalid_o                             <= acq_dvalid_demux_reg;
 acq_id_o                                 <= acq_id_demux_reg;
 acq_trig_o                               <= acq_trig_demux_reg;

end rtl;
