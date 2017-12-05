-------------------------------------------------------------------------------
-- Title      : Trigger Physical Interface
-- Project    :
-------------------------------------------------------------------------------
-- File       : trigger_io_physical.vhd
-- Author     : Lucas Russo  <lerwys@gmail.com>
-- Company    :
-- Created    : 2017-11-14
-- Last update:
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Send/Receives trigger to/from a hardware line. It supports,
-- debouncing, extension, polarity, direction control and controllable delay.
--
-- It implements the wired-OR logic with trigger lines, as described
-- in www.ti.com/lit/pdf/snla113, page 11. It works as follows:
--
-- If we want to output data, we use the direction pin as data and
-- drive the actual output to HI. This would only drive the line
-- when we send data.
--
-- If we want to input data, we use the pins as usual: data as data and
-- direction as direction.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2017-11-14  1.0      lerwys  Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ifc_common_pkg.all;
use work.platform_generic_pkg.all;

entity trigger_io_physical is
generic
(
  -- "true" to use external bidirectional trigger (*_b port) or "false"
  -- to use separate ports for external trigger input/output
  g_with_bidirectional_trigger             : boolean := true;
  -- IOBUF instantiation type if g_with_bidirectional_trigger = true.
  -- Possible values are: "native" or "inferred"
  g_iobuf_instantiation_type               : string := "native"
);
port
(
  -- Clock/Resets
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -------------------------------
  -- Trigger configuration
  -------------------------------
  -- Trigger direction. Set to '1' to 1 will set the FPGA
  -- to output and set to '0' will set the
  -- FPGA to input
  trig_dir_i                               : in std_logic;
  -- External direction polarity. This affects the behavior
  -- of trig_tx_o and trig_ext_dir_o. Set to '1' to use
  -- reverse polarity between the internal FPGA IO buffer and
  -- a possibly external IO buffer. Set to '0' to use the same
  -- polarity. If not using an external buffer, just leave it
  -- to '0'
  trig_ext_dir_pol_i                       : in std_logic;
  -- Output trigger polarity. Set to '1' to use reverse polarity
  -- ('1' to '0' output pulse). Set to '0' to use regular polarity
  -- ('0' to '1' output pulse)
  trig_pol_i                               : in std_logic;

  -------------------------------
  ---- External ports
  -------------------------------
  trig_dir_o                               : out std_logic;
  -- If using g_with_bidirectional_trigger = true
  trig_b                                   : inout std_logic := '0';
  -- If using g_with_bidirectional_trigger = false
  trig_i                                   : in std_logic := '0';
  trig_o                                   : out std_logic;

  -------------------------------
  -- Trigger input/output ports
  -------------------------------
  -- Trigger data input from FPGA
  trig_in_i                                : in std_logic;
  -- Trigger data output from FPGA
  trig_out_o                               : out std_logic
);
end entity trigger_io_physical;

architecture rtl of trigger_io_physical is

  -- Trigger direction constants
  constant c_trig_dir_fpga_input           : std_logic := '1';
  constant c_trig_dir_fpga_output          : std_logic := not (c_trig_dir_fpga_input);

  -- Signals
  signal trig_rx                           : std_logic;
  signal trig_rx_fpga                      : std_logic;
  signal trig_tx                           : std_logic;
  signal trig_tx_fpga                      : std_logic;
  signal trig_tx_int                       : std_logic;

  signal trig_dir                          : std_logic;
  signal trig_dir_int                      : std_logic;
  signal trig_ext_dir_pol_int              : std_logic;
  signal trig_pol_int                      : std_logic;
  signal trig_dir_polarized                : std_logic;
  signal trig_tx_polarized                 : std_logic;
  signal trig_dir_ext                      : std_logic;

begin

  -- Test for IOBUF instantiation types
  assert (g_iobuf_instantiation_type = "native" or g_iobuf_instantiation_type = "inferred")
  report "[trigger_io_physical] Only g_iobuf_instantiation_type = native or inferred are available"
  severity failure;

  -----------------------------------------------------------------------------
  -- Trigger to/from FPGA side assignments
  ----------------------------------------------------------------------------
  trig_tx_fpga <= trig_in_i;
  trig_out_o <= trig_rx_fpga;

  -----------------------------------------------------------------------------
  -- Trigger data/direction control
  ----------------------------------------------------------------------------
  -- Notice that for FPGA direction:
  --   Direction pin 0 = Output from FPGA
  --   Direction pin 1 = Input to FPGA
  --
  -- So, we must negate the data pin so, sending 1 will set the FPGA
  -- to output ('0' in iobuf) and sending 0 will set the FPGA to input
  -- ('1' in iobuf)
  trig_dir_int  <= trig_dir_i;
  trig_ext_dir_pol_int  <= trig_ext_dir_pol_i;
  trig_pol_int <= trig_pol_i;

  gen_with_bidir_data_int : if g_with_bidirectional_trigger generate
    trig_tx_int <= not (trig_tx_fpga);
  end generate;

  gen_without_bidir_data_int : if not(g_with_bidirectional_trigger) generate
    trig_tx_int <= trig_tx_fpga;
  end generate;

  -- Regular data/direction driving with polarity inversion
  trig_dir_polarized  <= trig_dir_int when trig_ext_dir_pol_int = '0' else
                             not (trig_dir_int);
  trig_tx_polarized <= trig_tx_int when trig_pol_int = '0' else
                              not (trig_tx_int);

  -----------------------------------------------------------------------------
  -- Wired-OR scheme
  ----------------------------------------------------------------------------
  -- Use data/direction pin as data depending if we are input or output.
  -- If it's input, we just need to use the direction according to the
  -- polarity ('0' means same polarity, '1' means reversed polarity).
  --
  -- We could have used just "not (trig_dir_int)" instead of trig_dir_polarized
  -- here, but we opted for clarity in the hope the tools will optimize this
  trig_dir_ext  <= trig_tx_polarized when trig_dir_int = c_trig_dir_fpga_output else
                     trig_dir_polarized;
  trig_tx <= '1' when trig_dir_int = c_trig_dir_fpga_output else '0';

  -- Internal buffer direction/data
  trig_dir  <= trig_tx_int when trig_dir_int = c_trig_dir_fpga_output else
                            trig_dir_int;

  -----------------------------------------------------------------------------
  -- Trigger to/from physical side assignments
  ----------------------------------------------------------------------------

  gen_with_bidir_trigger : if g_with_bidirectional_trigger generate

    gen_with_native_iobuf : if g_iobuf_instantiation_type = "native" generate

      cmp_iobuf_generic : iobuf_generic
      port map (
        buffer_o                                      => trig_rx,
        buffer_b                                      => trig_b,
        buffer_i                                      => trig_tx,
        buffer_t                                      => trig_dir
      );
    end generate;

    gen_with_inferred_iobuf : if g_iobuf_instantiation_type = "inferred" generate

      trig_b <= trig_tx when trig_dir = '0' else 'Z';
      trig_rx <= trig_b;

    end generate;

    trig_rx_fpga <= trig_rx when trig_dir_int = c_trig_dir_fpga_input
                       else '0'; -- FPGA is output
    -- Trigger direction external output
    trig_dir_o <= trig_dir_ext;

  end generate;

  gen_without_bidir_trigger : if not(g_with_bidirectional_trigger) generate

    trig_rx_fpga      <= trig_i;
    -- Use regular data/dir pins, as we don't implement the wired-OR logic in
    -- this case
    trig_o            <= trig_tx_polarized;
    -- Trigger direction external output
    trig_dir_o        <= trig_dir_polarized;

  end generate;

end rtl;
