---------------------------------------------------------------------------------------
-- Title          : Wishbone slave core for WRF Loopback
---------------------------------------------------------------------------------------
-- File           : lbk_wishbone_controller.vhd
-- Author         : auto-generated by wbgen2 from lbk_wishbone.wb
-- Created        : Wed Oct 28 15:10:33 2015
-- Standard       : VHDL'87
---------------------------------------------------------------------------------------
-- THIS FILE WAS GENERATED BY wbgen2 FROM SOURCE FILE lbk_wishbone.wb
-- DO NOT HAND-EDIT UNLESS IT'S ABSOLUTELY NECESSARY!
---------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lbk_wbgen2_pkg.all;


entity lbk_wishbone_controller is
  port (
    rst_n_i                                  : in     std_logic;
    clk_sys_i                                : in     std_logic;
    wb_adr_i                                 : in     std_logic_vector(2 downto 0);
    wb_dat_i                                 : in     std_logic_vector(31 downto 0);
    wb_dat_o                                 : out    std_logic_vector(31 downto 0);
    wb_cyc_i                                 : in     std_logic;
    wb_sel_i                                 : in     std_logic_vector(3 downto 0);
    wb_stb_i                                 : in     std_logic;
    wb_we_i                                  : in     std_logic;
    wb_ack_o                                 : out    std_logic;
    wb_stall_o                               : out    std_logic;
    regs_i                                   : in     t_lbk_in_registers;
    regs_o                                   : out    t_lbk_out_registers
  );
end lbk_wishbone_controller;

architecture syn of lbk_wishbone_controller is

signal lbk_mcr_ena_int                          : std_logic      ;
signal lbk_mcr_clr_dly0                         : std_logic      ;
signal lbk_mcr_clr_int                          : std_logic      ;
signal lbk_mcr_fdmac_int                        : std_logic      ;
signal ack_sreg                                 : std_logic_vector(9 downto 0);
signal rddata_reg                               : std_logic_vector(31 downto 0);
signal wrdata_reg                               : std_logic_vector(31 downto 0);
signal bwsel_reg                                : std_logic_vector(3 downto 0);
signal rwaddr_reg                               : std_logic_vector(2 downto 0);
signal ack_in_progress                          : std_logic      ;
signal wr_int                                   : std_logic      ;
signal rd_int                                   : std_logic      ;
signal allones                                  : std_logic_vector(31 downto 0);
signal allzeros                                 : std_logic_vector(31 downto 0);

begin
-- Some internal signals assignments. For (foreseen) compatibility with other bus standards.
  wrdata_reg <= wb_dat_i;
  bwsel_reg <= wb_sel_i;
  rd_int <= wb_cyc_i and (wb_stb_i and (not wb_we_i));
  wr_int <= wb_cyc_i and (wb_stb_i and wb_we_i);
  allones <= (others => '1');
  allzeros <= (others => '0');
-- 
-- Main register bank access process.
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      ack_sreg <= "0000000000";
      ack_in_progress <= '0';
      rddata_reg <= "00000000000000000000000000000000";
      lbk_mcr_ena_int <= '0';
      lbk_mcr_clr_int <= '0';
      lbk_mcr_fdmac_int <= '0';
      regs_o.dmac_l_load_o <= '0';
      regs_o.dmac_h_load_o <= '0';
      regs_o.rcv_cnt_load_o <= '0';
      regs_o.drp_cnt_load_o <= '0';
      regs_o.fwd_cnt_load_o <= '0';
    elsif rising_edge(clk_sys_i) then
