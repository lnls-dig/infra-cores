-- Do not edit.  Generated by cheby 1.6.dev0 using these options:
--  -i ram.cheby --hdl vhdl --gen-hdl wb_ram.vhd
-- Generated on Mon Oct 23 13:07:48 2023 by augusto


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;
use work.cheby_pkg.all;

entity wb_ram is
  port (
    rst_n_i              : in    std_logic;
    clk_i                : in    std_logic;
    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    -- RAM port for ram
    ram_adr_i            : in    std_logic_vector(12 downto 0);
    ram_data_rd_i        : in    std_logic;
    ram_data_dat_o       : out   std_logic_vector(31 downto 0)
  );
end wb_ram;

architecture syn of wb_ram is
  signal adr_int                        : std_logic_vector(14 downto 2);
  signal rd_req_int                     : std_logic;
  signal wr_req_int                     : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal ram_data_int_dato              : std_logic_vector(31 downto 0);
  signal ram_data_ext_dat               : std_logic_vector(31 downto 0);
  signal ram_data_rreq                  : std_logic;
  signal ram_data_rack                  : std_logic;
  signal ram_data_int_wr                : std_logic;
  signal rd_ack_d0                      : std_logic;
  signal rd_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_req_d0                      : std_logic;
  signal wr_adr_d0                      : std_logic_vector(14 downto 2);
  signal wr_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_sel_d0                      : std_logic_vector(3 downto 0);
  signal ram_wr                         : std_logic;
  signal ram_wreq                       : std_logic;
  signal ram_adr_int                    : std_logic_vector(12 downto 0);
begin

  -- WB decode signals
  adr_int <= wb_i.adr(14 downto 2);
  wb_en <= wb_i.cyc and wb_i.stb;

  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wb_rip <= '0';
      else
        wb_rip <= (wb_rip or (wb_en and not wb_i.we)) and not rd_ack_int;
      end if;
    end if;
  end process;
  rd_req_int <= (wb_en and not wb_i.we) and not wb_rip;

  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wb_wip <= '0';
      else
        wb_wip <= (wb_wip or (wb_en and wb_i.we)) and not wr_ack_int;
      end if;
    end if;
  end process;
  wr_req_int <= (wb_en and wb_i.we) and not wb_wip;

  ack_int <= rd_ack_int or wr_ack_int;
  wb_o.ack <= ack_int;
  wb_o.stall <= not ack_int and wb_en;
  wb_o.rty <= '0';
  wb_o.err <= '0';

  -- pipelining for wr-in+rd-out
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        rd_ack_int <= '0';
        wr_req_d0 <= '0';
      else
        rd_ack_int <= rd_ack_d0;
        wb_o.dat <= rd_dat_d0;
        wr_req_d0 <= wr_req_int;
        wr_adr_d0 <= adr_int;
        wr_dat_d0 <= wb_i.dat;
        wr_sel_d0 <= wb_i.sel;
      end if;
    end if;
  end process;

  -- Memory ram
  process (adr_int, wr_adr_d0, ram_wr) begin
    if ram_wr = '1' then
      ram_adr_int <= wr_adr_d0(14 downto 2);
    else
      ram_adr_int <= adr_int(14 downto 2);
    end if;
  end process;
  ram_wreq <= ram_data_int_wr;
  ram_wr <= ram_wreq;
  ram_data_raminst: cheby_dpssram
    generic map (
      g_data_width         => 32,
      g_size               => 8192,
      g_addr_width         => 13,
      g_dual_clock         => '0',
      g_use_bwsel          => '1'
    )
    port map (
      clk_a_i              => clk_i,
      clk_b_i              => clk_i,
      addr_a_i             => ram_adr_int,
      bwsel_a_i            => wr_sel_d0,
      data_a_i             => wr_dat_d0,
      data_a_o             => ram_data_int_dato,
      rd_a_i               => ram_data_rreq,
      wr_a_i               => ram_data_int_wr,
      addr_b_i             => ram_adr_i,
      bwsel_b_i            => (others => '1'),
      data_b_i             => ram_data_ext_dat,
      data_b_o             => ram_data_dat_o,
      rd_b_i               => ram_data_rd_i,
      wr_b_i               => '0'
    );
  
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        ram_data_rack <= '0';
      else
        ram_data_rack <= ram_data_rreq;
      end if;
    end if;
  end process;

  -- Process for write requests.
  process (wr_req_d0) begin
    ram_data_int_wr <= '0';
    -- Memory ram
    ram_data_int_wr <= wr_req_d0;
    wr_ack_int <= wr_req_d0;
  end process;

  -- Process for read requests.
  process (ram_data_int_dato, rd_req_int, ram_data_rack) begin
    -- By default ack read requests
    rd_dat_d0 <= (others => 'X');
    ram_data_rreq <= '0';
    -- Memory ram
    rd_dat_d0 <= ram_data_int_dato;
    ram_data_rreq <= rd_req_int;
    rd_ack_d0 <= ram_data_rack;
  end process;
end syn;
