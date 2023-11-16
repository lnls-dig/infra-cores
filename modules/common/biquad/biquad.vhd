--------------------------------------------------------------------------------
-- Title        : Biquadratic (Biquad) Filter
-- Project      :
--------------------------------------------------------------------------------
-- File         : biquad.vhd
-- Author       : Guilherme Ricioli <guilherme.riciolic@gmail.com>
-- Company      : CNPEM, LNLS - GIE
-- Platform     : Generic
-- Standard     : VHDL'08
--------------------------------------------------------------------------------
-- Description  : Implementation of biquad filter using its canonical form.
--------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
--------------------------------------------------------------------------------
-- Revisions    :
-- Date         Version  Author              Description
-- 2023-09-15   1.0      guilherme.ricioli   Created
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.fixed_pkg.ALL;

LIBRARY work;
USE work.ifc_common_pkg.ALL;

ENTITY biquad IS
  GENERIC (
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

    -- Extra bits for internal arithmetic
    g_EXTRA_BITS        : NATURAL
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

    -- Coefficients
    -- b0, b1, b2, a1, a2 (a0 = 1)
    coeffs_i            : IN  t_biquad_coeffs(
                                b0(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                b1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                b2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                a1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                                a2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH)
                              );

    -- Output
    -- y[n] = b0*x[n] + b1*x[n - 1] + b2*x[n - 2] - a1*y[n - 1] - a2*y[n - 2]
    y_o                 : OUT SFIXED(g_Y_INT_WIDTH-1 DOWNTO -g_Y_FRAC_WIDTH);
    -- Output valid
    y_valid_o           : OUT STD_LOGIC
  );
END ENTITY biquad;

ARCHITECTURE behave OF biquad IS
  CONSTANT c_B0_TIMES_W_IDX : NATURAL := 0;
  CONSTANT c_A1_TIMES_W_D1_IDX : NATURAL := 1;
  CONSTANT c_A2_TIMES_W_D2_IDX : NATURAL := 2;
  CONSTANT c_B1_TIMES_W_D1_IDX : NATURAL := 3;
  CONSTANT c_B2_TIMES_W_D2_IDX : NATURAL := 4;
  CONSTANT c_AUX_A_IDX : NATURAL := 5;
  CONSTANT c_AUX_B_IDX : NATURAL := 6;

  TYPE t_terms IS ARRAY (NATURAL RANGE <>) OF
    SFIXED((g_COEFF_INT_WIDTH + g_X_INT_WIDTH + g_EXTRA_BITS)-1 DOWNTO
           -(g_COEFF_FRAC_WIDTH + g_X_FRAC_WIDTH + g_EXTRA_BITS));

  SIGNAL w, w_d1, w_d2 : SFIXED((g_COEFF_INT_WIDTH + g_X_INT_WIDTH +
                                 g_EXTRA_BITS)-1
                                DOWNTO
                                -(g_COEFF_FRAC_WIDTH + g_X_FRAC_WIDTH +
                                g_EXTRA_BITS))
                       := (OTHERS => '0');
  SIGNAL terms : t_terms(c_AUX_B_IDX DOWNTO c_B0_TIMES_W_IDX)
               := (OTHERS => (OTHERS => '0'));
  SIGNAL state : NATURAL RANGE 0 TO 3 := 0;
BEGIN
  PROCESS(clk_i) IS
  BEGIN
    IF rising_edge(clk_i) THEN
      IF rst_n_i = '0' THEN
        w <= (OTHERS => '0');
        w_d1 <= (OTHERS => '0');
        w_d2 <= (OTHERS => '0');
        terms <= (OTHERS => (OTHERS => '0'));
        state <= 0;
        y_valid_o <= '0';
      ELSE
        y_valid_o <= '0';

        CASE state IS
          -- Computes: w[n] = x[n] - a1*w[n - 1] - a2*w[n - 2]
          WHEN 0 =>
            IF x_valid_i THEN
              w <= resize(x_i + terms(c_AUX_A_IDX), w'LEFT, w'RIGHT);
              state <= 1;
            END IF;

          -- Computes: b0*w[n]
          --           w[n - 1] (for the next iteration)
          --           w[n - 2] (for the next iteration)
          WHEN 1 =>
            terms(c_B0_TIMES_W_IDX) <= resize(coeffs_i.b0*w,
                                              terms(c_B0_TIMES_W_IDX)'LEFT,
                                              terms(c_B0_TIMES_W_IDX)'RIGHT);
            w_d1 <= w;
            w_d2 <= w_d1;
            state <= 2;

          -- Computes: y[n] = w[n] + b1*w[n - 1] + b2*w[n - 2]
          --           a1*w[n - 1] (for the next iteration)
          --           a2*w[n - 2] (for the next iteration)
          --           b1*w[n - 1] (for the next iteration)
          --           b2*w[n - 2] (for the next iteration)
          WHEN 2 =>
            y_o <= resize(terms(c_B0_TIMES_W_IDX) + terms(c_AUX_B_IDX),
                          y_o'LEFT, y_o'RIGHT);
            y_valid_o <= '1';
            terms(c_A1_TIMES_W_D1_IDX) <= resize(coeffs_i.a1*w_d1,
                                                 terms(c_A1_TIMES_W_D1_IDX)'LEFT,
                                                 terms(c_A1_TIMES_W_D1_IDX)'RIGHT);
            terms(c_A2_TIMES_W_D2_IDX) <= resize(coeffs_i.a2*w_d2,
                                                 terms(c_A2_TIMES_W_D2_IDX)'LEFT,
                                                 terms(c_A2_TIMES_W_D2_IDX)'RIGHT);
            terms(c_B1_TIMES_W_D1_IDX) <= resize(coeffs_i.b1*w_d1,
                                                 terms(c_B1_TIMES_W_D1_IDX)'LEFT,
                                                 terms(c_B1_TIMES_W_D1_IDX)'RIGHT);
            terms(c_B2_TIMES_W_D2_IDX) <= resize(coeffs_i.b2*w_d2,
                                                 terms(c_B2_TIMES_W_D2_IDX)'LEFT,
                                                 terms(c_B2_TIMES_W_D2_IDX)'RIGHT);
            state <= 3;

          -- Computes: -a1*w[n - 1] - a2*w[n - 2] (for the next iteration)
          --            b1*w[n - 1] + b2*w[n - 2] (for the next iteration)
          WHEN 3 =>
            terms(c_AUX_A_IDX) <= resize(-terms(c_A1_TIMES_W_D1_IDX) -
                                          terms(c_A2_TIMES_W_D2_IDX),
                                         terms(c_AUX_A_IDX)'LEFT,
                                         terms(c_AUX_A_IDX)'RIGHT);
            terms(c_AUX_B_IDX) <= resize(terms(c_B1_TIMES_W_D1_IDX) +
                                         terms(c_B2_TIMES_W_D2_IDX),
                                         terms(c_AUX_B_IDX)'LEFT,
                                         terms(c_AUX_B_IDX)'RIGHT);
            state <= 0;
        END CASE;
      END IF;
    END IF;
  END PROCESS;
END ARCHITECTURE behave;
