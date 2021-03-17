//----------------------------------------------------------------------------
// Title      : Testbench for BPM FSM Acq
//----------------------------------------------------------------------------
// Author     : Lucas Maziero Russo
// Company    : CNPEM LNLS-DIG
// Created    : 2013-22-10
// Platform   : FPGA-generic
//-----------------------------------------------------------------------------
// Description: Simulation of the BPM FSM ACQ module
//-----------------------------------------------------------------------------
// Copyright (c) 2013 CNPEM
// Licensed under GNU Lesser General Public License (LGPL) v3.0
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author          Description
// 2014-28-10  1.0      lucas.russo        Created
//-----------------------------------------------------------------------------

// Simulation timescale
`include "timescale.v"
// Common definitions
`include "defines.v"
// Wishbone Master
`include "wishbone_test_master.v"
// bpm swap Register definitions
`include "regs/wb_acq_core_regs.vh"

module wb_acq_core_tb;

  // Local definitions
  localparam c_data_max = (2**`ADC_DATA_WIDTH)-1;
  //localparam c_data_valid_gen_threshold = 0.6;
  //localparam c_data_ext_stall_threshold = 0.6;
  //localparam c_data_valid_gen_threshold = 0.3;
  //localparam c_data_ext_stall_threshold = 0.3;
  localparam c_wait_acquisition_done = 128;
  localparam c_ddr3_acq1_addr_offset      = 'h01000000;
  localparam c_ddr3_acq1_data_offset      = 'h00006000;

  //// DDR3 Parameters
  parameter SIMULATION                    = "TRUE";
  //***************************************************************************
  // The following parameters refer to width of various ports
  //***************************************************************************
  parameter BANK_WIDTH            = 3;
                                    // # of memory Bank Address bits.
  parameter CK_WIDTH              = 1;
                                    // # of CK/CK# outputs to memory.
  parameter COL_WIDTH             = 10;
                                    // # of memory Column Address bits.
  parameter CS_WIDTH              = 1;
                                    // # of unique CS outputs to memory.
  parameter nCS_PER_RANK          = 1;
                                    // # of unique CS outputs per rank for phy
  parameter CKE_WIDTH             = 1;
                                    // # of CKE outputs to memory.
  parameter DATA_BUF_ADDR_WIDTH   = 5;
  parameter DQ_CNT_WIDTH          = 5;
                                    // = ceil(log2(DQ_WIDTH))
  parameter DQ_PER_DM             = 8;
  parameter DM_WIDTH              = 4;
                                    // # of DM (data mask)
  parameter DQ_WIDTH              = 32;
                                    // # of DQ (data)
  parameter DQS_WIDTH             = 4;
  parameter DQS_CNT_WIDTH         = 2;
                                    // = ceil(log2(DQS_WIDTH))
  parameter DRAM_WIDTH            = 8;
                                    // # of DQ per DQS
  parameter ECC                   = "OFF";
  parameter nBANK_MACHS           = 4;
  parameter RANKS                 = 1;
                                    // # of Ranks.
  parameter ODT_WIDTH             = 1;
                                    // # of ODT outputs to memory.
  parameter ROW_WIDTH             = 16;
                                    // # of memory Row Address bits.
  parameter ADDR_WIDTH            = 30;
                                    // # = RANK_WIDTH + BANK_WIDTH
                                    //     + ROW_WIDTH + COL_WIDTH;
                                    // Chip Select is always tied to low for
                                    // single rank devices
  parameter USE_CS_PORT          = 1;
                                    // # = 1, When CS output is enabled
                                    //   = 0, When CS output is disabled
                                    // If CS_N disabled, user must connect
                                    // DRAM CS_N input(s) to ground
  parameter USE_DM_PORT           = 1;
                                    // # = 1, When Data Mask option is enabled
                                    //   = 0, When Data Mask option is disbaled
                                    // When Data Mask option is disabled in
                                    // MIG Controller Options page, the logic
                                    // related to Data Mask should not get
                                    // synthesized
  parameter USE_ODT_PORT          = 1;
                                    // # = 1, When ODT output is enabled
                                    //   = 0, When ODT output is disabled
                                    // Parameter configuration for Dynamic ODT support:
                                    // USE_ODT_PORT = 0, RTT_NOM = "DISABLED", RTT_WR = "60/120".
                                    // This configuration allows to save ODT pin mapping from FPGA.
                                    // The user can tie the ODT input of DRAM to HIGH.

  //***************************************************************************
  // The following parameters are mode register settings
  //***************************************************************************
  parameter AL                    = "0";
                                    // DDR3 SDRAM:
                                    // Additive Latency (Mode Register 1).
                                    // # = "0", "CL-1", "CL-2".
                                    // DDR2 SDRAM:
                                    // Additive Latency (Extended Mode Register).
  parameter nAL                   = 0;
                                    // # Additive Latency in number of clock
                                    // cycles.
  parameter BURST_MODE            = "8";
                                    // DDR3 SDRAM:
                                    // Burst Length (Mode Register 0).
                                    // # = "8", "4", "OTF".
                                    // DDR2 SDRAM:
                                    // Burst Length (Mode Register).
                                    // # = "8", "4".
  parameter BURST_TYPE            = "SEQ";
                                    // DDR3 SDRAM: Burst Type (Mode Register 0).
                                    // DDR2 SDRAM: Burst Type (Mode Register).
                                    // # = "SEQ" - (Sequential),
                                    //   = "INT" - (Interleaved).
  parameter CL                    = 6;
                                    // in number of clock cycles
                                    // DDR3 SDRAM: CAS Latency (Mode Register 0).
                                    // DDR2 SDRAM: CAS Latency (Mode Register).
  parameter CWL                   = 5;
                                    // in number of clock cycles
                                    // DDR3 SDRAM: CAS Write Latency (Mode Register 2).
                                    // DDR2 SDRAM: Can be ignored
  parameter OUTPUT_DRV            = "HIGH";
                                    // Output Driver Impedance Control (Mode Register 1).
                                    // # = "HIGH" - RZQ/7,
                                    //   = "LOW" - RZQ/6.
  parameter RTT_NOM               = "40";
                                    // RTT_NOM (ODT) (Mode Register 1).
                                    // # = "DISABLED" - RTT_NOM disabled,
                                    //   = "120" - RZQ/2,
                                    //   = "60"  - RZQ/4,
                                    //   = "40"  - RZQ/6.
  parameter RTT_WR                = "OFF";
                                    // RTT_WR (ODT) (Mode Register 2).
                                    // # = "OFF" - Dynamic ODT off,
                                    //   = "120" - RZQ/2,
                                    //   = "60"  - RZQ/4,
  parameter ADDR_CMD_MODE         = "1T" ;
                                    // # = "1T", "2T".
  parameter REG_CTRL              = "OFF";
                                    // # = "ON" - RDIMMs,
                                    //   = "OFF" - Components, SODIMMs, UDIMMs.
  parameter CA_MIRROR             = "OFF";
                                    // C/A mirror opt for DDR3 dual rank

  //***************************************************************************
  // The following parameters are multiplier and divisor factors for PLLE2.
  // Based on the selected design frequency these parameters vary.
  //***************************************************************************
  parameter CLKIN_PERIOD          = 5000;
                                    // Input Clock Period
  parameter CLKFBOUT_MULT         = 4;
                                    // write PLL VCO multiplier
  parameter DIVCLK_DIVIDE         = 1;
                                    // write PLL VCO divisor
  parameter CLKOUT0_DIVIDE        = 2;
                                    // VCO output divisor for PLL output clock (CLKOUT0)
  parameter CLKOUT1_DIVIDE        = 2;
                                    // VCO output divisor for PLL output clock (CLKOUT1)
  parameter CLKOUT2_DIVIDE        = 32;
                                    // VCO output divisor for PLL output clock (CLKOUT2)
  parameter CLKOUT3_DIVIDE        = 8;
                                    // VCO output divisor for PLL output clock (CLKOUT3)

  //***************************************************************************
  // Memory Timing Parameters. These parameters varies based on the selected
  // memory part.
  //***************************************************************************
  parameter tCKE                  = 5000;
                                    // memory tCKE paramter in pS
  parameter tFAW                  = 30000;
                                    // memory tRAW paramter in pS.
  parameter tRAS                  = 35000;
                                    // memory tRAS paramter in pS.
  parameter tRCD                  = 13750;
                                    // memory tRCD paramter in pS.
  parameter tREFI                 = 7800000;
                                    // memory tREFI paramter in pS.
  parameter tRFC                  = 300000;
                                    // memory tRFC paramter in pS.
  parameter tRP                   = 13750;
                                    // memory tRP paramter in pS.
  parameter tRRD                  = 6000;
                                    // memory tRRD paramter in pS.
  parameter tRTP                  = 7500;
                                    // memory tRTP paramter in pS.
  parameter tWTR                  = 7500;
                                    // memory tWTR paramter in pS.
  parameter tZQI                  = 128_000_000;
                                    // memory tZQI paramter in nS.
  parameter tZQCS                 = 64;
                                    // memory tZQCS paramter in clock cycles.

  //***************************************************************************
  // Simulation parameters
  //***************************************************************************
  parameter SIM_BYPASS_INIT_CAL   = "FAST";
                                    // # = "SIM_INIT_CAL_FULL" -  Complete
                                    //              memory init &
                                    //              calibration sequence
                                    // # = "SKIP" - Not supported
                                    // # = "FAST" - Complete memory init & use
                                    //              abbreviated calib sequence

  //***************************************************************************
  // The following parameters varies based on the pin out entered in MIG GUI.
  // Do not change any of these parameters directly by editing the RTL.
  // Any changes required should be done through GUI and the design regenerated.
  //***************************************************************************
  parameter BYTE_LANES_B0         = 4'b1111;
                                    // Byte lanes used in an IO column.
  parameter BYTE_LANES_B1         = 4'b1110;
                                    // Byte lanes used in an IO column.
  parameter BYTE_LANES_B2         = 4'b0000;
                                    // Byte lanes used in an IO column.
  parameter BYTE_LANES_B3         = 4'b0000;
                                    // Byte lanes used in an IO column.
  parameter BYTE_LANES_B4         = 4'b0000;
                                    // Byte lanes used in an IO column.
  parameter DATA_CTL_B0           = 4'b1111;
                                    // Indicates Byte lane is data byte lane
                                    // or control Byte lane. '1' in a bit
                                    // position indicates a data byte lane and
                                    // a '0' indicates a control byte lane
  parameter DATA_CTL_B1           = 4'b0000;
                                    // Indicates Byte lane is data byte lane
                                    // or control Byte lane. '1' in a bit
                                    // position indicates a data byte lane and
                                    // a '0' indicates a control byte lane
  parameter DATA_CTL_B2           = 4'b0000;
                                    // Indicates Byte lane is data byte lane
                                    // or control Byte lane. '1' in a bit
                                    // position indicates a data byte lane and
                                    // a '0' indicates a control byte lane
  parameter DATA_CTL_B3           = 4'b0000;
                                    // Indicates Byte lane is data byte lane
                                    // or control Byte lane. '1' in a bit
                                    // position indicates a data byte lane and
                                    // a '0' indicates a control byte lane
  parameter DATA_CTL_B4           = 4'b0000;
                                    // Indicates Byte lane is data byte lane
                                    // or control Byte lane. '1' in a bit
                                    // position indicates a data byte lane and
                                    // a '0' indicates a control byte lane
  parameter PHY_0_BITLANES        = 48'h3FE3FD2FF2FF;
  parameter PHY_1_BITLANES        = 48'hFFEFF3CC0000;
  parameter PHY_2_BITLANES        = 48'h000000000000;

  // control/address/data pin mapping parameters
  parameter CK_BYTE_MAP
    = 144'h000000000000000000000000000000000012;
  parameter ADDR_MAP
    = 192'h13211A11712A11B13A12512012B126131129116124121128;
  parameter BANK_MAP   = 36'h13613713B;
  parameter CAS_MAP    = 12'h135;
  parameter CKE_ODT_BYTE_MAP = 8'h00;
  parameter CKE_MAP    = 96'h000000000000000000000127;
  parameter ODT_MAP    = 96'h000000000000000000000138;
  parameter CS_MAP     = 120'h000000000000000000000000000133;
  parameter PARITY_MAP = 12'h000;
  parameter RAS_MAP    = 12'h139;
  parameter WE_MAP     = 12'h134;
  parameter DQS_BYTE_MAP
    = 144'h000000000000000000000000000003020100;
  parameter DATA0_MAP  = 96'h009006002004003007000005;
  parameter DATA1_MAP  = 96'h017014010015013011016019;
  parameter DATA2_MAP  = 96'h024026023027022025020029;
  parameter DATA3_MAP  = 96'h034037031035033036032039;
  parameter DATA4_MAP  = 96'h000000000000000000000000;
  parameter DATA5_MAP  = 96'h000000000000000000000000;
  parameter DATA6_MAP  = 96'h000000000000000000000000;
  parameter DATA7_MAP  = 96'h000000000000000000000000;
  parameter DATA8_MAP  = 96'h000000000000000000000000;
  parameter DATA9_MAP  = 96'h000000000000000000000000;
  parameter DATA10_MAP = 96'h000000000000000000000000;
  parameter DATA11_MAP = 96'h000000000000000000000000;
  parameter DATA12_MAP = 96'h000000000000000000000000;
  parameter DATA13_MAP = 96'h000000000000000000000000;
  parameter DATA14_MAP = 96'h000000000000000000000000;
  parameter DATA15_MAP = 96'h000000000000000000000000;
  parameter DATA16_MAP = 96'h000000000000000000000000;
  parameter DATA17_MAP = 96'h000000000000000000000000;
  parameter MASK0_MAP  = 108'h000000000000000038028012001;
  parameter MASK1_MAP  = 108'h000000000000000000000000000;

  parameter SLOT_0_CONFIG         = 8'b00000001;
                                    // Mapping of Ranks.
  parameter SLOT_1_CONFIG         = 8'b0000_0000;
                                    // Mapping of Ranks.
  parameter MEM_ADDR_ORDER
    = "TG_TEST";

  //***************************************************************************
  // IODELAY and PHY related parameters
  //***************************************************************************
  parameter IODELAY_HP_MODE       = "ON";
                                    // to phy_top
  parameter IBUF_LPWR_MODE        = "OFF";
                                    // to phy_top
  parameter DATA_IO_IDLE_PWRDWN   = "OFF";
                                    // # = "ON", "OFF"
  parameter DATA_IO_PRIM_TYPE     = "DEFAULT";
                                    // # = "HP_LP", "HR_LP", "DEFAULT"
  parameter USER_REFRESH          = "OFF";
  parameter WRLVL                 = "ON";
                                    // # = "ON" - DDR3 SDRAM
                                    //   = "OFF" - DDR2 SDRAM.
  parameter ORDERING              = "NORM";
                                    // # = "NORM", "STRICT", "RELAXED".
  parameter CALIB_ROW_ADD         = 16'h0000;
                                    // Calibration row address will be used for
                                    // calibration read and write operations
  parameter CALIB_COL_ADD         = 12'h000;
                                    // Calibration column address will be used for
                                    // calibration read and write operations
  parameter CALIB_BA_ADD          = 3'h0;
                                    // Calibration bank address will be used for
                                    // calibration read and write operations
  parameter TCQ                   = 100;
  //***************************************************************************
  // IODELAY and PHY related parameters
  //***************************************************************************
  parameter IODELAY_GRP           = "IODELAY_MIG";
                                    // It is associated to a set of IODELAYs with
                                    // an IDELAYCTRL that have same IODELAY CONTROLLER
                                    // clock frequency.
  parameter SYSCLK_TYPE           = "NO_BUFFER";
                                    // System clock type DIFFERENTIAL, SINGLE_ENDED,
                                    // NO_BUFFER
  parameter REFCLK_TYPE           = "USE_SYSTEM_CLOCK";
                                    // Reference clock type DIFFERENTIAL, SINGLE_ENDED,
                                    // NO_BUFFER, USE_SYSTEM_CLOCK
  parameter RST_ACT_LOW           = 0;
                                    // =1 for active low reset,
                                    // =0 for active high.
  parameter CAL_WIDTH             = "HALF";
  parameter STARVE_LIMIT          = 2;
                                    // # = 2,3,4.

  //***************************************************************************
  // Referece clock frequency parameters
  //***************************************************************************
  parameter REFCLK_FREQ           = 200.0;
                                    // IODELAYCTRL reference clock frequency
  //***************************************************************************
  // System clock frequency parameters
  //***************************************************************************
  parameter tCK                   = 2500;
                                    // memory tCK paramter.
                    // # = Clock Period in pS.
  parameter nCK_PER_CLK           = 4;
                                    // # of memory CKs per fabric CLK

   //***************************************************************************
   // AXI4 Shim parameters
   //***************************************************************************

   parameter UI_EXTRA_CLOCKS                = "FALSE";
                                            // Generates extra clocks as
                                            // 1/2, 1/4 and 1/8 of fabrick clock.
                                            // Valid for DDR2/DDR3 AXI interfaces
                                            // based on GUI selection
   parameter C_S_AXI_ID_WIDTH              = 4;
                                             // Width of all master and slave ID signals.
                                             // # = >= 1.
   parameter C_S_AXI_MEM_SIZE              = "2147483648";
                                            // Address Space required for this component
   parameter C_S_AXI_ADDR_WIDTH            = 31;
                                             // Width of S_AXI_AWADDR, S_AXI_ARADDR, M_AXI_AWADDR and
                                             // M_AXI_ARADDR for all SI/MI slots.
                                             // # = 32.
   parameter C_S_AXI_DATA_WIDTH            = 256;
                                             // Width of WDATA and RDATA on SI slot.
                                             // Must be <= APP_DATA_WIDTH.
                                             // # = 32, 64, 128, 256.
   parameter C_MC_nCK_PER_CLK              = 4;
                                             // Indicates whether to instatiate upsizer
                                             // Range: 0, 1
   parameter C_S_AXI_SUPPORTS_NARROW_BURST = 0;
                                             // Indicates whether to instatiate upsizer
                                             // Range: 0, 1
   parameter C_RD_WR_ARB_ALGORITHM          = "RD_PRI_REG";
                                             // Indicates the Arbitration
                                             // Allowed values - "TDM", "ROUND_ROBIN",
                                             // "RD_PRI_REG", "RD_PRI_REG_STARVE_LIMIT"
                                             // "WRITE_PRIORITY", "WRITE_PRIORITY_REG"
   parameter C_S_AXI_REG_EN0               = 20'h00000;
                                             // C_S_AXI_REG_EN0[00] = Reserved
                                             // C_S_AXI_REG_EN0[04] = AW CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN0[05] =  W CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN0[06] =  B CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN0[07] =  R CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN0[08] = AW CHANNEL UPSIZER REGISTER SLICE
                                             // C_S_AXI_REG_EN0[09] =  W CHANNEL UPSIZER REGISTER SLICE
                                             // C_S_AXI_REG_EN0[10] = AR CHANNEL UPSIZER REGISTER SLICE
                                             // C_S_AXI_REG_EN0[11] =  R CHANNEL UPSIZER REGISTER SLICE
   parameter C_S_AXI_REG_EN1               = 20'h00000;
                                             // Instatiates register slices after the upsizer.
                                             // The type of register is specified for each channel
                                             // in a vector. 4 bits per channel are used.
                                             // C_S_AXI_REG_EN1[03:00] = AW CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN1[07:04] =  W CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN1[11:08] =  B CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN1[15:12] = AR CHANNEL REGISTER SLICE
                                             // C_S_AXI_REG_EN1[20:16] =  R CHANNEL REGISTER SLICE
                                             // Possible values for each channel are:
                                             //
                                             //   0 => BYPASS    = The channel is just wired through the
                                             //                    module.
                                             //   1 => FWD       = The master VALID and payload signals
                                             //                    are registrated.
                                             //   2 => REV       = The slave ready signal is registrated
                                             //   3 => FWD_REV   = Both FWD and REV
                                             //   4 => SLAVE_FWD = All slave side signals and master
                                             //                    VALID and payload are registrated.
                                             //   5 => SLAVE_RDY = All slave side signals and master
                                             //                    READY are registrated.
                                             //   6 => INPUTS    = Slave and Master side inputs are
                                             //                    registrated.
                                             //   7 => ADDRESS   = Optimized for address channel
   parameter C_S_AXI_CTRL_ADDR_WIDTH       = 32;
                                             // Width of AXI-4-Lite address bus
   parameter C_S_AXI_CTRL_DATA_WIDTH       = 32;
                                             // Width of AXI-4-Lite data buses
   parameter C_S_AXI_BASEADDR              = 32'h0000_0000;
                                             // Base address of AXI4 Memory Mapped bus.
   parameter C_ECC_ONOFF_RESET_VALUE       = 1;
                                             // Controls ECC on/off value at startup/reset
   parameter C_ECC_CE_COUNTER_WIDTH        = 8;
                                             // The external memory to controller clock ratio.

  //***************************************************************************
  // Debug and Internal parameters
  //***************************************************************************
  parameter DEBUG_PORT            = "OFF";
                                    // # = "ON" Enable debug signals/controls.
                                    //   = "OFF" Disable debug signals/controls.
  //***************************************************************************
  // Debug and Internal parameters
  //***************************************************************************
  parameter DRAM_TYPE             = "DDR3";



  //**************************************************************************//
  // Local parameters Declarations
  //**************************************************************************//

  localparam real TPROP_DQS          = 0.00;
                                       // Delay for DQS signal during Write Operation
  localparam real TPROP_DQS_RD       = 0.00;
                       // Delay for DQS signal during Read Operation
  localparam real TPROP_PCB_CTRL     = 0.00;
                       // Delay for Address and Ctrl signals
  localparam real TPROP_PCB_DATA     = 0.00;
                       // Delay for data signal during Write operation
  localparam real TPROP_PCB_DATA_RD  = 0.00;
                       // Delay for data signal during Read operation

  localparam MEMORY_WIDTH            = 8;
  localparam NUM_COMP                = DQ_WIDTH/MEMORY_WIDTH;

  localparam real REFCLK_PERIOD = (1000000.0/(2*REFCLK_FREQ));
  localparam RESET_PERIOD = 200000; //in pSec
  localparam real SYSCLK_PERIOD = tCK;


  localparam DRAM_DEVICE = "COMPS";
                         // DRAM_TYPE: "UDIMM", "RDIMM", "COMPS"
  localparam DATA_WIDTH            = 32;
  localparam PAYLOAD_WIDTH         = 32;
  localparam BURST_MODE_INTEGER = 8; //BURST_MODE = "8"

  // local test parameters
  localparam c_n_shots_width            = 16;
  localparam c_n_pre_samples_width      = 32;
  localparam c_n_post_samples_width     = 32;
  localparam c_n_chan                   = 5;
  localparam c_n_width64                = 16'd64;
  localparam c_n_width128               = 16'd128;
  localparam c_n_width256               = 16'd256;

  // bpm acquisition parameters
  // Must be at least the size of the biggest acquisition size
  localparam ACQ_ADDR_WIDTH         = C_S_AXI_ADDR_WIDTH;
  localparam ACQ_DATA_WIDTH         = 128;
  localparam ACQ_DATA_WIDTH_MAX     = 1024;
  localparam DATA_CHECK_FIFO_SIZE   = 8192;
  localparam ACQ_FIFO_SIZE          = 256;

  localparam DDR3_PAYLOAD_WIDTH = (BURST_MODE_INTEGER)*PAYLOAD_WIDTH;
  localparam DDR3_ADDR_INC = DDR3_PAYLOAD_WIDTH/DQ_WIDTH;
  localparam DDR3_BYTES_PER_WORD = DQ_WIDTH/8;
  localparam DDR3_ADDR_INC_BYTES = DDR3_PAYLOAD_WIDTH/DQ_WIDTH*DDR3_BYTES_PER_WORD;

  localparam RB_COUNTER_WIDTH = 12;

  // Tests paramaters
  reg [ACQ_DATA_WIDTH_MAX-1:0] data_test [c_n_chan-1:0];
  reg [16-1:0] data_test_0;
  reg data_test_dvalid [c_n_chan-1:0];
  reg data_test_dvalid_t [c_n_chan-1:0];
  reg data_test_trig [c_n_chan-1:0];
  reg data_trig;
  real data_ext_stall_threshold;
  real data_ext_rdy_threshold;
  real data_valid_threshold;
  reg data_valid_prob_gen;
  reg [31:0] data_valid_zero_cycles;

  reg data_gen_start;
  reg stop_on_error;
  reg test_in_progress;
  reg test_in_progress_d0;
  reg test_in_progress_d1;
  wire test_in_progress_p;

  // Test scenario parameters
  integer test_id = 1;
  reg [c_n_shots_width-1:0] n_shots;
  reg [c_n_pre_samples_width-1:0] pre_trig_samples;
  reg [c_n_post_samples_width-1:0] post_trig_samples;
  reg [1:0] hw_trig_sel;
  reg hw_trig_en;
  reg [32-1:0] hw_trig_dly;
  reg [32-1:0] hw_int_trig_thres;
  reg [7:0] hw_int_trig_thres_filt;
  reg sw_trig_en;
  reg [32-1:0] ddr3_start_addr;
  reg [32-1:0] ddr3_end_addr;
  reg [16-1:0] acq_chan;
  reg [32-1:0] lmt_pkt_size;
  reg skip_trig;
  reg wait_finish;
  real data_valid_prob;
  integer min_wait_gnt;
  integer max_wait_gnt;
  integer min_wait_gnt_l;
  integer max_wait_gnt_l;
  integer min_wait_trig;
  integer max_wait_trig;
  integer min_wait_trig_l;
  integer max_wait_trig_l;

  // Core registers
  reg [31:0] acq_core_fsm_ctl_reg = 'h0;
  reg [31:0] acq_core_fsm_sta_reg = 'h0;

  // DDR3 signals
  wire                                      ddr3_reset_n;
  wire [DQ_WIDTH-1:0]                       ddr3_dq_fpga;
  wire [DQS_WIDTH-1:0]                      ddr3_dqs_p_fpga;
  wire [DQS_WIDTH-1:0]                      ddr3_dqs_n_fpga;
  wire [ROW_WIDTH-1:0]                      ddr3_addr_fpga;
  wire [BANK_WIDTH-1:0]                     ddr3_ba_fpga;
  wire                                      ddr3_ras_n_fpga;
  wire                                      ddr3_cas_n_fpga;
  wire                                      ddr3_we_n_fpga;
  wire [CKE_WIDTH-1:0]                      ddr3_cke_fpga;
  wire [CK_WIDTH-1:0]                       ddr3_ck_p_fpga;
  wire [CK_WIDTH-1:0]                       ddr3_ck_n_fpga;


  wire                                      init_calib_complete;
  wire                                      tg_compare_error;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0]        ddr3_cs_n_fpga;
  wire [DM_WIDTH-1:0]                       ddr3_dm_fpga;
  wire [ODT_WIDTH-1:0]                      ddr3_odt_fpga;

  reg [(CS_WIDTH*nCS_PER_RANK)-1:0]         ddr3_cs_n_sdram_tmp;
  reg [DM_WIDTH-1:0]                        ddr3_dm_sdram_tmp;
  reg [ODT_WIDTH-1:0]                       ddr3_odt_sdram_tmp;

  wire [DQ_WIDTH-1:0]                       ddr3_dq_sdram;
  reg [ROW_WIDTH-1:0]                       ddr3_addr_sdram [0:1];
  reg [BANK_WIDTH-1:0]                      ddr3_ba_sdram [0:1];
  reg                                       ddr3_ras_n_sdram;
  reg                                       ddr3_cas_n_sdram;
  reg                                       ddr3_we_n_sdram;
  wire [(CS_WIDTH*nCS_PER_RANK)-1:0]        ddr3_cs_n_sdram;
  wire [ODT_WIDTH-1:0]                      ddr3_odt_sdram;
  reg [CKE_WIDTH-1:0]                       ddr3_cke_sdram;
  wire [DM_WIDTH-1:0]                       ddr3_dm_sdram;
  wire [DQS_WIDTH-1:0]                      ddr3_dqs_p_sdram;
  wire [DQS_WIDTH-1:0]                      ddr3_dqs_n_sdram;
  reg [CK_WIDTH-1:0]                        ddr3_ck_p_sdram;
  reg [CK_WIDTH-1:0]                        ddr3_ck_n_sdram;

  // DDR3 Core AXI
  wire [3:0]                                ddr_aximm_ma_awid;
  wire [31:0]                               ddr_aximm_ma_awaddr;
  wire [7:0]                                ddr_aximm_ma_awlen;
  wire [2:0]                                ddr_aximm_ma_awsize;
  wire [1:0]                                ddr_aximm_ma_awburst;
  wire [0:0]                                ddr_aximm_ma_awlock;
  wire [3:0]                                ddr_aximm_ma_awcache;
  wire [2:0]                                ddr_aximm_ma_awprot;
  wire [3:0]                                ddr_aximm_ma_awqos;
  wire                                      ddr_aximm_ma_awvalid;
  wire                                      ddr_aximm_ma_awready;
  wire [255:0]                              ddr_aximm_ma_wdata;
  wire [31:0]                               ddr_aximm_ma_wstrb;
  wire                                      ddr_aximm_ma_wlast;
  wire                                      ddr_aximm_ma_wvalid;
  wire                                      ddr_aximm_ma_wready;
  wire                                      ddr_aximm_ma_bready;
  wire [3:0]                                ddr_aximm_ma_bid;
  wire [1:0]                                ddr_aximm_ma_bresp;
  wire                                      ddr_aximm_ma_bvalid;
  wire [3:0]                                ddr_aximm_ma_arid;
  wire [31:0]                               ddr_aximm_ma_araddr;
  wire [7:0]                                ddr_aximm_ma_arlen;
  wire [2:0]                                ddr_aximm_ma_arsize;
  wire [1:0]                                ddr_aximm_ma_arburst;
  wire [0:0]                                ddr_aximm_ma_arlock;
  wire [3:0]                                ddr_aximm_ma_arcache;
  wire [2:0]                                ddr_aximm_ma_arprot;
  wire [3:0]                                ddr_aximm_ma_arqos;
  wire                                      ddr_aximm_ma_arvalid;
  wire                                      ddr_aximm_ma_arready;
  wire                                      ddr_aximm_ma_rready;
  wire [3:0]                                ddr_aximm_ma_rid;
  wire [255:0]                              ddr_aximm_ma_rdata;
  wire [1:0]                                ddr_aximm_ma_rresp;
  wire                                      ddr_aximm_ma_rlast;
  wire                                      ddr_aximm_ma_rvalid;

  // PCIe / DDR AXI interconnect
  wire ui_clk             , ddr_mmcm_locked;
  wire ddr_ui_rst             , irconnect_arstn  , ddr_axi_aresetn , pcie_axi_aresetn;
  wire ui_clk_sync_rst, ui_clk_sync_rst_n;
  wire [7:0] ddr_axi_awid     , ddr_axi_arid     , ddr_axi_bid     , ddr_axi_rid;
  wire [31:0]  ddr_axi_awaddr;
  wire [7:0]  ddr_axi_awlen;
  wire [2:0]  ddr_axi_awsize;
  wire [1:0]  ddr_axi_awburst;
  wire  ddr_axi_awlock;
  wire [3:0]  ddr_axi_awcache;
  wire [2:0]  ddr_axi_awprot;
  wire [3:0]  ddr_axi_awqos;
  wire  ddr_axi_awvalid , ddr_axi_awready;
  wire [255:0]  ddr_axi_wdata;
  wire [31:0]  ddr_axi_wstrb;
  wire  ddr_axi_wvalid  , ddr_axi_wready;
  wire  ddr_axi_wlast;
  wire [1:0]  ddr_axi_bresp;
  wire  ddr_axi_bvalid  , ddr_axi_bready;
  wire [31:0]  ddr_axi_araddr;
  wire [7:0]  ddr_axi_arlen;
  wire [2:0]  ddr_axi_arsize;
  wire [1:0]  ddr_axi_arburst;
  wire ddr_axi_arlock;
  wire [3:0]  ddr_axi_arcache;
  wire [2:0]  ddr_axi_arprot;
  wire [3:0]  ddr_axi_arqos;
  wire  ddr_axi_arvalid , ddr_axi_arready;
  wire [255:0]  ddr_axi_rdata;
  wire [1:0]  ddr_axi_rresp;
  wire ddr_axi_rvalid  , ddr_axi_rready;
  wire ddr_axi_rlast;

  reg                                       ddr_sys_clk_i;
  reg                                       clk_ref_i;

  // External interface signals
  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext0_dout;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext0_addr;
  wire                                     ext0_valid;
  wire                                     ext0_sof;
  wire                                     ext0_eof;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext0_dout_conv;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext0_addr_conv;
  wire                                     ext0_valid_conv;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext1_dout;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext1_addr;
  wire                                     ext1_valid;
  wire                                     ext1_sof;
  wire                                     ext1_eof;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext1_dout_conv;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext1_addr_conv;
  wire                                     ext1_valid_conv;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext2_dout;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext2_addr;
  wire                                     ext2_valid;
  wire                                     ext2_sof;
  wire                                     ext2_eof;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext2_dout_conv;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext2_addr_conv;
  wire                                     ext2_valid_conv;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext3_dout;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext3_addr;
  wire                                     ext3_valid;
  wire                                     ext3_sof;
  wire                                     ext3_eof;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext3_dout_conv;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext3_addr_conv;
  wire                                     ext3_valid_conv;

  wire [DDR3_PAYLOAD_WIDTH-1:0]            ext_dout_conv_rb;
  wire [ACQ_ADDR_WIDTH-1:0]                    ext_addr_conv_rb;
  wire                                     ext_valid_conv;

  // Debug/Readback signals
  wire [(BURST_MODE_INTEGER)*DATA_WIDTH-1:0] dbg_ddr_rb0_data;
  wire [ACQ_ADDR_WIDTH-1:0]                     dbg_ddr_rb0_addr;
  wire                                      dbg_ddr_rb0_valid;
  reg                                       dbg_ddr_rb0_start_p;
  wire                                      dbg_ddr_rb0_start_int_p;
  reg [RB_COUNTER_WIDTH-1:0]                dbg_ddr_rb0_start_counter = 'h0;
  wire                                      dbg_ddr_rb0_rdy;
  reg                                       dbg_ddr_rb0_in_progress;
  reg                                       dbg_ddr_rb0_start_pulse_gen;

  wire [(BURST_MODE_INTEGER)*DATA_WIDTH-1:0] dbg_ddr_rb1_data;
  wire [ACQ_ADDR_WIDTH-1:0]                     dbg_ddr_rb1_addr;
  wire                                      dbg_ddr_rb1_valid;
  reg                                       dbg_ddr_rb1_start_p;
  wire                                      dbg_ddr_rb1_start_int_p;
  reg [RB_COUNTER_WIDTH-1:0]                dbg_ddr_rb1_start_counter = 'h0;
  wire                                      dbg_ddr_rb1_rdy;
  reg                                       dbg_ddr_rb1_in_progress;
  reg                                       dbg_ddr_rb1_start_pulse_gen;

  wire [(BURST_MODE_INTEGER)*DATA_WIDTH-1:0] dbg_ddr_rb2_data;
  wire [ACQ_ADDR_WIDTH-1:0]                     dbg_ddr_rb2_addr;
  wire                                      dbg_ddr_rb2_valid;
  reg                                       dbg_ddr_rb2_start_p;
  wire                                      dbg_ddr_rb2_start_int_p;
  reg [RB_COUNTER_WIDTH-1:0]                dbg_ddr_rb2_start_counter = 'h0;
  wire                                      dbg_ddr_rb2_rdy;
  reg                                       dbg_ddr_rb2_in_progress;
  reg                                       dbg_ddr_rb2_start_pulse_gen;

  wire [(BURST_MODE_INTEGER)*DATA_WIDTH-1:0] dbg_ddr_rb3_data;
  wire [ACQ_ADDR_WIDTH-1:0]                     dbg_ddr_rb3_addr;
  wire                                      dbg_ddr_rb3_valid;
  reg                                       dbg_ddr_rb3_start_p;
  wire                                      dbg_ddr_rb3_start_int_p;
  reg [RB_COUNTER_WIDTH-1:0]                dbg_ddr_rb3_start_counter = 'h0;
  wire                                      dbg_ddr_rb3_rdy;
  reg                                       dbg_ddr_rb3_in_progress;
  reg                                       dbg_ddr_rb3_start_pulse_gen;

  wire                                      chk0_data_err;
  wire [16-1:0]                             chk0_data_err_cnt;
  wire                                      chk0_addr_err;
  wire [16-1:0]                             chk0_addr_err_cnt;
  wire                                      chk0_end;
  wire                                      chk0_pass;

  wire                                      chk1_data_err;
  wire [16-1:0]                             chk1_data_err_cnt;
  wire                                      chk1_addr_err;
  wire [16-1:0]                             chk1_addr_err_cnt;
  wire                                      chk1_end;
  wire                                      chk1_pass;

  // Clock and resets
  wire                                      sys_clk;
  wire                                      sys_rstn;
  wire                                      sys_rst;
  wire                                      adc_clk;
  wire                                      adc_rstn;
  wire                                      clk_200mhz;
  wire                                      clk200mhz_rstn;
  wire                                      ddr3_sys_clk;
  wire                                      ddr3_sys_rstn;
  wire                                      ddr3_sys_rst;
  wire                                      clk_ref;

  wire                                      sda;
  wire                                      scl;

  clk_rst cmp_clk_rst(
   .clk_sys_o(sys_clk),
   .clk_adc_o(adc_clk),
   .clk_100mhz_o(),
   .clk_200mhz_o(clk_200mhz),
   .sys_rstn_o(sys_rstn),
   .adc_rstn_o(adc_rstn),
   .clk100mhz_rstn_o(),
   .clk200mhz_rstn_o(clk200mhz_rstn)
  );

  assign sys_rst = ~sys_rstn;

  // DDR3 Clocks
  assign clk_ref = clk_200mhz;
  assign ddr3_sys_clk = clk_200mhz;
  assign ddr3_sys_rstn = clk200mhz_rstn;
  assign ddr3_sys_rst = ~ddr3_sys_rstn;

  //**************************************************************************//
  // Clock generation and reset
  //**************************************************************************//

  wire [31:0] dummy_wb_dat2;
  wire [31:0] dummy_wb_dat3;
  wire        dummy_wb_ack2;
  wire        dummy_wb_ack3;

  WB_TEST_MASTER WB0(
    .wb_clk                                 (sys_clk)
  );

  WB_TEST_MASTER WB1(
    .wb_clk                                 (sys_clk)
  );

  // DUT
  wb_facq_core_mux_plain #(
    .g_ddr_addr_width(ACQ_ADDR_WIDTH),
    .g_acq_addr_width(ACQ_ADDR_WIDTH),
    .g_fifo_fc_size(ACQ_FIFO_SIZE),
    .g_ddr_payload_width(DDR3_PAYLOAD_WIDTH),
    .g_ddr_dq_width(PAYLOAD_WIDTH),
    .g_sim_readback(1),
    .g_acq_num_cores(4)
  )
  dut (

    .fs_clk_array_i                         ({adc_clk, adc_clk,adc_clk, adc_clk}),
    .fs_ce_array_i                          ({1'b1, 1'b1, 1'b1, 1'b1}),
    .fs_rst_n_array_i                       ({adc_rstn, adc_rstn, adc_rstn, adc_rstn}),

    .sys_clk_i                              (sys_clk),
    .sys_rst_n_i                            (sys_rstn),

    .ext_clk_i                              (ui_clk),
    .ext_rst_n_i                            (ui_clk_sync_rst_n),

    .wb_adr_array_i                         ({32'h0, 32'h0, WB1.wb_addr,   WB0.wb_addr}),
    .wb_dat_array_i                         ({32'h0, 32'h0, WB1.wb_data_o, WB0.wb_data_o}),
    .wb_dat_array_o                         ({dummy_wb_dat3, dummy_wb_dat2, WB1.wb_data_i, WB0.wb_data_i}),
    .wb_cyc_array_i                         ({1'b0, 1'b0, WB1.wb_cyc,    WB0.wb_cyc}),
    .wb_sel_array_i                         ({4'h0, 4'h0, WB1.wb_bwsel,  WB0.wb_bwsel}),
    .wb_stb_array_i                         ({1'b0, 1'b0, WB1.wb_stb,    WB0.wb_stb}),
    .wb_we_array_i                          ({1'b0, 1'b0, WB1.wb_we,     WB0.wb_we}),
    .wb_ack_array_o                         ({dummy_wb_ack3, dummy_wb_ack2, WB1.wb_ack_i,  WB0.wb_ack_i}),
    .wb_err_array_o                         (),
    .wb_rty_array_o                         (),
    .wb_stall_array_o                       (),

    .acq_val_array_i                        ({
                                                // Acq core 3
                                                data_test[4] + c_ddr3_acq1_data_offset, data_test[3] + c_ddr3_acq1_data_offset,
                                                data_test[2] + c_ddr3_acq1_data_offset, data_test[1] + c_ddr3_acq1_data_offset,
                                                data_test[0] + c_ddr3_acq1_data_offset ,
                                                // Acq core 2
                                                data_test[4], data_test[3], data_test[2],
                                                data_test[1], data_test[0],
                                                // Acq core 1
                                                data_test[4] + c_ddr3_acq1_data_offset, data_test[3] + c_ddr3_acq1_data_offset,
                                                data_test[2] + c_ddr3_acq1_data_offset, data_test[1] + c_ddr3_acq1_data_offset,
                                                data_test[0] + c_ddr3_acq1_data_offset ,
                                                // Acq core 0
                                                data_test[4], data_test[3], data_test[2],
                                                data_test[1], data_test[0]}),
    .acq_dvalid_array_i                     ({
                                                // Acq core 3
                                                data_test_dvalid[4], data_test_dvalid[3], data_test_dvalid[2],
                                                data_test_dvalid[1], data_test_dvalid[0],
                                                // Acq core 2
                                                data_test_dvalid[4], data_test_dvalid[3], data_test_dvalid[2],
                                                data_test_dvalid[1], data_test_dvalid[0],
                                                // Acq core 1
                                                data_test_dvalid[4], data_test_dvalid[3], data_test_dvalid[2],
                                                data_test_dvalid[1], data_test_dvalid[0],
                                                // Acq core 0
                                                data_test_dvalid[4], data_test_dvalid[3], data_test_dvalid[2],
                                                data_test_dvalid[1], data_test_dvalid[0]}),
    .acq_trig_array_i                       ({
                                                // Acq core 1
                                                data_test_trig[4], data_test_trig[3], data_test_trig[2],
                                                data_test_trig[1], data_test_trig[0],
                                                // Acq core 0
                                                data_test_trig[4], data_test_trig[3], data_test_trig[2],
                                                data_test_trig[1], data_test_trig[0],
                                                // Acq core 1
                                                data_test_trig[4], data_test_trig[3], data_test_trig[2],
                                                data_test_trig[1], data_test_trig[0],
                                                // Acq core 0
                                                data_test_trig[4], data_test_trig[3], data_test_trig[2],
                                                data_test_trig[1], data_test_trig[0]}),

    .dpram_dout_array_o                     (),
    .dpram_valid_array_o                    (),

    .ext_dout_array_o                       ({ext3_dout, ext2_dout, ext1_dout, ext0_dout}),
    .ext_valid_array_o                      ({ext3_valid, ext2_valid, ext1_valid, ext0_valid}),
    // This is just for debug. It does not epresent the actual address written
    // to DDR3 controller. The later is determined by the "acq_ddr3_iface" module
    // considering only the "ddr3_start_addr" signal
    .ext_addr_array_o                       ({ext3_addr, ext2_addr, ext1_addr, ext0_addr}),
    .ext_sof_array_o                        ({ext3_sof, ext2_sof, ext1_sof, ext0_sof}),
    .ext_eof_array_o                        ({ext3_eof, ext2_eof, ext1_eof, ext0_eof}),
    .ext_dreq_array_o                       ({ext3_dreq, ext2_dreq, ext1_dreq, ext0_dreq}),
    .ext_stall_array_o                      ({ext3_stall, ext2_stall, ext1_stall, ext0_stall}),

    // Debug interface
    .dbg_ddr_rb_start_p_array_i            ({1'b0, 1'b0, dbg_ddr_rb1_start_p, dbg_ddr_rb0_start_p}),
    .dbg_ddr_rb_rdy_array_o                ({dbg_ddr_rb3_rdy, dbg_ddr_rb2_rdy, dbg_ddr_rb1_rdy, dbg_ddr_rb0_rdy}),
    .dbg_ddr_rb_data_array_o               ({dbg_ddr_rb3_data, dbg_ddr_rb2_data, dbg_ddr_rb1_data, dbg_ddr_rb0_data}),
    .dbg_ddr_rb_addr_array_o               ({dbg_ddr_rb3_addr, dbg_ddr_rb2_addr, dbg_ddr_rb1_addr, dbg_ddr_rb0_addr}),
    .dbg_ddr_rb_valid_array_o              ({dbg_ddr_rb3_valid, dbg_ddr_rb2_valid, dbg_ddr_rb1_valid, dbg_ddr_rb0_valid}),

    // DDR interface
    .ddr_aximm_ma_awid_o                    (ddr_aximm_ma_awid),
    .ddr_aximm_ma_awaddr_o                  (ddr_aximm_ma_awaddr),
    .ddr_aximm_ma_awlen_o                   (ddr_aximm_ma_awlen),
    .ddr_aximm_ma_awsize_o                  (ddr_aximm_ma_awsize),
    .ddr_aximm_ma_awburst_o                 (ddr_aximm_ma_awburst),
    .ddr_aximm_ma_awlock_o                  (ddr_aximm_ma_awlock),
    .ddr_aximm_ma_awcache_o                 (ddr_aximm_ma_awcache),
    .ddr_aximm_ma_awprot_o                  (ddr_aximm_ma_awprot),
    .ddr_aximm_ma_awqos_o                   (ddr_aximm_ma_awqos),
    .ddr_aximm_ma_awvalid_o                 (ddr_aximm_ma_awvalid),
    .ddr_aximm_ma_awready_i                 (ddr_aximm_ma_awready),
    .ddr_aximm_ma_wdata_o                   (ddr_aximm_ma_wdata),
    .ddr_aximm_ma_wstrb_o                   (ddr_aximm_ma_wstrb),
    .ddr_aximm_ma_wlast_o                   (ddr_aximm_ma_wlast),
    .ddr_aximm_ma_wvalid_o                  (ddr_aximm_ma_wvalid),
    .ddr_aximm_ma_wready_i                  (ddr_aximm_ma_wready),
    .ddr_aximm_ma_bready_o                  (ddr_aximm_ma_bready),
    .ddr_aximm_ma_bid_i                     (ddr_aximm_ma_bid),
    .ddr_aximm_ma_bresp_i                   (ddr_aximm_ma_bresp),
    .ddr_aximm_ma_bvalid_i                  (ddr_aximm_ma_bvalid),
    .ddr_aximm_ma_arid_o                    (ddr_aximm_ma_arid),
    .ddr_aximm_ma_araddr_o                  (ddr_aximm_ma_araddr),
    .ddr_aximm_ma_arlen_o                   (ddr_aximm_ma_arlen),
    .ddr_aximm_ma_arsize_o                  (ddr_aximm_ma_arsize),
    .ddr_aximm_ma_arburst_o                 (ddr_aximm_ma_arburst),
    .ddr_aximm_ma_arlock_o                  (ddr_aximm_ma_arlock),
    .ddr_aximm_ma_arcache_o                 (ddr_aximm_ma_arcache),
    .ddr_aximm_ma_arprot_o                  (ddr_aximm_ma_arprot),
    .ddr_aximm_ma_arqos_o                   (ddr_aximm_ma_arqos),
    .ddr_aximm_ma_arvalid_o                 (ddr_aximm_ma_arvalid),
    .ddr_aximm_ma_arready_i                 (ddr_aximm_ma_arready),
    .ddr_aximm_ma_rready_o                  (ddr_aximm_ma_rready),
    .ddr_aximm_ma_rid_i                     (ddr_aximm_ma_rid),
    .ddr_aximm_ma_rdata_i                   (ddr_aximm_ma_rdata),
    .ddr_aximm_ma_rresp_i                   (ddr_aximm_ma_rresp),
    .ddr_aximm_ma_rlast_i                   (ddr_aximm_ma_rlast),
    .ddr_aximm_ma_rvalid_i                  (ddr_aximm_ma_rvalid)
  );

  // Very simple software trigger driving

  always @(posedge adc_clk) begin
    if (~adc_rstn) begin
      data_trig <= 1'b0;
    end else begin
      // allow for retrigger in the same acquistion
      if (test_in_progress) begin
        if (~data_trig) begin
          repeat(f_gen_lmt(min_wait_trig, max_wait_trig)) // waits between c_min_wait_trig and c_max_wait_trig
            @(posedge adc_clk);

          data_trig = 1'b1;
        end else begin
          data_trig <= 1'b0;
        end
      end
      else begin
        data_trig <= 1'b0;
      end
    end
  end

  // Very simple dbg_ddr_rb_start_p and dbg_ddr_rb_rdy
  // Just delay the start pulse until the AXI datamover has finished
  // writing everything to DDR controller

  // WB acq core 0
  always @(posedge ui_clk) begin
    if (~ui_clk_sync_rst_n | ~test_in_progress) begin
      dbg_ddr_rb0_in_progress <= 1'b0;
//      dbg_ddr_rb0_start_counter <= 'h0;
      dbg_ddr_rb0_start_p <= 1'b0;
      dbg_ddr_rb0_start_pulse_gen <= 1'b0;
    end else begin

      if (dbg_ddr_rb0_start_p) begin
        dbg_ddr_rb0_in_progress <= 1'b1;
      end

      if (dbg_ddr_rb0_rdy) begin
        if (~dbg_ddr_rb0_start_counter[RB_COUNTER_WIDTH-1]) begin
          dbg_ddr_rb0_start_counter <= dbg_ddr_rb0_start_counter + 1;
          dbg_ddr_rb0_start_p <= 1'b0;
          dbg_ddr_rb0_start_pulse_gen <= 1'b1;
        end else if (~dbg_ddr_rb0_start_p & dbg_ddr_rb0_start_pulse_gen) begin
          dbg_ddr_rb0_start_p <= 1'b1;
          dbg_ddr_rb0_start_pulse_gen <= 1'b0;
        end else begin
          dbg_ddr_rb0_start_p <= 1'b0;
          dbg_ddr_rb0_start_pulse_gen <= 1'b0;
        end
      end else begin
        dbg_ddr_rb0_start_p <= 1'b0;
        dbg_ddr_rb0_start_pulse_gen <= 1'b0;
        dbg_ddr_rb0_start_counter <= 'h0;
      end
    end
  end

  // WB acq core 1
  always @(posedge ui_clk) begin
    if (~ui_clk_sync_rst_n | ~test_in_progress) begin
      dbg_ddr_rb1_in_progress <= 1'b0;
 //     dbg_ddr_rb1_start_counter <= 'h0;
      dbg_ddr_rb1_start_p <= 1'b0;
      dbg_ddr_rb1_start_pulse_gen <= 1'b0;
    end else begin

      if (dbg_ddr_rb1_start_p) begin
        dbg_ddr_rb1_in_progress <= 1'b1;
      end

      if (dbg_ddr_rb1_rdy) begin
        if (~dbg_ddr_rb1_start_counter[RB_COUNTER_WIDTH-1]) begin
          dbg_ddr_rb1_start_counter <= dbg_ddr_rb1_start_counter + 1;
          dbg_ddr_rb1_start_p <= 1'b0;
          dbg_ddr_rb1_start_pulse_gen <= 1'b1;
        end else if (~dbg_ddr_rb1_start_p & dbg_ddr_rb1_start_pulse_gen) begin
          dbg_ddr_rb1_start_p <= 1'b1;
          dbg_ddr_rb1_start_pulse_gen <= 1'b0;
        end else begin
          dbg_ddr_rb1_start_p <= 1'b0;
          dbg_ddr_rb1_start_pulse_gen <= 1'b0;
        end
      end else begin
        dbg_ddr_rb1_start_p <= 1'b0;
        dbg_ddr_rb1_start_pulse_gen <= 1'b0;
        dbg_ddr_rb1_start_counter <= 'h0;
      end
    end
  end

  //**************************************************************************//
  // Data readback checker instantiation
  //**************************************************************************//
  data_checker #(.g_addr_width(ACQ_ADDR_WIDTH),
                        .g_data_width(DDR3_PAYLOAD_WIDTH),
                        .g_fifo_size(DATA_CHECK_FIFO_SIZE),
                        .g_addr_inc(DDR3_ADDR_INC_BYTES)
                    )
  cmp0_data_checker(
    .ext_clk_i                              (ui_clk),
    .ext_rst_n_i                            (ui_clk_sync_rst_n & test_in_progress),

    // Expected data
    .exp_din_i                              (ext0_dout_conv),
     // This is just for debug. It does not epresent the actual address written
     // to DDR3 controller. The later is determined by the "acq_ddr3_iface" module
     // considering only the "ddr3_start_addr" signal
    .exp_addr_i                             (ext0_addr_conv),
    .exp_valid_i                            (ext0_valid & ~ext0_stall),

    // Actual data
    .act_din_i                              (dbg_ddr_rb0_data),
    .act_addr_i                             (dbg_ddr_rb0_addr),
    .act_valid_i                            (dbg_ddr_rb0_valid & dbg_ddr_rb0_in_progress),

    // Size of the transaction in g_fifo_size bytes
    .lmt_pkt_size_i                         (lmt_pkt_size),
    // Number of shots in this acquisition
    .lmt_shots_nb_i                         (n_shots),
    // Acquisition limits valid signal. Qualifies lmt_fifo_pkt_size_i and lmt_shots_nb_i
    .lmt_valid_i                            (test_in_progress),

    .chk_data_err_o                         (chk0_data_err),
    .chk_data_err_cnt_o                     (chk0_data_err_cnt),
    .chk_addr_err_o                         (chk0_addr_err),
    .chk_addr_err_cnt_o                     (chk0_addr_err_cnt),
    .chk_end_o                              (chk0_end),
    .chk_pass_o                             (chk0_pass)
  );

  ////////assign dbg_ddr_rb_data_conv_rb    = dbg_ddr_rb0_data : dbg_ddr_rb1_data;
  ////////assign dbg_ddr_rb_addr_conv_rb    = dbg_ddr_rb0_addr : dbg_ddr_rb1_addr;
  ////////assign dbg_ddr_rb_valid_conv_rb   = dbg_ddr_rb0_valid : dbg_ddr_rb1_valid;

  assign ext0_dout_conv  = ext0_dout;
  assign ext0_valid_conv = ext0_valid;
  assign ext0_addr_conv  = ext0_addr*DDR3_ADDR_INC_BYTES;

  data_checker #(.g_addr_width(ACQ_ADDR_WIDTH),
                        .g_data_width(DDR3_PAYLOAD_WIDTH),
                        .g_fifo_size(DATA_CHECK_FIFO_SIZE),
                        .g_addr_inc(DDR3_ADDR_INC_BYTES)
                    )
  cmp1_data_checker(
    .ext_clk_i                              (ui_clk),
    .ext_rst_n_i                            (ui_clk_sync_rst_n & test_in_progress),

    // Expected data
    .exp_din_i                              (ext1_dout_conv),
     // This is just for debug. It does not epresent the actual address written
     // to DDR3 controller. The later is determined by the "acq_ddr3_iface" module
     // considering only the "ddr3_start_addr" signal
    .exp_addr_i                             (ext1_addr_conv),
    .exp_valid_i                            (ext1_valid & ~ext1_stall),

    // Actual data
    .act_din_i                              (dbg_ddr_rb1_data),
    .act_addr_i                             (dbg_ddr_rb1_addr),
    .act_valid_i                            (dbg_ddr_rb1_valid & dbg_ddr_rb1_in_progress),

    // Size of the transaction in g_fifo_size bytes
    .lmt_pkt_size_i                         (lmt_pkt_size),
    // Number of shots in this acquisition
    .lmt_shots_nb_i                         (n_shots),
    // Acquisition limits valid signal. Qualifies lmt_fifo_pkt_size_i and lmt_shots_nb_i
    .lmt_valid_i                            (test_in_progress),

    .chk_data_err_o                         (chk1_data_err),
    .chk_data_err_cnt_o                     (chk1_data_err_cnt),
    .chk_addr_err_o                         (chk1_addr_err),
    .chk_addr_err_cnt_o                     (chk1_addr_err_cnt),
    .chk_end_o                              (chk1_end),
    .chk_pass_o                             (chk1_pass)
  );

  assign ext1_dout_conv  = ext1_dout;
  assign ext1_valid_conv = ext1_valid;
  assign ext1_addr_conv  = ext1_addr*DDR3_ADDR_INC_BYTES + c_ddr3_acq1_addr_offset;

  ///////assign ext1_dout_conv_rb  = c_ddr3_acq1_addr_offset ? ext0_dout : ext1_dout;
  ///////assign ext1_valid_conv_rb = ext0_valid : ext1_valid;
  ///////assign ext1_addr_conv_rb  = ext0_addr*DDR3_ADDR_INC : ext1_addr*DDR3_ADDR_INC;

  axi_interconnect_wrapper axi_interconnect_ddr_pcie (
    .interconnect_aclk                          (ui_clk),
    .interconnect_aresetn                       (ui_clk_sync_rst_n),
    .s00_axi_areset_out_n                       (),
    .s00_axi_aclk                               (ui_clk),
    .s00_axi_awid                               (4'b0),
    .s00_axi_awaddr                             (32'h0),
    .s00_axi_awlen                              (8'h00),
    .s00_axi_awsize                             (3'h0),
    .s00_axi_awburst                            (2'h0),
    .s00_axi_awlock                             (1'b0),
    .s00_axi_awcache                            (4'h0),
    .s00_axi_awprot                             (3'h0),
    .s00_axi_awqos                              (4'h0),
    .s00_axi_awvalid                            (1'b0),
    .s00_axi_awready                            (),
    .s00_axi_wdata                              (256'h0),
    .s00_axi_wstrb                              (32'h0),
    .s00_axi_wlast                              (1'b0),
    .s00_axi_wvalid                             (1'b0),
    .s00_axi_wready                             (),
    .s00_axi_bid                                (),
    .s00_axi_bresp                              (),
    .s00_axi_bvalid                             (),
    .s00_axi_bready                             (1'b1),
    .s00_axi_arid                               (4'h0),
    .s00_axi_araddr                             (32'h0),
    .s00_axi_arlen                              (8'h0),
    .s00_axi_arsize                             (3'h0),
    .s00_axi_arburst                            (2'h0),
    .s00_axi_arlock                             (1'b0),
    .s00_axi_arcache                            (4'h0),
    .s00_axi_arprot                             (3'h0),
    .s00_axi_arqos                              (4'h0),
    .s00_axi_arvalid                            (1'b0),
    .s00_axi_arready                            (),
    .s00_axi_rid                                (),
    .s00_axi_rdata                              (),
    .s00_axi_rresp                              (),
    .s00_axi_rlast                              (),
    .s00_axi_rvalid                             (),
    .s00_axi_rready                             (1'b1),
    .s01_axi_areset_out_n                       (),
    .s01_axi_aclk                               (ui_clk),
    .s01_axi_awid                               (ddr_aximm_ma_awid),
    .s01_axi_awaddr                             (ddr_aximm_ma_awaddr),
    .s01_axi_awlen                              (ddr_aximm_ma_awlen),
    .s01_axi_awsize                             (ddr_aximm_ma_awsize),
    .s01_axi_awburst                            (ddr_aximm_ma_awburst),
    .s01_axi_awlock                             (ddr_aximm_ma_awlock),
    .s01_axi_awcache                            (ddr_aximm_ma_awcache),
    .s01_axi_awprot                             (ddr_aximm_ma_awprot),
    .s01_axi_awqos                              (ddr_aximm_ma_awqos),
    .s01_axi_awvalid                            (ddr_aximm_ma_awvalid),
    .s01_axi_awready                            (ddr_aximm_ma_awready),
    .s01_axi_wdata                              (ddr_aximm_ma_wdata),
    .s01_axi_wstrb                              (ddr_aximm_ma_wstrb),
    .s01_axi_wlast                              (ddr_aximm_ma_wlast),
    .s01_axi_wvalid                             (ddr_aximm_ma_wvalid),
    .s01_axi_wready                             (ddr_aximm_ma_wready),
    .s01_axi_bid                                (ddr_aximm_ma_bid),
    .s01_axi_bresp                              (ddr_aximm_ma_bresp),
    .s01_axi_bvalid                             (ddr_aximm_ma_bvalid),
    .s01_axi_bready                             (ddr_aximm_ma_bready),
    .s01_axi_arid                               (ddr_aximm_ma_arid),
    .s01_axi_araddr                             (ddr_aximm_ma_araddr),
    .s01_axi_arlen                              (ddr_aximm_ma_arlen),
    .s01_axi_arsize                             (ddr_aximm_ma_arsize),
    .s01_axi_arburst                            (ddr_aximm_ma_arburst),
    .s01_axi_arlock                             (ddr_aximm_ma_arlock),
    .s01_axi_arcache                            (ddr_aximm_ma_arcache),
    .s01_axi_arprot                             (ddr_aximm_ma_arprot),
    .s01_axi_arqos                              (ddr_aximm_ma_arqos),
    .s01_axi_arvalid                            (ddr_aximm_ma_arvalid),
    .s01_axi_arready                            (ddr_aximm_ma_arready),
    .s01_axi_rid                                (ddr_aximm_ma_rid),
    .s01_axi_rdata                              (ddr_aximm_ma_rdata),
    .s01_axi_rresp                              (ddr_aximm_ma_rresp),
    .s01_axi_rlast                              (ddr_aximm_ma_rlast),
    .s01_axi_rvalid                             (ddr_aximm_ma_rvalid),
    .s01_axi_rready                             (ddr_aximm_ma_rready),
    .m00_axi_areset_out_n                       (),
    .m00_axi_aclk                               (ui_clk),
    .m00_axi_awid                               (ddr_axi_awid),
    .m00_axi_awaddr                             (ddr_axi_awaddr),
    .m00_axi_awlen                              (ddr_axi_awlen),
    .m00_axi_awsize                             (ddr_axi_awsize),
    .m00_axi_awburst                            (ddr_axi_awburst),
    .m00_axi_awlock                             (ddr_axi_awlock),
    .m00_axi_awcache                            (ddr_axi_awcache),
    .m00_axi_awprot                             (ddr_axi_awprot),
    .m00_axi_awqos                              (ddr_axi_awqos),
    .m00_axi_awvalid                            (ddr_axi_awvalid),
    .m00_axi_awready                            (ddr_axi_awready),
    .m00_axi_wdata                              (ddr_axi_wdata),
    .m00_axi_wstrb                              (ddr_axi_wstrb),
    .m00_axi_wlast                              (ddr_axi_wlast),
    .m00_axi_wvalid                             (ddr_axi_wvalid),
    .m00_axi_wready                             (ddr_axi_wready),
    .m00_axi_bid                                (ddr_axi_bid),
    .m00_axi_bresp                              (ddr_axi_bresp),
    .m00_axi_bvalid                             (ddr_axi_bvalid),
    .m00_axi_bready                             (ddr_axi_bready),
    .m00_axi_arid                               (ddr_axi_arid),
    .m00_axi_araddr                             (ddr_axi_araddr),
    .m00_axi_arlen                              (ddr_axi_arlen),
    .m00_axi_arsize                             (ddr_axi_arsize),
    .m00_axi_arburst                            (ddr_axi_arburst),
    .m00_axi_arlock                             (ddr_axi_arlock),
    .m00_axi_arcache                            (ddr_axi_arcache),
    .m00_axi_arprot                             (ddr_axi_arprot),
    .m00_axi_arqos                              (ddr_axi_arqos),
    .m00_axi_arvalid                            (ddr_axi_arvalid),
    .m00_axi_arready                            (ddr_axi_arready),
    .m00_axi_rid                                (ddr_axi_rid),
    .m00_axi_rdata                              (ddr_axi_rdata),
    .m00_axi_rresp                              (ddr_axi_rresp),
    .m00_axi_rlast                              (ddr_axi_rlast),
    .m00_axi_rvalid                             (ddr_axi_rvalid),
    .m00_axi_rready                             (ddr_axi_rready)
  );

  //**************************************************************************//
  // DDR3 ARTIX7 Controller instantiation
  //**************************************************************************//
  ddr_core_mig # (
    .SIMULATION                (SIMULATION),

    //.BANK_WIDTH                (BANK_WIDTH),
    //.CK_WIDTH                  (CK_WIDTH),
    //.COL_WIDTH                 (COL_WIDTH),
    //.CS_WIDTH                  (CS_WIDTH),
    //.nCS_PER_RANK              (nCS_PER_RANK),
    //.CKE_WIDTH                 (CKE_WIDTH),
    //.DATA_BUF_ADDR_WIDTH       (DATA_BUF_ADDR_WIDTH),
    //.DQ_CNT_WIDTH              (DQ_CNT_WIDTH),
    //.DQ_PER_DM                 (DQ_PER_DM),
    //.DM_WIDTH                  (DM_WIDTH),

    //.DQ_WIDTH                  (DQ_WIDTH),
    //.DQS_WIDTH                 (DQS_WIDTH),
    //.DQS_CNT_WIDTH             (DQS_CNT_WIDTH),
    //.DRAM_WIDTH                (DRAM_WIDTH),
    //.ECC                       (ECC),
    //.nBANK_MACHS               (nBANK_MACHS),
    //.RANKS                     (RANKS),
    //.ODT_WIDTH                 (ODT_WIDTH),
    //.ROW_WIDTH                 (ROW_WIDTH),
    //.ADDR_WIDTH                (ADDR_WIDTH),
    //.USE_CS_PORT               (USE_CS_PORT),
    //.USE_DM_PORT               (USE_DM_PORT),
    //.USE_ODT_PORT              (USE_ODT_PORT),

    //.AL                        (AL),
    //.nAL                       (nAL),
    //.BURST_MODE                (BURST_MODE),
    //.BURST_TYPE                (BURST_TYPE),
    //.CL                        (CL),
    //.CWL                       (CWL),
    //.OUTPUT_DRV                (OUTPUT_DRV),
    //.RTT_NOM                   (RTT_NOM),
    //.RTT_WR                    (RTT_WR),
    //.ADDR_CMD_MODE             (ADDR_CMD_MODE),
    //.REG_CTRL                  (REG_CTRL),
    //.CA_MIRROR                 (CA_MIRROR),


    //.CLKIN_PERIOD              (CLKIN_PERIOD),
    //.CLKFBOUT_MULT             (CLKFBOUT_MULT),
    //.DIVCLK_DIVIDE             (DIVCLK_DIVIDE),
    //.CLKOUT0_DIVIDE            (CLKOUT0_DIVIDE),
    //.CLKOUT1_DIVIDE            (CLKOUT1_DIVIDE),
    //.CLKOUT2_DIVIDE            (CLKOUT2_DIVIDE),
    //.CLKOUT3_DIVIDE            (CLKOUT3_DIVIDE),


    //.tCKE                      (tCKE),
    //.tFAW                      (tFAW),
    //.tRAS                      (tRAS),
    //.tRCD                      (tRCD),
    //.tREFI                     (tREFI),
    //.tRFC                      (tRFC),
    //.tRP                       (tRP),
    //.tRRD                      (tRRD),
    //.tRTP                      (tRTP),
    //.tWTR                      (tWTR),
    //.tZQI                      (tZQI),
    //.tZQCS                     (tZQCS),

    .SIM_BYPASS_INIT_CAL       (SIM_BYPASS_INIT_CAL),

    //.BYTE_LANES_B0             (BYTE_LANES_B0),
    //.BYTE_LANES_B1             (BYTE_LANES_B1),
    //.BYTE_LANES_B2             (BYTE_LANES_B2),
    //.BYTE_LANES_B3             (BYTE_LANES_B3),
    //.BYTE_LANES_B4             (BYTE_LANES_B4),
    //.DATA_CTL_B0               (DATA_CTL_B0),
    //.DATA_CTL_B1               (DATA_CTL_B1),
    //.DATA_CTL_B2               (DATA_CTL_B2),
    //.DATA_CTL_B3               (DATA_CTL_B3),
    //.DATA_CTL_B4               (DATA_CTL_B4),
    //.PHY_0_BITLANES            (PHY_0_BITLANES),
    //.PHY_1_BITLANES            (PHY_1_BITLANES),
    //.PHY_2_BITLANES            (PHY_2_BITLANES),
    //.CK_BYTE_MAP               (CK_BYTE_MAP),
    //.ADDR_MAP                  (ADDR_MAP),
    //.BANK_MAP                  (BANK_MAP),
    //.CAS_MAP                   (CAS_MAP),
    //.CKE_ODT_BYTE_MAP          (CKE_ODT_BYTE_MAP),
    //.CKE_MAP                   (CKE_MAP),
    //.ODT_MAP                   (ODT_MAP),
    //.CS_MAP                    (CS_MAP),
    //.PARITY_MAP                (PARITY_MAP),
    //.RAS_MAP                   (RAS_MAP),
    //.WE_MAP                    (WE_MAP),
    //.DQS_BYTE_MAP              (DQS_BYTE_MAP),
    //.DATA0_MAP                 (DATA0_MAP),
    //.DATA1_MAP                 (DATA1_MAP),
    //.DATA2_MAP                 (DATA2_MAP),
    //.DATA3_MAP                 (DATA3_MAP),
    //.DATA4_MAP                 (DATA4_MAP),
    //.DATA5_MAP                 (DATA5_MAP),
    //.DATA6_MAP                 (DATA6_MAP),
    //.DATA7_MAP                 (DATA7_MAP),
    //.DATA8_MAP                 (DATA8_MAP),
    //.DATA9_MAP                 (DATA9_MAP),
    //.DATA10_MAP                (DATA10_MAP),
    //.DATA11_MAP                (DATA11_MAP),
    //.DATA12_MAP                (DATA12_MAP),
    //.DATA13_MAP                (DATA13_MAP),
    //.DATA14_MAP                (DATA14_MAP),
    //.DATA15_MAP                (DATA15_MAP),
    //.DATA16_MAP                (DATA16_MAP),
    //.DATA17_MAP                (DATA17_MAP),
    //.MASK0_MAP                 (MASK0_MAP),
    //.MASK1_MAP                 (MASK1_MAP),
    //.SLOT_0_CONFIG             (SLOT_0_CONFIG),
    //.SLOT_1_CONFIG             (SLOT_1_CONFIG),
    //.MEM_ADDR_ORDER            (MEM_ADDR_ORDER),

    //.IODELAY_HP_MODE           (IODELAY_HP_MODE),
    //.IBUF_LPWR_MODE            (IBUF_LPWR_MODE),
    //.DATA_IO_IDLE_PWRDWN       (DATA_IO_IDLE_PWRDWN),
    //.DATA_IO_PRIM_TYPE         (DATA_IO_PRIM_TYPE),
    //.USER_REFRESH              (USER_REFRESH),
    //.WRLVL                     (WRLVL),
    //.ORDERING                  (ORDERING),
    //.CALIB_ROW_ADD             (CALIB_ROW_ADD),
    //.CALIB_COL_ADD             (CALIB_COL_ADD),
    //.CALIB_BA_ADD              (CALIB_BA_ADD),
    //.TCQ                       (TCQ),


    //.IODELAY_GRP               (IODELAY_GRP),
    //.SYSCLK_TYPE               (SYSCLK_TYPE),
    //.REFCLK_TYPE               (REFCLK_TYPE),
    //.DRAM_TYPE                 (DRAM_TYPE),
    //.CAL_WIDTH                 (CAL_WIDTH),
    //.STARVE_LIMIT              (STARVE_LIMIT),


    //.REFCLK_FREQ               (REFCLK_FREQ),


    //.tCK                       (tCK),
    //.nCK_PER_CLK               (nCK_PER_CLK),


    //.DEBUG_PORT                (DEBUG_PORT),

    .RST_ACT_LOW               (RST_ACT_LOW)
  )
  cmp_ddr_core_mig (
     // System Clock Ports
    .sys_clk_i                              (ddr3_sys_clk),
    .sys_rst                                (ddr3_sys_rst),

    // Memory interface ports
    .ddr3_dq                                (ddr3_dq_fpga),
    .ddr3_dm                                (ddr3_dm_fpga),
    .ddr3_addr                              (ddr3_addr_fpga),
    .ddr3_ba                                (ddr3_ba_fpga),
    .ddr3_ras_n                             (ddr3_ras_n_fpga),
    .ddr3_cas_n                             (ddr3_cas_n_fpga),
    .ddr3_we_n                              (ddr3_we_n_fpga),
    .ddr3_reset_n                           (ddr3_reset_n),
    .ddr3_cs_n                              (ddr3_cs_n_fpga),
    .ddr3_odt                               (ddr3_odt_fpga),
    .ddr3_cke                               (ddr3_cke_fpga),
    .ddr3_dqs_p                             (ddr3_dqs_p_fpga),
    .ddr3_dqs_n                             (ddr3_dqs_n_fpga),
    .ddr3_ck_p                              (ddr3_ck_p_fpga),
    .ddr3_ck_n                              (ddr3_ck_n_fpga),

    // Application AXI interface ports
    .s_axi_awid                             (ddr_axi_awid),
    .s_axi_awaddr                           (ddr_axi_awaddr[30:0]),
    .s_axi_awlen                            (ddr_axi_awlen),
    .s_axi_awsize                           (ddr_axi_awsize),
    .s_axi_awburst                          (ddr_axi_awburst),
    .s_axi_awlock                           (ddr_axi_awlock),
    .s_axi_awcache                          (ddr_axi_awcache),
    .s_axi_awprot                           (ddr_axi_awprot),
    .s_axi_awqos                            (ddr_axi_awqos),
    .s_axi_awvalid                          (ddr_axi_awvalid),
    .s_axi_awready                          (ddr_axi_awready),

    .s_axi_wdata                            (ddr_axi_wdata),
    .s_axi_wstrb                            (ddr_axi_wstrb),
    .s_axi_wlast                            (ddr_axi_wlast),
    .s_axi_wvalid                           (ddr_axi_wvalid),
    .s_axi_wready                           (ddr_axi_wready),

    .s_axi_bready                           (ddr_axi_bready),
    .s_axi_bid                              (ddr_axi_bid),
    .s_axi_bresp                            (ddr_axi_bresp),
    .s_axi_bvalid                           (ddr_axi_bvalid),

    .s_axi_arid                             (ddr_axi_arid),
    .s_axi_araddr                           (ddr_axi_araddr[30:0]),
    .s_axi_arlen                            (ddr_axi_arlen),
    .s_axi_arsize                           (ddr_axi_arsize),
    .s_axi_arburst                          (ddr_axi_arburst),
    .s_axi_arlock                           (ddr_axi_arlock),
    .s_axi_arcache                          (ddr_axi_arcache),
    .s_axi_arprot                           (ddr_axi_arprot),
    .s_axi_arqos                            (ddr_axi_arqos),
    .s_axi_arvalid                          (ddr_axi_arvalid),
    .s_axi_arready                          (ddr_axi_arready),

    .s_axi_rready                           (ddr_axi_rready),
    .s_axi_rid                              (ddr_axi_rid),
    .s_axi_rdata                            (ddr_axi_rdata),
    .s_axi_rresp                            (ddr_axi_rresp),
    .s_axi_rlast                            (ddr_axi_rlast),
    .s_axi_rvalid                           (ddr_axi_rvalid),

    .mmcm_locked                            (),
    .aresetn                                (1'b1),
    .app_sr_active                          (),
    .app_ref_ack                            (),
    .app_zq_ack                             (),
    .app_sr_req                             (1'b0),
    .app_ref_req                            (1'b0),
    .app_zq_req                             (1'b0),
    .ui_clk_sync_rst                        (ui_clk_sync_rst),
    .ui_clk                                 (ui_clk),
    .init_calib_complete                    (ui_phy_init_done)
  );

  assign ui_clk_sync_rst_n = ~ui_clk_sync_rst;

  //**************************************************************************//
  // Memory Models instantiations
  //**************************************************************************//

  genvar r,i;
  generate
    for (r = 0; r < CS_WIDTH; r = r + 1) begin: mem_rnk
      for (i = 0; i < NUM_COMP; i = i + 1) begin: gen_mem
        ddr3_model u_comp_ddr3
          (
           .rst_n   (ddr3_reset_n),
           .ck      (ddr3_ck_p_sdram),
           .ck_n    (ddr3_ck_n_sdram),
           .cke     (ddr3_cke_sdram[r]),
           .cs_n    (ddr3_cs_n_sdram[r]),
           .ras_n   (ddr3_ras_n_sdram),
           .cas_n   (ddr3_cas_n_sdram),
           .we_n    (ddr3_we_n_sdram),
           .dm_tdqs (ddr3_dm_sdram[i]),
           .ba      (ddr3_ba_sdram[r]),
           .addr    (ddr3_addr_sdram[r]),
           .dq      (ddr3_dq_sdram[MEMORY_WIDTH*(i+1)-1:MEMORY_WIDTH*(i)]),
           .dqs     (ddr3_dqs_p_sdram[i]),
           .dqs_n   (ddr3_dqs_n_sdram[i]),
           .tdqs_n  (),
           .odt     (ddr3_odt_sdram[r])
           );
      end
    end
  endgenerate

  //**************************************************************************//
  // DDR controller <--> DDR model Logic
  //**************************************************************************//

  //assign init_calib_complete = 1'b1;
  assign init_calib_complete = ui_phy_init_done;

  always @( * ) begin
    ddr3_ck_p_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_p_fpga;
    ddr3_ck_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_ck_n_fpga;
    ddr3_addr_sdram[0]   <=  #(TPROP_PCB_CTRL) ddr3_addr_fpga;
    ddr3_addr_sdram[1]   <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {ddr3_addr_fpga[ROW_WIDTH-1:9],
                                                  ddr3_addr_fpga[7], ddr3_addr_fpga[8],
                                                  ddr3_addr_fpga[5], ddr3_addr_fpga[6],
                                                  ddr3_addr_fpga[3], ddr3_addr_fpga[4],
                                                  ddr3_addr_fpga[2:0]} :
                                                 ddr3_addr_fpga;
    ddr3_ba_sdram[0]     <=  #(TPROP_PCB_CTRL) ddr3_ba_fpga;
    ddr3_ba_sdram[1]     <=  #(TPROP_PCB_CTRL) (CA_MIRROR == "ON") ?
                                                 {ddr3_ba_fpga[BANK_WIDTH-1:2],
                                                  ddr3_ba_fpga[0],
                                                  ddr3_ba_fpga[1]} :
                                                 ddr3_ba_fpga;
    ddr3_ras_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_ras_n_fpga;
    ddr3_cas_n_sdram     <=  #(TPROP_PCB_CTRL) ddr3_cas_n_fpga;
    ddr3_we_n_sdram      <=  #(TPROP_PCB_CTRL) ddr3_we_n_fpga;
    ddr3_cke_sdram       <=  #(TPROP_PCB_CTRL) ddr3_cke_fpga;
  end


  always @( * )
    ddr3_cs_n_sdram_tmp   <=  #(TPROP_PCB_CTRL) ddr3_cs_n_fpga;
  assign ddr3_cs_n_sdram =  ddr3_cs_n_sdram_tmp;


  always @( * )
    ddr3_dm_sdram_tmp <=  #(TPROP_PCB_DATA) ddr3_dm_fpga;//DM signal generation
  assign ddr3_dm_sdram = ddr3_dm_sdram_tmp;


  always @( * )
    ddr3_odt_sdram_tmp  <=  #(TPROP_PCB_CTRL) ddr3_odt_fpga;
  assign ddr3_odt_sdram =  ddr3_odt_sdram_tmp;


  assign sys_rst_n = sys_rstn;
// Controlling the bi-directional BUS

  genvar dqwd;
  generate
    for (dqwd = 1;dqwd < DQ_WIDTH;dqwd = dqwd+1) begin : dq_delay
      WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dq
       (
        .A             (ddr3_dq_fpga[dqwd]),
        .B             (ddr3_dq_sdram[dqwd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
    // For ECC ON case error is inserted on LSB bit from DRAM to FPGA
          WireDelay #
       (
        .Delay_g    (TPROP_PCB_DATA),
        .Delay_rd   (TPROP_PCB_DATA_RD),
        .ERR_INSERT (ECC)
       )
      u_delay_dq_0
       (
        .A             (ddr3_dq_fpga[0]),
        .B             (ddr3_dq_sdram[0]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
  endgenerate

  genvar dqswd;
  generate
    for (dqswd = 0;dqswd < DQS_WIDTH;dqswd = dqswd+1) begin : dqs_delay
      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_p
       (
        .A             (ddr3_dqs_p_fpga[dqswd]),
        .B             (ddr3_dqs_p_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );

      WireDelay #
       (
        .Delay_g    (TPROP_DQS),
        .Delay_rd   (TPROP_DQS_RD),
        .ERR_INSERT ("OFF")
       )
      u_delay_dqs_n
       (
        .A             (ddr3_dqs_n_fpga[dqswd]),
        .B             (ddr3_dqs_n_sdram[dqswd]),
        .reset         (sys_rst_n),
        .phy_init_done (init_calib_complete)
       );
    end
  endgenerate

  //**************************************************************************//
  // Stimulus to DUT
  //**************************************************************************//
  reg [31:0] acq_channel_sample_size [4:0];
  genvar acq_ch;
  generate
    for (acq_ch = 0; acq_ch < c_n_chan; acq_ch = acq_ch + 1) begin
      initial
        acq_channel_sample_size[acq_ch] = (dut.g_facq_channels[acq_ch].width > DDR3_PAYLOAD_WIDTH)?
            DDR3_PAYLOAD_WIDTH : dut.g_facq_channels[acq_ch].width;
    end
  endgenerate

  reg data_start_ok = 1'b0;
  reg data_valid_num_samp = 1'b0;
  initial begin

    // Initial values for ADC data signals
    data_gen_start = 1'b0;
    test_in_progress = 1'b0;
    dbg_ddr_rb0_start_counter = 'h0;
    dbg_ddr_rb1_start_counter = 'h0;
    // Default values. No wait
    min_wait_gnt = 0;
    max_wait_gnt = 0;
    // Default values. 200 ADC CLK cycles after star wait
    min_wait_trig = 200;
    max_wait_trig = 200;

    $display("-----------------------------------");
    $display("@%0d: Simulation of BPM ACQ FSM starting!", $time);
    $display("-----------------------------------");

    $display("-----------------------------------");
    $display("@%0d: Initialization  Begin", $time);
    $display("-----------------------------------");

    $display("-----------------------------------");
    $display("@%0d: Waiting for all resets...", $time);
    $display("-----------------------------------");

    wait (WB0.ready);
    wait (WB1.ready);
    wait (sys_rstn);
    wait (adc_rstn);

    $display("@%0d: Reset done!", $time);

    $display("-----------------------------------");
    $display("@%0d: Waiting for Memory initilization/calibration...", $time);
    $display("-----------------------------------");

    wait (init_calib_complete);

    $display("@%0d: Memory initialization/calibration done!", $time);

    data_gen_start = 1'b1;

    @(posedge sys_clk);

    $display("-------------------------------------");
    $display("@%0d:  Initialization  Done!", $time);
    $display("-------------------------------------");

    ////////////////////////
    // TEST #1
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////
    test_id = 1;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 32;
    max_wait_gnt_l = 128;
    data_valid_prob = 1.0;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b0;
    data_valid_zero_cycles = 100;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #2
    // Number of shots = 1
    // Pre trigger samples only
    // Only specified number of samples generated
    // No trigger
    ////////////////////////
    test_id = 2;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 32;
    max_wait_gnt_l = 128;
    data_valid_prob = 1.0;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b0;
    data_valid_zero_cycles = 100;
    data_valid_num_samp = 1'b1;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #3
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////
    test_id = 3;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 32;
    max_wait_gnt_l = 128;
    data_valid_prob = 0.7;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #4
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 4;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000100;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 256;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.7;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #5
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    // Larger channel
    ////////////////////////

    test_id = 5;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000100;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd1;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 256;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.7;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #6
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 6;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000400;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 1024; // watch for errors here!
    max_wait_gnt_l = 2048; // watch for errors here!
    data_valid_prob = 1.0;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #7
    // Number of shots = 2
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 7;
    n_shots = 16'h0002;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 64;
    max_wait_gnt_l = 128;
    data_valid_prob = 0.7;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #8
    // Number of shots = 16
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 8;
    n_shots = 16'h0010;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 64;
    max_wait_gnt_l = 128;
    data_valid_prob = 0.6;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #9
    // Number of shots = 16
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 9;
    n_shots = 16'h0010;
    pre_trig_samples = 32'h00000020;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.6;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #10
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 10;
    n_shots = 16'h0010;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 64;
    max_wait_gnt_l = 128;
    data_valid_prob = 0.6;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #11
    // Number of shots = 16
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 11;
    n_shots = 16'h0010;
    pre_trig_samples = 32'h00000020;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.6;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #12
    // Number of shots = 1
    // Pre trigger samples only, small amount
    // No trigger
    ////////////////////////
    test_id = 12;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000004;
    post_trig_samples = 32'h00000000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b1;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 32;
    max_wait_gnt_l = 128;
    data_valid_prob = 1.0;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b0;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // Trigger Tests
    ////////////////////////

    ////////////////////////
    // TEST #13
    // Number of shots = 1
    // Pre trigger samples
    // Post trigger samples
    // With trigger
    ////////////////////////
    test_id = 13;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000010;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 1.0;
    min_wait_trig_l = 1000;
    max_wait_trig_l = 1200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #14
    // Number of shots = 1
    // Pre trigger samples
    // Post trigger samples
    // With trigger
    ////////////////////////
    test_id = 14;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000100;
    post_trig_samples = 32'h00000010;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 1.0;
    min_wait_trig_l = 1000;
    max_wait_trig_l = 1200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #15
    // Number of shots = 1
    // Pre trigger samples
    // Post trigger samples
    // With trigger
    ////////////////////////
    test_id = 15;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000010;
    post_trig_samples = 32'h00000100;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.6;
    min_wait_trig_l = 1000;
    max_wait_trig_l = 1200;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #16
    // Number of shots = 1
    // Pre trigger samples
    // Post trigger samples
    // With trigger
    ////////////////////////
    test_id = 16;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000100;
    post_trig_samples = 32'h00001000;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.8;
    min_wait_trig_l = 1000;
    max_wait_trig_l = 1500;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #17
    // Number of shots = 16
    // Pre trigger samples
    // Post trigger samples
    // With trigger
    ////////////////////////
    test_id = 17;
    n_shots = 16'h0010;
    pre_trig_samples = 32'h00000100;
    post_trig_samples = 32'h00000100;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    stop_on_error = 1'b1;
    min_wait_gnt_l = 128;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.7;
    min_wait_trig_l = 1000;
    max_wait_trig_l = 2000;
    hw_trig_sel = 1'b1; // External trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h000FFFFF;
    hw_int_trig_thres_filt = 8'b00001111;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    ////////////////////////
    // TEST #18
    // Number of shots = 1
    // Pre trigger samples only
    // No trigger
    ////////////////////////

    test_id = 18;
    n_shots = 16'h0001;
    pre_trig_samples = 32'h00000040;
    post_trig_samples = 32'h00000040;
    ddr3_start_addr = 32'h00000000; // all zeros for now
    ddr3_end_addr = 32'h00100000;
    acq_chan = 16'd0;
    lmt_pkt_size = (pre_trig_samples + post_trig_samples)/(DDR3_PAYLOAD_WIDTH/acq_channel_sample_size[acq_chan]);
    skip_trig = 1'b0;
    wait_finish = 1'b1;
    min_wait_gnt_l = 256;
    max_wait_gnt_l = 512;
    data_valid_prob = 0.7;
    min_wait_trig_l = 100;
    max_wait_trig_l = 200;
    hw_trig_sel = 1'b0; // Data-driven trigger
    hw_trig_en = 1'b1;
    hw_trig_dly = 'h0;
    hw_int_trig_thres = 32'h00000010;
    hw_int_trig_thres_filt = 8'b00000001;
    sw_trig_en = 1'b0;
    data_valid_prob_gen = 1'b1;
    data_valid_zero_cycles = 0;
    data_valid_num_samp = 1'b0;

    wb_acq(test_id, n_shots,
                pre_trig_samples, post_trig_samples,
                hw_trig_sel, hw_trig_en, hw_trig_dly, hw_int_trig_thres,
                hw_int_trig_thres_filt, sw_trig_en,
                ddr3_start_addr, ddr3_end_addr, acq_chan, skip_trig,
                wait_finish, stop_on_error, min_wait_gnt_l,
                max_wait_gnt_l, min_wait_trig_l,
                max_wait_trig_l, data_valid_prob,
                data_valid_prob_gen, data_valid_zero_cycles,
                data_valid_num_samp);

    $display("Simulation Done!");
    $display("All Tests Passed!");
    $display("---------------------------------------------");
    $finish;
  end

  // Generate data and valid signals on positive edge of clock

  reg [31:0] data_valid_counter [c_n_chan-1:0];
  reg [31:0] data_valid_counter_trans [c_n_chan-1:0];
  reg [31:0] data_valid_zero_cycles_task = 'h0;
  reg data_valid_prob_gen_task;
  reg data_valid_num_samp_task;
  reg [31:0] num_samples_all_task = 'h0;
  initial begin
    data_valid_counter[0] = 'h0;
    data_valid_counter_trans[0] = 'h0;
    data_valid_zero_cycles_task = 'h0;
    data_valid_prob_gen_task = 1'b0;
    data_test[0] <= 'h0;
    data_test_trig[0] <= 1'b0;
  end

  always @(posedge adc_clk)
  begin
    if (!test_in_progress) begin
      data_valid_counter[0] <= 'h0;
      data_valid_counter_trans[0] <= 'h0;
      data_test_dvalid_t[0] <= 1'b0;
    end else begin
      if (data_gen_start && data_start_ok) begin
        //data_test <= f_data_gen(c_data_max);
        if (data_test_dvalid_t[0]) begin
        //  data_test[0] <= {data_test_0 + 16'h30, data_test_0 + 16'h20,
        //                                  data_test_0 + 16'h10, data_test_0 + 16'h00};
          data_test[0] <= {
              data_test_0 + 16'hF0, data_test_0 + 16'hE0,
              data_test_0 + 16'hD0, data_test_0 + 16'hC0,

              data_test_0 + 16'hB0, data_test_0 + 16'hA0,
              data_test_0 + 16'h90, data_test_0 + 16'h80,

              data_test_0 + 16'h70, data_test_0 + 16'h60,
              data_test_0 + 16'h50, data_test_0 + 16'h40,

              data_test_0 + 16'h30, data_test_0 + 16'h20,
              data_test_0 + 16'h10, data_test_0 + 16'h00
              };
          data_test_0 <= data_test_0 + 1;
        end

        if (data_valid_prob_gen_task)  begin
          data_test_dvalid_t[0] <= f_gen_data_rdy_gen(data_valid_threshold);
        end else begin
          if (data_valid_counter[0] == data_valid_zero_cycles_task) begin
            data_valid_counter[0] <= 'h0;
            data_valid_counter_trans[0] <= data_valid_counter_trans[0] + 1;
            data_test_dvalid_t[0] <= 1'b1;
          end else begin
            data_test_dvalid_t[0] <= 1'b0;
            if (!data_valid_num_samp_task ||
                (data_valid_num_samp_task &&
                  data_valid_counter_trans[0] != num_samples_all_task)) begin
              data_valid_counter[0] <= data_valid_counter[0] + 1;
            end
          end
        end

        data_test_dvalid[0] <= data_test_dvalid_t[0];
        data_test_trig[0] <= data_trig;
      end else begin
        data_test_0 <= 'h0;
        data_test[0] <= 'h0;
        data_test_dvalid[0] <= 1'b0;
        data_test_dvalid_t[0] <= 1'b0;
        data_test_trig[0] <= 1'b0;
      end
    end
  end

  genvar ch;

  generate
    for (ch = 1; ch < c_n_chan; ch = ch + 1) begin: gen_chan
      initial begin
        data_valid_counter[ch] = 'h0;
        data_valid_counter_trans[ch] = 'h0;
        data_test_trig[ch] = 0;
        data_test[ch] = 0;
      end

      always @(posedge adc_clk)
      begin
        if (!test_in_progress) begin
          data_valid_counter[ch] <= 'h0;
          data_valid_counter_trans[ch] <= 'h0;
          data_test_dvalid_t[ch] <= 1'b0;
        end else begin
          if (data_gen_start) begin
            //data_test <= f_data_gen(c_data_max);
            if (data_test_dvalid_t[ch]) begin
              data_test[ch] <= data_test[ch] + ch + 1;
            end

            if (data_valid_prob_gen_task)  begin
              data_test_dvalid_t[ch] <= f_gen_data_rdy_gen(data_valid_threshold);
            end else begin
              if (data_valid_counter[ch] == data_valid_zero_cycles_task) begin
                data_valid_counter[ch] <= 'h0;
                data_valid_counter_trans[ch] <= data_valid_counter_trans[ch] + 1;
                data_test_dvalid_t[ch] <= 1'b1;
              end else begin
                data_test_dvalid_t[ch] <= 1'b0;
                if (!data_valid_num_samp_task ||
                    (data_valid_num_samp_task &&
                      data_valid_counter_trans[ch] != num_samples_all_task)) begin
                  data_valid_counter[ch] <= data_valid_counter[ch] + 1;
                end
              end
            end

            data_test_dvalid[ch] <= data_test_dvalid_t[ch];
            data_test_trig[ch] <= data_trig;
          end else begin
            data_test[ch] <= 'h0;
            data_test_dvalid[ch] <= 1'b0;
            data_test_dvalid_t[ch] <= 1'b0;
            data_test_trig[ch] <= 1'b0;
          end
        end
      end
    end
  endgenerate

  /////////////////////////////////////////////////////////////////////////////
  // Functions
  /////////////////////////////////////////////////////////////////////////////
  function automatic [`DATA_TEST_WIDTH-1:0] f_data_gen;
    input integer max_size;
  begin
    // $random is surronded by the concat operator in order
    // to provide us with only unsigned (bit vector) data
    f_data_gen = {$random} % max_size;
  end
  endfunction

  function automatic f_gen_data_rdy_gen;
    input real prob;
  begin
    f_gen_data_rdy_gen = f_gen_bit_one(prob);
  end
  endfunction

  function automatic f_gen_data_stall;
    input real prob;
  begin
    f_gen_data_stall = f_gen_bit_one(1.0-prob);
  end
  endfunction

  function automatic f_gen_bit_one;
    input real prob;
    real temp;
  begin

    // $random is surronded by the concat operator in order
    // to provide us with only unsigned (bit vector) data.
    // Generates valud in a 0..1 range
    temp = ({$random} % 100 + 1)/100.00;//threshold;

    if (temp <= prob)
      f_gen_bit_one = 1'b1;
    else
      f_gen_bit_one = 1'b0;
  end
  endfunction

  function automatic integer f_gen_lmt;
    input integer min;
    input integer max;
    real temp;
  begin
    // $random is surronded by the concat operator in order
    // to provide us with only unsigned (bit vector) data.
    f_gen_lmt = ({$random} % (max-min) + min);

  end
  endfunction

  /////////////////////////////////////////////////////////////////////////////
  // Tasks
  /////////////////////////////////////////////////////////////////////////////

  task wb_busy_wait0;
    input [`WB_ADDRESS_BUS_WIDTH-1:0] addr;
    input [`WB_DATA_BUS_WIDTH-1:0] mask;
    input [`WB_DATA_BUS_WIDTH-1:0] offset;
    input verbose;

    reg [`WB_DATA_BUS_WIDTH-1:0] tmp_reg0;
    reg [`WB_DATA_BUS_WIDTH-1:0] tmp_reg1;
  begin
    WB0.monitor_bus(1'b0);
    WB0.verbose(1'b0);

    WB0.read32(addr, tmp_reg0);

    while (((tmp_reg0 & mask) >> offset) != 'h1) begin
      if (verbose)
        $write(".");

      @(posedge sys_clk);
      WB0.read32(addr, tmp_reg0);
    end

    WB0.monitor_bus(1'b1);
    WB0.verbose(1'b1);
  end
  endtask

  task wb_busy_wait1;
    input [`WB_ADDRESS_BUS_WIDTH-1:0] addr;
    input [`WB_DATA_BUS_WIDTH-1:0] mask;
    input [`WB_DATA_BUS_WIDTH-1:0] offset;
    input verbose;

    reg [`WB_DATA_BUS_WIDTH-1:0] tmp_reg0;
    reg [`WB_DATA_BUS_WIDTH-1:0] tmp_reg1;
  begin
    WB1.monitor_bus(1'b0);
    WB1.verbose(1'b0);

    WB1.read32(addr, tmp_reg1);

    while (((tmp_reg1 & mask) >> offset) != 'h1) begin
      if (verbose)
        $write(".");

      @(posedge sys_clk);
      WB1.read32(addr, tmp_reg1);
    end

    WB1.monitor_bus(1'b1);
    WB1.verbose(1'b1);
  end
  endtask

  task wb_acq;
    input integer test_id;
    input [15:0] n_shots;
    input [31:0] pre_trig_samples;
    input [31:0] post_trig_samples;
    input hw_trig_sel; // 0 is Data-driven trigger, 1 is External trigger
    input hw_trig_en; // Data-driven trigger enable
    input [31:0] hw_trig_dly;
    input [31:0] hw_int_trig_thres;
    input [7:0] hw_int_trig_thres_filt;
    input sw_trig_en; // Software trigger enable
    input [31:0] ddr3_start_addr;
    input [31:0] ddr3_end_addr;
    input [15:0] acq_chan;
    input skip_trig;
    input wait_finish;
    input stop_on_error;
    input integer min_wait_gnt_l;
    input integer max_wait_gnt_l;
    input integer min_wait_trig_l;
    input integer max_wait_trig_l;
    //input real ext_stall_prob;
    input real data_valid_prob;
    input data_valid_prob_gen;
    input [31:0] data_valid_zero_cycles;
    input data_valid_num_samp;

    reg [31:0] acq_core_fsm_ctl_reg;
    reg [31:0] acq_core_trig_cfg_reg;
    reg [31:0] acq_core_trig_data_cfg;
  begin
    $display("#############################");
    $display("######## TEST #%03d ######", test_id);
    $display("#############################");
    $display("## Number of shots = %03d", n_shots);
    $display("## Number of pre samples = %03d", pre_trig_samples);
    $display("## Skip trigger = %d", skip_trig);
    $display("## Number of post samples = %03d", post_trig_samples);
    $display("## Minimum number of wait cycles DDR3 access = %03d", min_wait_gnt_l);
    $display("## Maximum number of wait cycles DDR3 access = %03d", max_wait_gnt_l);
    $display("## Minimum number of wait cycles SW Trigger= %03d", min_wait_trig_l);
    $display("## Maximum number of wait cycles SW Trigger= %03d", max_wait_trig_l);

    $display("Setting throttling parameters scenario");
    //$display("Setting sink stall probability = %.2f%%", ext_stall_prob*100);
    //$display("Setting sink rdy probability = %.2f%%", (1-ext_stall_prob)*100);
    $display("Setting source data valid input probability = %.2f%%", data_valid_prob*100);
    $display("Using data_valid probabilistic generator = %d", data_valid_prob_gen);
    $display("Setting data_valid zero cycles = %d", data_valid_zero_cycles);
    $display("Setting data_valid only to specified number of samples = %d",data_valid_num_samp);

    //@(posedge sys_clk);
    //test_in_progress = 1'b0;

    @(posedge sys_clk);
    //data_ext_stall_threshold = 0.3;
    //data_ext_rdy_threshold = 0.7;
    //data_valid_threshold = 0.7;
    data_valid_threshold = data_valid_prob; // modify external register! FIXME?
    data_valid_prob_gen_task = data_valid_prob_gen;
    data_valid_zero_cycles_task = data_valid_zero_cycles;
    min_wait_gnt = min_wait_gnt_l; // modify external register! FIXME?
    max_wait_gnt = max_wait_gnt_l; // modify external register! FIXME?

    // Wait for some time and then trigger the acquisition
    min_wait_trig = min_wait_trig_l; // modify external register! FIXME?
    max_wait_trig = max_wait_trig_l; // modify external register! FIXME?

    test_in_progress = 1'b1;

    $display("Setting # of shots to %03d", n_shots);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_SHOTS >> `WB_WORD_ACC, (n_shots << `ACQ_CORE_SHOTS_NB_OFFSET));
    WB1.write32(`ADDR_ACQ_CORE_SHOTS >> `WB_WORD_ACC, (n_shots << `ACQ_CORE_SHOTS_NB_OFFSET));

    $display("Setting # of pre-trigger to %03d", pre_trig_samples);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_PRE_SAMPLES >> `WB_WORD_ACC, (pre_trig_samples));
    WB1.write32(`ADDR_ACQ_CORE_PRE_SAMPLES >> `WB_WORD_ACC, (pre_trig_samples));

    $display("Setting # of pos-trigger to %03d", post_trig_samples);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_POST_SAMPLES >> `WB_WORD_ACC, (post_trig_samples));
    WB1.write32(`ADDR_ACQ_CORE_POST_SAMPLES >> `WB_WORD_ACC, (post_trig_samples));

    // Calculate total number of samples
    num_samples_all_task = n_shots*(pre_trig_samples + post_trig_samples);

    // Prepare CFG trigger register
    acq_core_trig_cfg_reg = (hw_trig_sel) << `ACQ_CORE_TRIG_CFG_HW_TRIG_SEL_OFFSET;

    $display("Selecting external HW trigger: %d", hw_trig_sel);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);

    acq_core_trig_cfg_reg = (acq_core_trig_cfg_reg) | ((hw_trig_en) << `ACQ_CORE_TRIG_CFG_HW_TRIG_EN_OFFSET);

    $display("Enabling HW trigger: %d", hw_trig_en);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);

    // Prepare CFG trigger register
    acq_core_trig_cfg_reg = (acq_core_trig_cfg_reg) | ((sw_trig_en) << `ACQ_CORE_TRIG_CFG_SW_TRIG_EN_OFFSET);

    $display("Enabling SW trigger: %d", sw_trig_en);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_CFG >> `WB_WORD_ACC, acq_core_trig_cfg_reg);

    // Prepare trigger delay register
    $display("Setting trigger delay to %d", hw_trig_dly);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_DLY >> `WB_WORD_ACC, hw_trig_dly);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_DLY >> `WB_WORD_ACC, hw_trig_dly);

    // Prepare HW trigger threshold
    $display("Setting HW data threshold to %d", hw_int_trig_thres);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_DATA_THRES >> `WB_WORD_ACC, hw_int_trig_thres);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_DATA_THRES >> `WB_WORD_ACC, hw_int_trig_thres);

    // Prepare HW trigger filter
    acq_core_trig_data_cfg = (hw_int_trig_thres_filt << `ACQ_CORE_TRIG_DATA_CFG_THRES_FILT_OFFSET);

    $display("Setting HW data filter to %d", hw_int_trig_thres_filt);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_TRIG_DATA_CFG >> `WB_WORD_ACC, acq_core_trig_data_cfg);
    WB1.write32(`ADDR_ACQ_CORE_TRIG_DATA_CFG >> `WB_WORD_ACC, acq_core_trig_data_cfg);

    // Prepare core_ctl register
    acq_core_fsm_ctl_reg = (skip_trig) << `ACQ_CORE_CTL_FSM_ACQ_NOW_OFFSET;

    $display("Setting skip trigger parameter to %d", skip_trig);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_CTL >> `WB_WORD_ACC, acq_core_fsm_ctl_reg);
    WB1.write32(`ADDR_ACQ_CORE_CTL >> `WB_WORD_ACC, acq_core_fsm_ctl_reg);

    $display("Setting DDR3 start address for the next acquistion \
        WB0:0x%08X,WB1:0x%08X", ddr3_start_addr,
        ddr3_start_addr + c_ddr3_acq1_addr_offset);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_DDR3_START_ADDR >> `WB_WORD_ACC, ddr3_start_addr);
    WB1.write32(`ADDR_ACQ_CORE_DDR3_START_ADDR >> `WB_WORD_ACC, ddr3_start_addr + c_ddr3_acq1_addr_offset);

    $display("Setting DDR3 end address for the next acquistion \
        WB0:0x%08X,WB1:0x%08X", ddr3_end_addr,
        ddr3_end_addr + c_ddr3_acq1_addr_offset);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_DDR3_END_ADDR >> `WB_WORD_ACC, ddr3_end_addr);
    WB1.write32(`ADDR_ACQ_CORE_DDR3_END_ADDR >> `WB_WORD_ACC, ddr3_end_addr + c_ddr3_acq1_addr_offset);

    $display("Setting acquisition channel for the next acquistion %d", acq_chan);
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_ACQ_CHAN_CTL >> `WB_WORD_ACC,
              (acq_chan << `ACQ_CORE_ACQ_CHAN_CTL_WHICH_OFFSET) & `ACQ_CORE_ACQ_CHAN_CTL_WHICH);
    WB1.write32(`ADDR_ACQ_CORE_ACQ_CHAN_CTL >> `WB_WORD_ACC,
              (acq_chan << `ACQ_CORE_ACQ_CHAN_CTL_WHICH_OFFSET) & `ACQ_CORE_ACQ_CHAN_CTL_WHICH);

    // Prepare core_ctl register
    acq_core_fsm_ctl_reg = (acq_core_fsm_ctl_reg) | (`ACQ_CORE_CTL_FSM_START_ACQ);

    $display("Starting acquisition... ");
    @(posedge sys_clk);
    WB0.write32(`ADDR_ACQ_CORE_CTL >> `WB_WORD_ACC, acq_core_fsm_ctl_reg);
    WB1.write32(`ADDR_ACQ_CORE_CTL >> `WB_WORD_ACC, acq_core_fsm_ctl_reg);

    @(posedge sys_clk);
    data_start_ok = 1'b1;
    data_valid_num_samp_task = data_valid_num_samp;

    // ACQ Core 0
    if (wait_finish) begin
      $display("Waiting until all data have been acquired...\n");
      @(posedge sys_clk);
      wb_busy_wait0(`ADDR_ACQ_CORE_STA >> `WB_WORD_ACC, `ACQ_CORE_STA_DDR3_TRANS_DONE,
                      `ACQ_CORE_STA_DDR3_TRANS_DONE_OFFSET, 1'b1);
    end

    $display("Done!");
    //$display("Waiting data check...");

    wait (chk0_end); // data checker ended

    $display("Data checker detected a total of %03d data mismatch errors", chk0_data_err_cnt);
    $display("Data checker detected a total of %03d addr mismatch errors", chk0_addr_err_cnt);

    if (stop_on_error & (chk0_data_err | chk0_addr_err)) begin
      $display("Acq core 0, TEST #%03d NOT PASS!", test_id);
      $finish;
    end

    $display("\n");

    // ACQ Core 1
    if (wait_finish) begin
      $display("Waiting until all data have been acquired...\n");
      @(posedge sys_clk);
      //wb_busy_wait(`ADDR_ACQ_CORE_STA >> `WB_WORD_ACC, `ACQ_CORE_STA_FC_TRANS_DONE,
      //                `ACQ_CORE_STA_FC_TRANS_DONE_OFFSET, 1'b1);
      wb_busy_wait1(`ADDR_ACQ_CORE_STA >> `WB_WORD_ACC, `ACQ_CORE_STA_DDR3_TRANS_DONE,
                      `ACQ_CORE_STA_DDR3_TRANS_DONE_OFFSET, 1'b1);
    end

    $display("Done!");
    //$display("Waiting data check...");

    wait (chk1_end); // data checker ended

    $display("Data checker detected a total of %03d data mismatch errors", chk1_data_err_cnt);
    $display("Data checker detected a total of %03d addr mismatch errors", chk1_addr_err_cnt);

    if (stop_on_error & (chk1_data_err | chk1_addr_err)) begin
      $display("Acq core 1, TEST #%03d NOT PASS!", test_id);
      $finish;
    end

    $display("\n");

    @(posedge sys_clk);
    test_in_progress = 1'b0;
    data_start_ok = 1'b0;

    // give some time for all the modules that ned a reset between tests
    repeat (2) begin
      @(posedge sys_clk);
    end

  end
  endtask

endmodule
