-- Do not edit.  Generated by cheby 1.6.0rc1 using these options:
--  -i wb_si57x_ctrl_regs.cheby --hdl vhdl --gen-hdl wb_si57x_ctrl_regs.vhd --doc html --gen-doc doc/wb_si57x_ctrl_regs.html --gen-c wb_si57x_ctrl_regs.h --consts-style verilog --gen-consts ../../../../sim/regs/wb_si57x_ctrl_regs.vh --consts-style vhdl-ohwr --gen-consts ../../../../sim/regs/wb_si57x_ctrl_reg_consts.vhd
-- Generated on Thu Jun 13 17:05:03 2024 by augusto


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity wb_si57x_ctrl_regs is
  port (
    rst_n_i              : in    std_logic;
    clk_i                : in    std_logic;
    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    -- Si57x control register
    -- 0: Do nothing;
    -- 1: Load startup registers (WARNING: This will change the output frequency of the Si57x oscillator to the startup values, autoclear).
    ctl_read_strp_regs_o : out   std_logic;
    -- 0: Do nothing;
    -- 1: Write registers (autoclear).
    ctl_apply_cfg_o      : out   std_logic;

    -- Si57x controller status bits
    -- 0: HSDIV_STRP, N1_STRP and RFREQ_STRP are not valid, a read_startup_regs command should be issued
    -- 1: HSDIV_STRP, N1_STRP and RFREQ_STRP are updated and valid
    sta_strp_complete_i  : in    std_logic;
    -- 0: Registers HSDIV, N1 and RFREQ values are not in sync with the internal Si57x registers
    -- 1: Registers HSDIV, N1 and RFREQ values are in sync with the internal Si57x registers
    sta_cfg_in_sync_i    : in    std_logic;
    -- 0: No errors
    -- 1: An I2C error occured (no response from slave, arbitration lost)
    sta_i2c_err_i        : in    std_logic;
    -- 0: The Si57x controller is idle and can receive new commands
    -- 1: The Si57x controller is busy and will ignore new commands
    sta_busy_i           : in    std_logic;

    -- HSDIV, N1 and RFREQ higher bits startup values
    -- RFREQ startup value (most significant bits)
    hsdiv_n1_rfreq_msb_strp_rfreq_msb_strp_i : in    std_logic_vector(5 downto 0);
    -- N1 startup value
    hsdiv_n1_rfreq_msb_strp_n1_strp_i : in    std_logic_vector(6 downto 0);
    -- HSDIV startup value
    hsdiv_n1_rfreq_msb_strp_hsdiv_strp_i : in    std_logic_vector(2 downto 0);

    -- RFREQ startup value (least significant bits)
    rfreq_lsb_strp_i     : in    std_logic_vector(31 downto 0);

    -- HSDIV, N1 and RFREQ higher bits
    -- RFREQ (most significant bits)
    hsdiv_n1_rfreq_msb_rfreq_msb_o : out   std_logic_vector(5 downto 0);
    -- N1
    hsdiv_n1_rfreq_msb_n1_o : out   std_logic_vector(6 downto 0);
    -- HSDIV
    hsdiv_n1_rfreq_msb_hsdiv_o : out   std_logic_vector(2 downto 0);

    -- RFREQ (least significant bits)
    rfreq_lsb_o          : out   std_logic_vector(31 downto 0)
  );
end wb_si57x_ctrl_regs;

