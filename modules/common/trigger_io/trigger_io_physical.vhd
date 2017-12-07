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
  g_iobuf_instantiation_type               : string := "native";
  -- Wired-OR implementation if g_with_wired_or_driver = true.
  -- Possible values are: true or false
  g_with_wired_or_driver                   : boolean := true;
  -- Single-ended trigger input/out, if g_with_single_ended_driver = true
  -- Possible values are: true or false
  g_with_single_ended_driver               : boolean := false
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
  -- If using g_with_bidirectional_trigger = true and g_with_single_ended_driver = false
  trig_n_b                                 : inout std_logic := '0';
  -- If using g_with_bidirectional_trigger = false
  trig_i                                   : in std_logic := '0';
  trig_o                                   : out std_logic;
  -- If using g_with_bidirectional_trigger = false and g_with_single_ended_driver = true
  trig_n_o                                 : out std_logic;

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

  -- Test sanity of wired-OR and bidirectional generics
  assert ((g_with_wired_or_driver = true and g_with_bidirectional_trigger = true) or
          (g_with_wired_or_driver = false))
  report "[trigger_io_physical] Unsupported combination. g_with_wired_or_driver = true, but gen_with_bidir_trigger is not."
  severity failure;

  -- Test sanity of g_with_inferred_iobuf and g_with_single_ended_driver generics
  assert ((g_with_single_ended_driver = false and g_iobuf_instantiation_type = "native") or
          (g_with_single_ended_driver = true))
          report "[trigger_io_physical] Only native implementation (g_iobuf_instantiation_type = native) " &
                "is supported if g_with_single_ended_driver = false"
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

  gen_tx_with_wired_or_driver : if g_with_wired_or_driver generate
    trig_tx_int <= not (trig_tx_fpga);
  end generate;

  gen_tx_without_wired_or_driver : if not(g_with_wired_or_driver) generate
    trig_tx_int <= trig_tx_fpga;
  end generate;

  -- Regular data/direction driving with polarity inversion
  trig_dir_polarized  <= trig_dir_int when trig_ext_dir_pol_int = '0' else
                             not (trig_dir_int);

  -- If we are implementing the wired-OR scheme, data/dir pins must
  -- be controlled by the same polarity pin, as the output direction pin
  -- will be used as data.
  -- If we are NOT in wired-OR, we can use the data/dir pins as usual,
  -- each one with its independent controller
  gen_tx_pol_with_wired_or_driver : if g_with_wired_or_driver generate
    trig_tx_polarized <= trig_tx_int when trig_ext_dir_pol_int = '0' else
                                not (trig_tx_int);
  end generate;

  gen_tx_pol_without_wired_or_driver : if not(g_with_wired_or_driver) generate
    trig_tx_polarized <= trig_tx_int when trig_pol_int = '0' else
                                not (trig_tx_int);
  end generate;

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

      gen_with_single_ended : if g_with_single_ended_driver generate
        cmp_iobuf_generic : iobuf_generic
        port map (
          buffer_o                                      => trig_rx,
          buffer_b                                      => trig_b,
          buffer_i                                      => trig_tx,
          buffer_t                                      => trig_dir
        );
      end generate;

      gen_without_single_ended : if not(g_with_single_ended_driver) generate
        cmp_iobufds_generic : iobufds_generic
        port map (
          buffer_o                                      => trig_rx,
          buffer_b                                      => trig_b,
          buffer_n_b                                    => trig_n_b,
          buffer_i                                      => trig_tx,
          buffer_t                                      => trig_dir
        );
      end generate;

    end generate;

    gen_with_inferred_iobuf : if g_iobuf_instantiation_type = "inferred" generate

      gen_with_single_ended : if g_with_single_ended_driver generate
        trig_b <= trig_tx when trig_dir = '0' else 'Z';
        trig_rx <= trig_b;
      end generate;

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

    -- Single-Ended/Differential Buffer for unidirectional drivers
    gen_with_single_ended : if g_with_single_ended_driver generate
      trig_n_o            <= 'X';
    end generate;

    gen_without_single_ended : if not(g_with_single_ended_driver) generate
      trig_n_o            <= not trig_tx_polarized;
    end generate;

    -- Trigger direction external output
    trig_dir_o        <= trig_dir_polarized;

  end generate;

end rtl;