-- advance the ACK generator shift register
      ack_sreg(8 downto 0) <= ack_sreg(9 downto 1);
      ack_sreg(9) <= '0';
      if (ack_in_progress = '1') then
        if (ack_sreg(0) = '1') then
          lbk_mcr_clr_int <= '0';
          regs_o.dmac_l_load_o <= '0';
          regs_o.dmac_h_load_o <= '0';
          regs_o.rcv_cnt_load_o <= '0';
          regs_o.drp_cnt_load_o <= '0';
          regs_o.fwd_cnt_load_o <= '0';
          ack_in_progress <= '0';
        else
          regs_o.dmac_l_load_o <= '0';
          regs_o.dmac_h_load_o <= '0';
          regs_o.rcv_cnt_load_o <= '0';
          regs_o.drp_cnt_load_o <= '0';
          regs_o.fwd_cnt_load_o <= '0';
        end if;
      else
        if ((wb_cyc_i = '1') and (wb_stb_i = '1')) then
          case rwaddr_reg(2 downto 0) is
          when "000" => 
            if (wb_we_i = '1') then
              lbk_mcr_ena_int <= wrdata_reg(0);
              lbk_mcr_clr_int <= wrdata_reg(1);
              lbk_mcr_fdmac_int <= wrdata_reg(2);
            end if;
            rddata_reg(0) <= lbk_mcr_ena_int;
            rddata_reg(1) <= '0';
            rddata_reg(2) <= lbk_mcr_fdmac_int;
            rddata_reg(3) <= 'X';
            rddata_reg(4) <= 'X';
            rddata_reg(5) <= 'X';
            rddata_reg(6) <= 'X';
            rddata_reg(7) <= 'X';
            rddata_reg(8) <= 'X';
            rddata_reg(9) <= 'X';
            rddata_reg(10) <= 'X';
            rddata_reg(11) <= 'X';
            rddata_reg(12) <= 'X';
            rddata_reg(13) <= 'X';
            rddata_reg(14) <= 'X';
            rddata_reg(15) <= 'X';
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(2) <= '1';
            ack_in_progress <= '1';
          when "001" => 
            if (wb_we_i = '1') then
              regs_o.dmac_l_load_o <= '1';
            end if;
            rddata_reg(31 downto 0) <= regs_i.dmac_l_i;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "010" => 
            if (wb_we_i = '1') then
              regs_o.dmac_h_load_o <= '1';
            end if;
            rddata_reg(15 downto 0) <= regs_i.dmac_h_i;
            rddata_reg(16) <= 'X';
            rddata_reg(17) <= 'X';
            rddata_reg(18) <= 'X';
            rddata_reg(19) <= 'X';
            rddata_reg(20) <= 'X';
            rddata_reg(21) <= 'X';
            rddata_reg(22) <= 'X';
            rddata_reg(23) <= 'X';
            rddata_reg(24) <= 'X';
            rddata_reg(25) <= 'X';
            rddata_reg(26) <= 'X';
            rddata_reg(27) <= 'X';
            rddata_reg(28) <= 'X';
            rddata_reg(29) <= 'X';
            rddata_reg(30) <= 'X';
            rddata_reg(31) <= 'X';
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "011" => 
            if (wb_we_i = '1') then
              regs_o.rcv_cnt_load_o <= '1';
            end if;
            rddata_reg(31 downto 0) <= regs_i.rcv_cnt_i;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "100" => 
            if (wb_we_i = '1') then
              regs_o.drp_cnt_load_o <= '1';
            end if;
            rddata_reg(31 downto 0) <= regs_i.drp_cnt_i;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when "101" => 
            if (wb_we_i = '1') then
              regs_o.fwd_cnt_load_o <= '1';
            end if;
            rddata_reg(31 downto 0) <= regs_i.fwd_cnt_i;
            ack_sreg(0) <= '1';
            ack_in_progress <= '1';
          when others =>
-- prevent the slave from hanging the bus on invalid address
            ack_in_progress <= '1';
            ack_sreg(0) <= '1';
          end case;
        end if;
      end if;
    end if;
  end process;
  
  
-- Drive the data output bus
  wb_dat_o <= rddata_reg;
-- Enable Loopback
  regs_o.mcr_ena_o <= lbk_mcr_ena_int;
-- Clear counters
  process (clk_sys_i, rst_n_i)
  begin
    if (rst_n_i = '0') then 
      lbk_mcr_clr_dly0 <= '0';
      regs_o.mcr_clr_o <= '0';
    elsif rising_edge(clk_sys_i) then
      lbk_mcr_clr_dly0 <= lbk_mcr_clr_int;
      regs_o.mcr_clr_o <= lbk_mcr_clr_int and (not lbk_mcr_clr_dly0);
    end if;
  end process;
  
  
-- Force DMAC
  regs_o.mcr_fdmac_o <= lbk_mcr_fdmac_int;
-- MAC
  regs_o.dmac_l_o <= wrdata_reg(31 downto 0);
-- MAC
  regs_o.dmac_h_o <= wrdata_reg(15 downto 0);
-- Value
  regs_o.rcv_cnt_o <= wrdata_reg(31 downto 0);
-- Value
  regs_o.drp_cnt_o <= wrdata_reg(31 downto 0);
-- Value
  regs_o.fwd_cnt_o <= wrdata_reg(31 downto 0);
  rwaddr_reg <= wb_adr_i;
  wb_stall_o <= (not ack_sreg(0)) and (wb_stb_i and wb_cyc_i);
-- ACK signal generation. Just pass the LSB of ACK counter.
  wb_ack_o <= ack_sreg(0);
end syn;