architecture syn of wb_si57x_ctrl_regs is
  signal adr_int                        : std_logic_vector(4 downto 2);
  signal rd_req_int                     : std_logic;
  signal wr_req_int                     : std_logic;
  signal rd_ack_int                     : std_logic;
  signal wr_ack_int                     : std_logic;
  signal wb_en                          : std_logic;
  signal ack_int                        : std_logic;
  signal wb_rip                         : std_logic;
  signal wb_wip                         : std_logic;
  signal ctl_read_strp_regs_reg         : std_logic;
  signal ctl_apply_cfg_reg              : std_logic;
  signal ctl_wreq                       : std_logic;
  signal ctl_wack                       : std_logic;
  signal hsdiv_n1_rfreq_msb_rfreq_msb_reg : std_logic_vector(5 downto 0);
  signal hsdiv_n1_rfreq_msb_n1_reg      : std_logic_vector(6 downto 0);
  signal hsdiv_n1_rfreq_msb_hsdiv_reg   : std_logic_vector(2 downto 0);
  signal hsdiv_n1_rfreq_msb_wreq        : std_logic;
  signal hsdiv_n1_rfreq_msb_wack        : std_logic;
  signal rfreq_lsb_reg                  : std_logic_vector(31 downto 0);
  signal rfreq_lsb_wreq                 : std_logic;
  signal rfreq_lsb_wack                 : std_logic;
  signal rd_ack_d0                      : std_logic;
  signal rd_dat_d0                      : std_logic_vector(31 downto 0);
  signal wr_req_d0                      : std_logic;
  signal wr_adr_d0                      : std_logic_vector(4 downto 2);
  signal wr_dat_d0                      : std_logic_vector(31 downto 0);
