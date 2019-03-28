------------------------------------------------------------------------------
-- Title      : Acquisition Trigger Logic
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2015-19-08
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Acquisition trigger logic for hardware trigger (external and data),
--               alignment and delay balancing (for trigger detection)
-------------------------------------------------------------------------------
-- Copyright (c) 2015 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2015-19-08  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

-- The trigger detection and selection was based on on FMC-ADC-100M
-- (http://www.ohwr.org/projects/fmc-adc-100m14b4cha/repository), specifically
-- the fmc_adc_100Ms_core.vhd file

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.acq_core_pkg.all;
use work.gencores_pkg.all;
use work.genram_pkg.all;

entity acq_trigger is
generic
(
  g_data_in_width                           : natural := 128;
  g_acq_num_channels                        : natural := 5;
  g_ddr_payload_width                       : natural := 256;
  g_trig_cnt_off_width                      : natural := 8;
  g_acq_channels                            : t_acq_chan_param_array := c_default_acq_chan_param_array
);
port
(
  fs_clk_i                                  : in std_logic;
  fs_ce_i                                   : in std_logic;
  fs_rst_n_i                                : in std_logic;

  -- Trigger inputs
  cfg_hw_trig_sel_i                         : in std_logic;
  cfg_hw_trig_pol_i                         : in std_logic;
  cfg_hw_trig_en_i                          : in std_logic;
  cfg_sw_trig_t_i                           : in std_logic;
  cfg_sw_trig_en_i                          : in std_logic;
  cfg_trig_dly_i                            : in std_logic_vector(31 downto 0);
  cfg_int_trig_sel_i                        : in std_logic_vector(4 downto 0);
  cfg_int_trig_thres_i                      : in std_logic_vector(31 downto 0);
  cfg_int_trig_thres_filt_i                 : in std_logic_vector(7 downto 0);

  -- Data-driven data input
  dtrig_data_i                              : in std_logic_vector(g_data_in_width-1 downto 0);
  dtrig_valid_i                             : in std_logic;
  dtrig_id_i                                : in t_acq_id;

  -- Data-driven trigger channel selection ID
  lmt_dtrig_chan_id_i                       : in unsigned(c_chan_id_width-1 downto 0);
  -- Acquisition limits valid signal
  lmt_dtrig_valid_i                         : in std_logic;

  -- Acquisition input
  acq_data_i                                : in std_logic_vector(g_data_in_width-1 downto 0);
  acq_valid_i                               : in std_logic;
  acq_id_i                                  : in t_acq_id;
  acq_trig_i                                : in std_logic;

  -- Current channel selection ID
  lmt_curr_chan_id_i                        : in unsigned(c_chan_id_width-1 downto 0);
  -- Acquisition limits valid signal
  lmt_valid_i                               : in std_logic;

  -- Acquisition data with data + metadata
  acq_wr_en_i                               : in std_logic;
  acq_data_o                                : out std_logic_vector(g_data_in_width-1 downto 0);
  acq_valid_o                               : out std_logic;
  acq_id_o                                  : out t_acq_id;
  acq_trig_o                                : out std_logic;
  acq_trig_cnt_off_o                        : out unsigned(g_trig_cnt_off_width-1 downto 0)
);
end acq_trigger;

architecture rtl of acq_trigger is
  -- Constants
  constant c_narrowest_atom_width           : natural := f_acq_chan_find_narrowest_atom(g_acq_channels);
  constant c_widest_atom_width              : natural := f_acq_chan_find_widest_atom(g_acq_channels);

  constant c_narrowest_num_atoms            : natural := f_acq_chan_find_narrowest_num_atoms(g_acq_channels);
  constant c_widest_num_atoms               : natural := f_acq_chan_find_widest_num_atoms(g_acq_channels);

  constant c_narrowest_channel_width        : natural := f_acq_chan_find_narrowest(g_acq_channels);

  --constant c_trigger_align_samples          : natural := g_ddr_payload_width/c_narrowest_channel_width;
  constant c_trigger_coalesce_align         : natural := f_acq_chan_find_widest_num_coalesce(g_acq_channels);
  constant c_trigger_ddr_payload_align      : natural := g_ddr_payload_width/c_narrowest_channel_width;
  constant c_trigger_align_samples          : natural := max(c_trigger_coalesce_align, c_trigger_ddr_payload_align);
  constant c_trigger_align_width            : natural := f_log2_size(c_trigger_align_samples);

  constant c_int_data_hysteresis_depth      : natural := 8;
  constant c_pipe_depth                     : natural := 5;

  -- Caution here! We must calculate the internal delay detection
  -- and change it here. Failure to do so will result in trigger misalignment
  constant c_trig_det_delay                 : natural := 5;

  constant c_num_atoms_array                : t_property_value_array(g_acq_channels'length-1 downto 0) :=
      f_extract_property_array(g_acq_channels, NUM_ATOMS);
  constant c_atom_width_array               : t_property_value_array(g_acq_channels'length-1 downto 0) :=
      f_extract_property_array(g_acq_channels, ATOM_WIDTH);
  constant c_num_coalesce_array             : t_property_value_array(g_acq_channels'length-1 downto 0) :=
      f_extract_property_array(g_acq_channels, NUM_COALESCE);

  constant c_num_atoms_uncoalesced_array    : t_property_value_array(g_acq_channels'length-1 downto 0) :=
      f_divide_array(c_num_atoms_array, c_num_coalesce_array);
  constant c_num_atoms_uncoalesced_log2_array
                                            : t_property_value_array(g_acq_channels'length-1 downto 0) :=
                                            f_log2_size_array(c_num_atoms_uncoalesced_array);

  constant c_acq_chan_slice                 : t_acq_chan_slice_array(g_acq_num_channels-1 downto 0) :=
                                                 f_acq_chan_det_slice(g_acq_channels);
  constant c_fc_payload_ratio               : t_payld_ratio_array(g_acq_num_channels-1 downto 0) :=
                                                   f_fc_payload_ratio (g_ddr_payload_width,
                                                                c_acq_chan_slice);

  -- Minimum required alignment for each data stream
  constant c_min_align_array                : t_property_value_array(g_acq_num_channels-1 downto 0) :=
                                                   f_max_align_array(c_num_coalesce_array,
                                                                 c_fc_payload_ratio);

  -- Types
  subtype t_acq_atom is std_logic_vector(c_widest_atom_width-1 downto 0);
  type t_acq_atom_array is array (natural range <>) of t_acq_atom;
  type t_acq_atom_array2d is array (natural range <>, natural range <>) of t_acq_atom;
  type t_data_pipe is array (natural range <>) of std_logic_vector(g_data_in_width-1 downto 0);
  type t_valid_pipe is array (natural range <>) of std_logic;
  type t_id_pipe is array (natural range <>) of t_acq_id;

  -- Signals
  signal lmt_dtrig_chan_id                  : unsigned(c_chan_id_width-1 downto 0);
  signal lmt_dtrig_valid                    : std_logic;
  signal lmt_curr_chan_id                   : unsigned(c_chan_id_width-1 downto 0);
  signal lmt_valid                          : std_logic;

  signal dtrig_data_in                      : std_logic_vector(g_data_in_width-1 downto 0);
  signal dtrig_valid_in                     : std_logic;
  signal dtrig_id_in                        : t_acq_id;

  signal acq_curr_coalesce_id               : integer;
  signal acq_data_in                        : std_logic_vector(g_data_in_width-1 downto 0);
  signal acq_data_sel_out                   : std_logic_vector(g_data_in_width-1 downto 0);
  signal acq_data_out                       : std_logic_vector(g_data_in_width-1 downto 0);
  signal acq_atoms                          : t_acq_atom_array2d(g_acq_num_channels-1 downto 0,
                                                c_widest_num_atoms-1 downto 0) :=
                                                (others => (others => (others => '0')));

  signal acq_num_atoms                      : t_acq_num_atoms;
  signal acq_num_atoms_uncoalesced          : t_acq_num_atoms := to_unsigned(2, t_acq_num_atoms'length);
  signal acq_num_atoms_uncoalesced_log2     : t_acq_num_atoms := to_unsigned(2, t_acq_num_atoms'length);
  signal acq_valid_in                       : std_logic;
  signal acq_id_in                          : t_acq_id;
  signal acq_valid_sel_out                  : std_logic;
  signal acq_id_sel_out                     : t_acq_id;
  signal acq_valid_out                      : std_logic;
  signal acq_id_out                         : t_acq_id;

  signal acq_data_pipe                      : t_data_pipe(c_pipe_depth-1 downto 0);
  signal acq_valid_pipe                     : t_valid_pipe(c_pipe_depth-1 downto 0);
  signal acq_id_pipe                        : t_id_pipe(c_pipe_depth-1 downto 0);
  signal acq_trig                           : std_logic;
  signal acq_trig_sel_out                   : std_logic;
  signal acq_trig_out                       : std_logic;
  signal acq_trig_align_cnt                 : unsigned(c_trigger_align_width-1 downto 0);
  signal acq_trig_align_cnt_en              : std_logic;
  signal acq_min_align_max                  : unsigned(c_trigger_align_width-1 downto 0);

  signal int_trig                           : std_logic;
  signal int_trig_over_thres                : std_logic;
  signal int_trig_over_thres_filt           : std_logic;
  signal int_trig_over_thres_filt_d         : std_logic;
  signal int_trig_data                      : std_logic_vector(c_widest_atom_width-1 downto 0);
  signal int_trig_data_se                   : std_logic_vector(c_widest_atom_width-1 downto 0);
  signal hw_trig                            : std_logic;
  signal hw_trig_t                          : std_logic;
  signal sw_trig                            : std_logic;
  signal sw_trig_t                          : std_logic;
  signal sw_trig_en                         : std_logic;
  signal trig                               : std_logic;
  signal trig_delay                         : std_logic_vector(31 downto 0);
  signal trig_delay_cnt                     : unsigned(31 downto 0);
  signal trig_cnt_off                       : unsigned(g_trig_cnt_off_width-1 downto 0);
  signal trig_d                             : std_logic;
  signal trig_unaligned                     : std_logic;
  signal trig_align                         : std_logic;
  signal trig_cnt_off_captured              : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Input Register Logic
  -----------------------------------------------------------------------------

  p_reg_lmt_dtrig_iface : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        lmt_dtrig_valid <= '0';
        lmt_dtrig_chan_id <= to_unsigned(0, lmt_dtrig_chan_id'length);
      else
        lmt_dtrig_valid <= lmt_dtrig_valid_i;

        if lmt_dtrig_valid_i = '1' then
          lmt_dtrig_chan_id <= lmt_dtrig_chan_id_i;
        end if;
      end if;
    end if;
  end process;

  p_reg_lmt_iface : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        lmt_valid <= '0';
        lmt_curr_chan_id <= to_unsigned(0, lmt_curr_chan_id'length);
        acq_num_atoms <= to_unsigned(0, acq_num_atoms'length);
        acq_num_atoms_uncoalesced <= to_unsigned(0, acq_num_atoms_uncoalesced'length);
        acq_num_atoms_uncoalesced_log2 <= to_unsigned(0, acq_num_atoms_uncoalesced_log2'length);
        acq_min_align_max <= to_unsigned(0, acq_min_align_max'length);
      else
        lmt_valid <= lmt_valid_i;

        if lmt_valid_i = '1' then
          lmt_curr_chan_id <= lmt_curr_chan_id_i;
          -- prepare the maximun fifo index to be used by the current channel
          acq_num_atoms <= to_unsigned(c_num_atoms_array(to_integer(lmt_curr_chan_id_i)),
                                acq_num_atoms'length);
          acq_num_atoms_uncoalesced <= to_unsigned(c_num_atoms_uncoalesced_array(to_integer(lmt_curr_chan_id_i)),
                                acq_num_atoms_uncoalesced'length);
          acq_num_atoms_uncoalesced_log2 <= to_unsigned(c_num_atoms_uncoalesced_log2_array(to_integer(lmt_curr_chan_id_i)),
                                acq_num_atoms_uncoalesced_log2'length);
          acq_min_align_max <= to_unsigned(c_min_align_array(to_integer(lmt_curr_chan_id_i)),
                                acq_min_align_max'length) - 1;
      else
        end if;
      end if;
    end if;
  end process;

  p_reg_dtrig_data_in : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        dtrig_data_in <= (others => '0');
        dtrig_id_in <= to_unsigned(0, dtrig_id_in'length);
        dtrig_valid_in <= '0';
      else
        dtrig_valid_in <= dtrig_valid_i;

        if dtrig_valid_i = '1' then
          dtrig_data_in <= dtrig_data_i;
          dtrig_id_in <= dtrig_id_i;
        end if;
      end if;
    end if;
  end process;

  p_reg_data_in : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        acq_data_in <= (others => '0');
        acq_valid_in <= '0';
        acq_id_in <= to_unsigned(0, acq_id_in'length);
      else
        acq_valid_in <= acq_valid_i;

        if acq_valid_i = '1' then
          acq_data_in <= acq_data_i;
          acq_id_in <= acq_id_i;
        end if;
      end if;
    end if;
  end process;

  -- Prepare slices for all atoms in the channels
  gen_channels_prop : for i in 0 to g_acq_num_channels-1 generate -- for all input channels

      -- The effective number of atoms is the number of atoms in a single word,
      -- not in the aggregated stream. So, we must consider only the uncoalesced
      -- number of atoms.
      gen_channel_atoms : for j in 0 to c_num_atoms_uncoalesced_array(i)-1 generate -- for all uncoalesced atoms
        -- with sign extension
        acq_atoms(i,j) <=
        std_logic_vector(resize(signed(dtrig_data_in(c_atom_width_array(i)*(j+1)-1 downto
                                c_atom_width_array(i)*j)), acq_atoms(i,j)'length));
    end generate;

  end generate;

  -----------------------------------------------------------------------------
  -- Trigger Logic
  -----------------------------------------------------------------------------

  -- Internal hardware trigger
  -- Get the coalesced data packet ID of the Data Trigger channel
  --int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id(to_integer(acq_num_atoms_uncoalesced_log2)-1 downto 0)),
  --                 to_integer(unsigned(cfg_int_trig_sel_i)));

  -- Problem: Vivado 2015.2 does not support dynamic slicing!
  -- Solution: Implement a case statement to address each possible slice

  p_int_trig_data : process(acq_num_atoms_uncoalesced_log2)
  begin
     case to_integer(acq_num_atoms_uncoalesced_log2) is
       when 0 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(0 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 0)));
       when 1 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(0 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 1)));
       when 2 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(1 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 2)));
       when 3 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(2 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 3)));
       when 4 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(3 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 4)));
       when 5 =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(4 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 4)));
       when others =>
         int_trig_data <= acq_atoms(to_integer(lmt_dtrig_chan_id),
                          to_integer(unsigned(cfg_int_trig_sel_i(0 downto 0))));
         acq_curr_coalesce_id <= to_integer(unsigned(cfg_int_trig_sel_i(cfg_int_trig_sel_i'length-1 downto 0)));
     end case;
  end process;

  -- Sign extend data according to the selected channel
  p_int_trig_sign_extend : process (fs_clk_i)
    variable v_atom_width : t_property_value;
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        int_trig_data_se <= (others => '0');
      else
        -- Get only the uncoalesced part of the Data Trigger channel ID
        if acq_curr_coalesce_id = dtrig_id_in then
          int_trig_data_se <= int_trig_data;
        end if;
      end if;
    end if;
  end process;

  -- Detects input data going over the internal trigger threshold
  p_int_trig : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        int_trig_over_thres <= '0';
      else
        if signed(int_trig_data_se) > signed(cfg_int_trig_thres_i) then
          int_trig_over_thres <= '1';
        else
          int_trig_over_thres <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Filters out glitches from over threshold signal (rejects noise around the threshold -> hysteresis)
  cmp_dyn_glitch_filt : gc_dyn_glitch_filt
  generic map
  (
    g_len_width => c_int_data_hysteresis_depth
  )
  port map
  (
    clk_i   => fs_clk_i,
    rst_n_i => fs_rst_n_i,
    len_i   => cfg_int_trig_thres_filt_i(c_int_data_hysteresis_depth-1 downto 0),
    dat_i   => int_trig_over_thres,
    dat_o   => int_trig_over_thres_filt
  );

  -- Detects whether it's a positive or negative slope
  p_int_trig_slope : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        int_trig_over_thres_filt_d <= '0';
      else
        int_trig_over_thres_filt_d <= int_trig_over_thres_filt;
      end if;
    end if;
  end process;

  int_trig <= int_trig_over_thres_filt and not(int_trig_over_thres_filt_d) when cfg_hw_trig_pol_i = '0' else  -- positive slope
              not(int_trig_over_thres_filt) and int_trig_over_thres_filt_d;                             -- negative slope

  -- Hardware trigger selection
  --    internal = data threshold
  --    external = external pulse
  hw_trig_t <= acq_trig_i when cfg_hw_trig_sel_i = '1' else int_trig;

  -- Hardware trigger enable
  hw_trig <= hw_trig_t and cfg_hw_trig_en_i;

  -- Software trigger enable
  sw_trig <= cfg_sw_trig_t_i and cfg_sw_trig_en_i;

  -- Trigger sources ORing
  trig <= sw_trig or hw_trig;

  -- Trigger delay
  p_trig_delay_cnt : process(fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        trig_delay_cnt <= (others => '0');
      else
        if trig = '1' then
          trig_delay_cnt <= unsigned(cfg_trig_dly_i);
        elsif trig_delay_cnt /= 0 then
          trig_delay_cnt <= trig_delay_cnt - 1;
        end if;
      end if;
    end if;
  end process;

  p_trig_delay : process(fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        trig_d <= '0';
      else
        if cfg_trig_dly_i = X"00000000" then
          if trig = '1' then
            trig_d <= '1';
          else
            trig_d <= '0';
          end if;
        else
          if trig_delay_cnt = X"00000001" then
            trig_d <= '1';
          else
            trig_d <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Count number of valid samples transfered up to the alignment value.
  -- Note that the counter will wraparound.
  p_trig_align_counter : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        acq_trig_align_cnt <= to_unsigned(0, acq_trig_align_cnt'length);
      else
        if acq_trig_align_cnt_en = '1' then
          -- Increment the alignment (between input data and aggregated data
          -- for DDR memory) counter
          acq_trig_align_cnt <= acq_trig_align_cnt + 1;

          if acq_trig_align_cnt = acq_min_align_max then
            acq_trig_align_cnt <= to_unsigned(0, acq_trig_align_cnt'length);
         end if;
        end if;
      end if;
    end if;
  end process;

  -- Only count while we are acquiring data, not before nor after. This is
  -- necessary to acquire the desired alignment.
  -- FIXME: here we are relying on the precise delay between "acq_valid_out"
  -- and "acq_wr_en_i" signals, which are not clearly related
  acq_trig_align_cnt_en <= acq_valid_out and acq_wr_en_i;

  -- Hold trigger signal until a we are aligned and a valid sample is found.
  -- The aligned term here refers to the first atom of a channel sample
  -- (composed of atoms). For instance, if the channel is composed of 4 atoms,
  -- the last channel atom would be number 3.
  p_trig_align : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        trig_unaligned <= '0';
        trig_align <= '0';
        trig_cnt_off <= to_unsigned(0, trig_cnt_off'length);
        trig_cnt_off_captured <= '0';
      else
        if trig_d = '1' and trig_cnt_off_captured = '0' then
          trig_unaligned <= '1';
        -- Trigger captured
        elsif trig_align = '1' then
          trig_unaligned <= '0';
          trig_cnt_off_captured <= '0';
        end if;

        -- Wait until we have transfered the correct (aligned) number of samples
        -- to output trigger.
        --
        -- By design acq_min_align_max would be at least 1, meaning a channel
        -- composed of 2 atoms. So the arithmetic acq_min_align_max-1 yields
        -- valid values in all cases.
        if trig_d = '1' or trig_unaligned = '1' then
          if acq_trig_align_cnt = acq_min_align_max and acq_valid_sel_out = '1' then -- will increment to the first atom
            trig_align <= '1'; -- Output trigger aligned with the first atom
          end if;

          -- Acquire offset from trigger only once per transaction
          if trig_cnt_off_captured = '0' then
            trig_cnt_off <= resize(acq_min_align_max - acq_trig_align_cnt, trig_cnt_off'length);
            trig_cnt_off_captured <= '1';
          end if;

        elsif acq_valid_sel_out = '1' then
          trig_align <= '0';
        end if;
      end if;
    end if;
  end process;

  acq_trig_cnt_off_o <= trig_cnt_off;

  -- Delay data to compensate for internal trigger detection
  p_data_delay : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        acq_data_pipe <= (others => (others => '0'));
        acq_valid_pipe <= (others => '0');
        acq_id_pipe <= (others => (others => '0'));
      else
        acq_data_pipe <= acq_data_pipe(acq_data_pipe'left-1 downto 0) & acq_data_in;
        acq_valid_pipe <= acq_valid_pipe(acq_valid_pipe'left-1 downto 0) & acq_valid_in;
        acq_id_pipe <= acq_id_pipe(acq_valid_pipe'left-1 downto 0) & acq_id_in;
      end if;
    end if;
  end process;

  -- An additional c_trig_det_delay fs_clk period delay is added when internal
  -- hw trigger is selected
  acq_data_sel_out <= acq_data_pipe(c_trig_det_delay-1) when cfg_hw_trig_sel_i = '0' else
                    acq_data_in;
  acq_valid_sel_out <= acq_valid_pipe(c_trig_det_delay-1) when cfg_hw_trig_sel_i = '0' else
                    acq_valid_in;
  acq_id_sel_out <= acq_id_pipe(c_trig_det_delay-1) when cfg_hw_trig_sel_i = '0' else
                    acq_id_in;
  acq_trig_sel_out <= trig_align;

  ------------------------------------------------------------------------------
  -- Output Logic
  -----------------------------------------------------------------------------

  p_reg_trig_data : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        acq_data_out <= (others => '0');
        acq_valid_out <= '0';
        acq_id_out <= (others => '0');
        acq_trig_out <= '0';
      else
        acq_data_out <= acq_data_sel_out;
        acq_valid_out <= acq_valid_sel_out;
        acq_id_out <= acq_id_sel_out;
        acq_trig_out <= acq_trig_sel_out;
      end if;
    end if;
  end process;

  acq_data_o <= acq_data_out;
  acq_valid_o <= acq_valid_out;
  acq_id_o <= acq_id_out;
  acq_trig_o <= acq_trig_out;

end rtl;
