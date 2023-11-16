--------------------------------------------------------------------------------
-- Title        : Infinite Impulse Response (IIR) Filter
-- Project      :
--------------------------------------------------------------------------------
-- File         : iir_filt.vhd
-- Author       : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company      : CNPEM, LNLS - GIE
-- Platform     : Generic
-- Standard     : VHDL'08
--------------------------------------------------------------------------------
-- Description  : Cascades biquad filters for achieving higher-order IIR filter.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions    :
-- Date         Version  Author              Description
-- 2023-09-18   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.fixed_pkg.ALL;

LIBRARY work;
USE work.ifc_common_pkg.ALL;

ENTITY iir_filt IS
  GENERIC (
    -- Maximum filter order
    g_MAX_FILT_ORDER    : NATURAL;

    -- Integer width of x
    g_X_INT_WIDTH       : NATURAL;
    -- Fractionary width of x
    g_X_FRAC_WIDTH      : NATURAL;

    -- Integer width of coefficients
    g_COEFF_INT_WIDTH   : NATURAL;
    -- Fractionary width of coefficients
    g_COEFF_FRAC_WIDTH  : NATURAL;

    -- Integer width of y
    g_Y_INT_WIDTH       : NATURAL;
    -- Fractionary width of y
    g_Y_FRAC_WIDTH      : NATURAL;

    -- Extra bits for biquads' internal arithmetic
    g_ARITH_EXTRA_BITS  : NATURAL;
    -- Extra bits for between-biquads cascade interfaces
    g_IFCS_EXTRA_BITS   : NATURAL
  );
  PORT (
    -- Clock
    clk_i               : IN  STD_LOGIC;
    -- Reset
    rst_n_i             : IN  STD_LOGIC;

    -- Input
    -- x[n]
    x_i                 : IN  SFIXED(g_X_INT_WIDTH-1 DOWNTO -g_X_FRAC_WIDTH);
    -- Input valid
    x_valid_i           : IN  STD_LOGIC;

    -- Coefficients for all ceil(g_MAX_FILT_ORDER/2) internal biquads
    -- b0, b1, b2, a1, a2 (a0 = 1)
    coeffs_i            : IN  t_iir_filt_coeffs(
                                ((g_MAX_FILT_ORDER + 1)/2)-1 DOWNTO 0)(
                                b0(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                b1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                b2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                a1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                a2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH)
                              );

    -- Busy flag
    busy_o              : OUT STD_LOGIC;

    -- Output
    -- y[n]
    y_o                 : OUT SFIXED(g_Y_INT_WIDTH-1 DOWNTO -g_Y_FRAC_WIDTH);
    -- Output valid
    y_valid_o           : OUT STD_LOGIC
  );
END ENTITY iir_filt;

ARCHITECTURE behave OF iir_filt IS
  CONSTANT c_NUM_OF_BIQUADS : NATURAL := (g_MAX_FILT_ORDER + 1)/2;

  TYPE t_cascade_ifc IS RECORD
    x       : SFIXED(g_X_INT_WIDTH-1 DOWNTO
                -(g_X_FRAC_WIDTH + g_IFCS_EXTRA_BITS));
    x_valid : STD_LOGIC;
    y       : SFIXED(g_Y_INT_WIDTH-1 DOWNTO
                -(g_Y_FRAC_WIDTH + g_IFCS_EXTRA_BITS));
    y_valid : STD_LOGIC;
  END RECORD;
  TYPE t_cascade_ifcs IS ARRAY (NATURAL RANGE <>) OF t_cascade_ifc;

  SIGNAL cascade_ifcs : t_cascade_ifcs(c_NUM_OF_BIQUADS-1 DOWNTO 0);
  SIGNAL busy : STD_LOGIC_VECTOR(c_NUM_OF_BIQUADS-1 DOWNTO 0);
BEGIN
  gen_biquads : FOR idx IN 0 TO c_NUM_OF_BIQUADS-1
    GENERATE
      cmp_biquad : biquad
        GENERIC MAP (
          g_X_INT_WIDTH       => g_X_INT_WIDTH,
          g_X_FRAC_WIDTH      => g_X_FRAC_WIDTH + g_IFCS_EXTRA_BITS,
          g_COEFF_INT_WIDTH   => g_COEFF_INT_WIDTH,
          g_COEFF_FRAC_WIDTH  => g_COEFF_FRAC_WIDTH,
          g_Y_INT_WIDTH       => g_Y_INT_WIDTH,
          g_Y_FRAC_WIDTH      => g_Y_FRAC_WIDTH + g_IFCS_EXTRA_BITS,
          g_EXTRA_BITS        => g_ARITH_EXTRA_BITS
        )
        PORT MAP (
          clk_i               => clk_i,
          rst_n_i             => rst_n_i,
          x_i                 => cascade_ifcs(idx).x,
          x_valid_i           => cascade_ifcs(idx).x_valid,
          coeffs_i            => coeffs_i(idx),
          busy_o              => busy(idx),
          y_o                 => cascade_ifcs(idx).y,
          y_valid_o           => cascade_ifcs(idx).y_valid
        );
    END GENERATE gen_biquads;

  cascade_ifcs(0).x <= resize(x_i, cascade_ifcs(0).x'LEFT, cascade_ifcs(0).x'RIGHT);
  cascade_ifcs(0).x_valid <= x_valid_i;

  gen_cascade_conn : FOR idx IN 0 TO c_NUM_OF_BIQUADS-2
    GENERATE
      cascade_ifcs(idx + 1).x <= cascade_ifcs(idx).y;
      cascade_ifcs(idx + 1).x_valid <= cascade_ifcs(idx).y_valid;
    END GENERATE gen_cascade_conn;

  y_o <= resize(cascade_ifcs(c_NUM_OF_BIQUADS-1).y, y_o'LEFT, y_o'RIGHT);
  y_valid_o <= cascade_ifcs(c_NUM_OF_BIQUADS-1).y_valid;

  -- Since all biquads have the same FSM length, it's enough to consider only
  -- the first cascaded biquad's busy flag.
  busy_o <= busy(0);
END ARCHITECTURE behave;