begin

  -- WB decode signals
  adr_int <= wb_i.adr(4 downto 2);
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
        wb_o.dat <= "00000000000000000000000000000000";
        wr_req_d0 <= '0';
        wr_adr_d0 <= "000";
        wr_dat_d0 <= "00000000000000000000000000000000";
      else
        rd_ack_int <= rd_ack_d0;
        wb_o.dat <= rd_dat_d0;
        wr_req_d0 <= wr_req_int;
        wr_adr_d0 <= adr_int;
        wr_dat_d0 <= wb_i.dat;
      end if;
    end if;
  end process;

  -- Register ctl
  ctl_read_strp_regs_o <= ctl_read_strp_regs_reg;
  ctl_apply_cfg_o <= ctl_apply_cfg_reg;
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        ctl_read_strp_regs_reg <= '0';
        ctl_apply_cfg_reg <= '0';
        ctl_wack <= '0';
      else
        if ctl_wreq = '1' then
          ctl_read_strp_regs_reg <= wr_dat_d0(0);
          ctl_apply_cfg_reg <= wr_dat_d0(1);
        else
          ctl_read_strp_regs_reg <= '0';
          ctl_apply_cfg_reg <= '0';
        end if;
        ctl_wack <= ctl_wreq;
      end if;
    end if;
  end process;

  -- Register sta

  -- Register hsdiv_n1_rfreq_msb_strp

  -- Register rfreq_lsb_strp

  -- Register hsdiv_n1_rfreq_msb
  hsdiv_n1_rfreq_msb_rfreq_msb_o <= hsdiv_n1_rfreq_msb_rfreq_msb_reg;
  hsdiv_n1_rfreq_msb_n1_o <= hsdiv_n1_rfreq_msb_n1_reg;
  hsdiv_n1_rfreq_msb_hsdiv_o <= hsdiv_n1_rfreq_msb_hsdiv_reg;
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        hsdiv_n1_rfreq_msb_rfreq_msb_reg <= "000000";
        hsdiv_n1_rfreq_msb_n1_reg <= "0000000";
        hsdiv_n1_rfreq_msb_hsdiv_reg <= "000";
        hsdiv_n1_rfreq_msb_wack <= '0';
      else
        if hsdiv_n1_rfreq_msb_wreq = '1' then
          hsdiv_n1_rfreq_msb_rfreq_msb_reg <= wr_dat_d0(5 downto 0);
          hsdiv_n1_rfreq_msb_n1_reg <= wr_dat_d0(12 downto 6);
          hsdiv_n1_rfreq_msb_hsdiv_reg <= wr_dat_d0(15 downto 13);
        end if;
        hsdiv_n1_rfreq_msb_wack <= hsdiv_n1_rfreq_msb_wreq;
      end if;
    end if;
  end process;

  -- Register rfreq_lsb
  rfreq_lsb_o <= rfreq_lsb_reg;
  process (clk_i) begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        rfreq_lsb_reg <= "00000000000000000000000000000000";
        rfreq_lsb_wack <= '0';
      else
        if rfreq_lsb_wreq = '1' then
          rfreq_lsb_reg <= wr_dat_d0;
        end if;
        rfreq_lsb_wack <= rfreq_lsb_wreq;
      end if;
    end if;
  end process;

  -- Process for write requests.
  process (wr_adr_d0, wr_req_d0, ctl_wack, hsdiv_n1_rfreq_msb_wack, rfreq_lsb_wack) begin
    ctl_wreq <= '0';
    hsdiv_n1_rfreq_msb_wreq <= '0';
    rfreq_lsb_wreq <= '0';
    case wr_adr_d0(4 downto 2) is
    when "000" =>
      -- Reg ctl
      ctl_wreq <= wr_req_d0;
      wr_ack_int <= ctl_wack;
    when "001" =>
      -- Reg sta
      wr_ack_int <= wr_req_d0;
    when "010" =>
      -- Reg hsdiv_n1_rfreq_msb_strp
      wr_ack_int <= wr_req_d0;
    when "011" =>
      -- Reg rfreq_lsb_strp
      wr_ack_int <= wr_req_d0;
    when "100" =>
      -- Reg hsdiv_n1_rfreq_msb
      hsdiv_n1_rfreq_msb_wreq <= wr_req_d0;
      wr_ack_int <= hsdiv_n1_rfreq_msb_wack;
    when "101" =>
      -- Reg rfreq_lsb
      rfreq_lsb_wreq <= wr_req_d0;
      wr_ack_int <= rfreq_lsb_wack;
    when others =>
      wr_ack_int <= wr_req_d0;
    end case;
  end process;

  -- Process for read requests.
  process (adr_int, rd_req_int, sta_strp_complete_i, sta_cfg_in_sync_i,
           sta_i2c_err_i, sta_busy_i, hsdiv_n1_rfreq_msb_strp_rfreq_msb_strp_i,
           hsdiv_n1_rfreq_msb_strp_n1_strp_i,
           hsdiv_n1_rfreq_msb_strp_hsdiv_strp_i, rfreq_lsb_strp_i,
           hsdiv_n1_rfreq_msb_rfreq_msb_reg, hsdiv_n1_rfreq_msb_n1_reg,
           hsdiv_n1_rfreq_msb_hsdiv_reg, rfreq_lsb_reg) begin
    -- By default ack read requests
    rd_dat_d0 <= (others => 'X');
    case adr_int(4 downto 2) is
    when "000" =>
      -- Reg ctl
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0(0) <= '0';
      rd_dat_d0(1) <= '0';
      rd_dat_d0(31 downto 2) <= (others => '0');
    when "001" =>
      -- Reg sta
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0(0) <= sta_strp_complete_i;
      rd_dat_d0(1) <= sta_cfg_in_sync_i;
      rd_dat_d0(2) <= sta_i2c_err_i;
      rd_dat_d0(3) <= sta_busy_i;
      rd_dat_d0(31 downto 4) <= (others => '0');
    when "010" =>
      -- Reg hsdiv_n1_rfreq_msb_strp
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0(5 downto 0) <= hsdiv_n1_rfreq_msb_strp_rfreq_msb_strp_i;
      rd_dat_d0(12 downto 6) <= hsdiv_n1_rfreq_msb_strp_n1_strp_i;
      rd_dat_d0(15 downto 13) <= hsdiv_n1_rfreq_msb_strp_hsdiv_strp_i;
      rd_dat_d0(31 downto 16) <= (others => '0');
    when "011" =>
      -- Reg rfreq_lsb_strp
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0 <= rfreq_lsb_strp_i;
    when "100" =>
      -- Reg hsdiv_n1_rfreq_msb
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0(5 downto 0) <= hsdiv_n1_rfreq_msb_rfreq_msb_reg;
      rd_dat_d0(12 downto 6) <= hsdiv_n1_rfreq_msb_n1_reg;
      rd_dat_d0(15 downto 13) <= hsdiv_n1_rfreq_msb_hsdiv_reg;
      rd_dat_d0(31 downto 16) <= (others => '0');
    when "101" =>
      -- Reg rfreq_lsb
      rd_ack_d0 <= rd_req_int;
      rd_dat_d0 <= rfreq_lsb_reg;
    when others =>
      rd_ack_d0 <= rd_req_int;
    end case;
  end process;
end syn;