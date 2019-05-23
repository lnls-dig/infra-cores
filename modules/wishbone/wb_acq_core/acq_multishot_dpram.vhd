------------------------------------------------------------------------------
-- Title      : BPM Multishot DPRAM
------------------------------------------------------------------------------
-- Author     : Lucas Maziero Russo
-- Company    : CNPEM LNLS-DIG
-- Created    : 2013-22-10
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description: Module for the buffering samples in multishot acquisition
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-22-10  1.0      lucas.russo        Created
-------------------------------------------------------------------------------

-- Based on FMC-ADC-100M (http://www.ohwr.org/projects/fmc-adc-100m14b4cha/repository)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
-- Main Wishbone Definitions
use work.wishbone_pkg.all;
-- General common cores
use work.gencores_pkg.all;
-- Genrams cores
use work.genram_pkg.all;
-- Acquisition cores
use work.acq_core_pkg.all;

entity acq_multishot_dpram is
generic
(
  g_header_out_width                        : natural := 1;
  g_data_width                              : natural := 64;
  g_fc_pipe_size                            : natural := 4;
  g_multishot_ram_size                      : natural := 2048
);
port
(
  fs_clk_i                                  : in std_logic;
  fs_ce_i                                   : in std_logic;
  fs_rst_n_i                                : in std_logic;

  data_i                                    : in std_logic_vector(g_data_width-1 downto 0);
  data_id_i                                 : in std_logic_vector(2 downto 0);
  dvalid_i                                  : in std_logic;
  wr_en_i                                   : in std_logic;
  addr_rst_i                                : in std_logic;

  buffer_sel_i                              : in std_logic;
  acq_trig_i                                : in std_logic;

  pre_trig_samples_i                        : in unsigned(c_acq_samples_size-1 downto 0);
  post_trig_samples_i                       : in unsigned(c_acq_samples_size-1 downto 0);
  full_samples_i                            : in unsigned(c_acq_samples_size-1 downto 0);
  samples_valid_i                           : in std_logic;

  acq_pre_trig_done_i                       : in std_logic;
  acq_wait_trig_skip_done_i                 : in std_logic;
  acq_post_trig_done_i                      : in std_logic;

  dpram_fifo_full_o                         : out std_logic;
  dpram_dout_o                              : out std_logic_vector(g_header_out_width+g_data_width-1 downto 0);
  dpram_valid_o                             : out std_logic;
  dpram_stall_i                             : in std_logic
);
end acq_multishot_dpram;

architecture rtl of acq_multishot_dpram is

  constant c_dpram_depth                    : integer := f_log2_size(g_multishot_ram_size);
  constant c_dpram_width                    : integer := g_header_out_width+g_data_width;

  constant c_dpram_header_top_idx           : natural := g_header_out_width+g_data_width-1;
  constant c_dpram_header_bot_idx           : natural := g_data_width;
  constant c_dpram_payload_top_idx          : natural := g_data_width-1;
  constant c_dpram_payload_bot_idx          : natural := 0;
  constant c_fc_source_pipe_size            : natural := 8;

  signal dpram_trig                         : std_logic;

  signal dpram_addra_cnt                    : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addra_trig                   : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addra_post_done              : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_addrb_cnt                    : unsigned(c_dpram_depth-1 downto 0);
  signal dpram_trigger                      : std_logic;
  signal dpram_data_id                      : std_logic_vector(2 downto 0);
  signal dpram_data                         : std_logic_vector(g_data_width-1 downto 0);
  signal dpram_valid_t                      : std_logic;
  signal dpram_valid_t1                     : std_logic;
  signal dpram_valid_t2                     : std_logic;
  signal dpram_rd_req                       : std_logic;

  signal dpram0_dina                        : std_logic_vector(c_dpram_width-1 downto 0);
  signal dpram0_addra                       : std_logic_vector(c_dpram_depth-1 downto 0);
  signal dpram0_wea                         : std_logic;
  signal dpram0_addrb                       : std_logic_vector(c_dpram_depth-1 downto 0);
  signal dpram0_doutb                       : std_logic_vector(c_dpram_width-1 downto 0);
  signal dpram0_doutb_r                     : std_logic_vector(c_dpram_width-1 downto 0);

  signal dpram1_dina                        : std_logic_vector(c_dpram_width-1 downto 0);
  signal dpram1_addra                       : std_logic_vector(c_dpram_depth-1 downto 0);
  signal dpram1_wea                         : std_logic;
  signal dpram1_addrb                       : std_logic_vector(c_dpram_depth-1 downto 0);
  signal dpram1_doutb                       : std_logic_vector(c_dpram_width-1 downto 0);
  signal dpram1_doutb_r                     : std_logic_vector(c_dpram_width-1 downto 0);

  signal dpram_dout                         : std_logic_vector(g_header_out_width+g_data_width-1 downto 0);
  signal dpram_valid                        : std_logic;

  signal fc_src_data_in                     : std_logic_vector(g_header_out_width+g_data_width-1 downto 0);
  signal fc_src_valid_in                    : std_logic;
  signal fc_src_stall                       : std_logic;
  signal fc_src_dreq                        : std_logic;

begin

  -- DPRAM input address counter
  p_dpram_addra_cnt : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        dpram_addra_cnt       <= (others => '0');
        dpram_addra_trig      <= (others => '0');
        dpram_addra_post_done <= (others => '0');
      else

        if addr_rst_i = '1' then
          dpram_addra_cnt <= to_unsigned(0, dpram_addra_cnt'length);
        elsif (wr_en_i = '1' and dvalid_i = '1') then
          dpram_addra_cnt <= dpram_addra_cnt + 1;
        end if;

        -- Mark the point in RAM where a trigger occured or just the
        -- pre-trigger number of samples if we are in acquire now mode
        if acq_trig_i = '1' or acq_wait_trig_skip_done_i = '1' then
          dpram_addra_trig <= dpram_addra_cnt;
        end if;

        if acq_post_trig_done_i = '1' then
          dpram_addra_post_done <= dpram_addra_cnt - 1;
        end if;

      end if;
    end if;
  end process;

  -- DPRAM inputs
  dpram0_addra <= std_logic_vector(dpram_addra_cnt);
  dpram1_addra <= std_logic_vector(dpram_addra_cnt);
  dpram0_dina  <= data_id_i & acq_trig_i & data_i; -- data_id + trigger + data
  dpram1_dina  <= data_id_i & acq_trig_i & data_i; -- data_id + trigger + data
  dpram0_wea   <= (wr_en_i and dvalid_i) when buffer_sel_i = '0' else '0';
  dpram1_wea   <= (wr_en_i and dvalid_i) when buffer_sel_i = '1' else '0';

  -- DPRAMs
  cmp_multishot_dpram0 : generic_dpram
  generic map
  (
    g_data_width                            => c_dpram_width,
    g_size                                  => g_multishot_ram_size,
    g_with_byte_enable                      => false,
    g_addr_conflict_resolution              => "read_first",
    g_dual_clock                            => false
  )
  port map
  (
    rst_n_i                                 => fs_rst_n_i,

    -- Write through port A
    clka_i                                  => fs_clk_i,
    bwea_i                                  => open,
    wea_i                                   => dpram0_wea,
    aa_i                                    => dpram0_addra,
    da_i                                    => dpram0_dina,
    qa_o                                    => open,

    -- Read through port B
    clkb_i                                  => fs_clk_i,
    bweb_i                                  => open,
    ab_i                                    => dpram0_addrb,
    qb_o                                    => dpram0_doutb
  );

  cmp_multishot_dpram1 : generic_dpram
  generic map
  (
    g_data_width                            => c_dpram_width,
    g_size                                  => g_multishot_ram_size,
    g_with_byte_enable                      => false,
    g_addr_conflict_resolution              => "read_first",
    g_dual_clock                            => false
  )
  port map
  (
    rst_n_i                                 => fs_rst_n_i,

    clka_i                                  => fs_clk_i,
    bwea_i                                  => open,
    wea_i                                   => dpram1_wea,
    aa_i                                    => dpram1_addra,
    da_i                                    => dpram1_dina,
    qa_o                                    => open,

    clkb_i                                  => fs_clk_i,
    bweb_i                                  => open,
    ab_i                                    => dpram1_addrb,
    qb_o                                    => dpram1_doutb
    );

  -- DPRAM output address counter. Keep in mind that DPRAM has 1 clock
  -- cycle to output the data + 1 to increment the counter + 1 output register
  -- below. So, even if we stop reading we must have at least 3 FIFO positions
  -- available. That's why we only request new data when the FC source is almost empty
  p_dpram_addrb_cnt : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        dpram_addrb_cnt <= (others => '0');
        dpram_valid_t   <= '0';
        dpram_valid_t1  <= '0';
      else
        if dpram_rd_req = '1' then
          if acq_post_trig_done_i = '1' then
            dpram_addrb_cnt <= dpram_addra_trig - pre_trig_samples_i(c_dpram_depth-1 downto 0);
            dpram_valid_t   <= '1';
          elsif (dpram_addrb_cnt = dpram_addra_post_done) then
            dpram_valid_t <= '0';
          else
            dpram_addrb_cnt <= dpram_addrb_cnt + 1;
            dpram_valid_t <= '1';
          end if;
        else
          dpram_valid_t <= '0';
        end if;

        -- Account for DPRAM 1 cycle latency
        dpram_valid_t1 <= dpram_valid_t;

      end if;
    end if;
  end process;

  dpram0_addrb <= std_logic_vector(dpram_addrb_cnt);
  dpram1_addrb <= std_logic_vector(dpram_addrb_cnt);

  -- DPRAM output register
  p_dpram_rut_reg : process (fs_clk_i)
  begin
    if rising_edge(fs_clk_i) then
      if fs_rst_n_i = '0' then
        dpram0_doutb_r <= (others => '0');
        dpram1_doutb_r <= (others => '0');
      else
        dpram0_doutb_r <= dpram0_doutb;
        dpram1_doutb_r <= dpram1_doutb;
        dpram_valid_t2 <= dpram_valid_t1;
      end if;
    end if;
  end process;

  -- DPRAM output mux. When writing to DPRAM 0, reads from DPRAM 1 and vice-versa
  dpram_dout   <= dpram0_doutb_r when buffer_sel_i = '1' else dpram1_doutb_r;
  dpram_valid  <= dpram_valid_t2;

  dpram_fifo_full_o <= fc_src_stall;
  dpram_rd_req <= fc_src_dreq;

  -- Extract trigger from dpram data
  dpram_trigger <= dpram_dout(c_acq_header_trigger_idx+c_dpram_header_bot_idx);

  -- Extract data_id from dpram data
  dpram_data_id <= dpram_dout(c_acq_header_id_top_idx+c_dpram_header_bot_idx downto
                          c_acq_header_id_bot_idx+c_dpram_header_bot_idx);

  dpram_data <= dpram_dout(c_dpram_payload_top_idx downto c_dpram_payload_bot_idx);

  -- FC Source inputs.
  -- Change DPRAM tag from wait_trig to pre_samples, as we only write to DPRAM
  -- exactly the samples to be written to DDR and we can have samples tagged with
  -- wait_trig (which are not gonna be counter for on next modules)
  fc_src_data_in <= "010" & dpram_trigger & dpram_data when dpram_data_id = "011" else
                    dpram_dout;
  fc_src_valid_in <= dpram_valid;

  cmp_fc_source : fc_source
  generic map (
    g_header_in_width                       => g_header_out_width,
    g_data_width                            => g_data_width,
    g_pkt_size_width                        => c_pkt_size_width,
    g_addr_width                            => 0,
    g_pipe_size                             => c_fc_source_pipe_size
  )
  port map (
    clk_i                                   => fs_clk_i,
    rst_n_i                                 => fs_rst_n_i,

    pl_data_i                               => fc_src_data_in,
    pl_addr_i                               => (others => '0'),
    pl_valid_i                              => fc_src_valid_in,

    pl_dreq_o                               => fc_src_dreq,
    pl_stall_o                              => fc_src_stall,
    pl_pkt_sent_o                           => open,

    pl_rst_trans_i                          => '0',

    lmt_pre_pkt_size_i                      => pre_trig_samples_i,
    lmt_pos_pkt_size_i                      => post_trig_samples_i,
    lmt_full_pkt_size_i                     => full_samples_i,
    lmt_valid_i                             => samples_valid_i,

    fc_dout_o                               => dpram_dout_o,
    fc_valid_o                              => dpram_valid_o,
    fc_addr_o                               => open,
    fc_sof_o                                => open,
    fc_eof_o                                => open,

    fc_stall_i                              => dpram_stall_i,
    fc_dreq_i                               => '1'
  );

end rtl;
