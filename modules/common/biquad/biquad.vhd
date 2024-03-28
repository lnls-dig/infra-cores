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

    -- Busy flag
    busy_o              : OUT STD_LOGIC;

    -- Output
    -- y[n] = b0*x[n] + b1*x[n - 1] + b2*x[n - 2] - a1*y[n - 1] - a2*y[n - 2]
    y_o                 : OUT SFIXED(g_Y_INT_WIDTH-1 DOWNTO -g_Y_FRAC_WIDTH);
    -- Output valid
    y_valid_o           : OUT STD_LOGIC
  );
END ENTITY biquad;

ARCHITECTURE behave OF biquad IS
  SIGNAL w, w_d1, w_d2, b0_times_w, a1_times_w_d1, a2_times_w_d2, b1_times_w_d1,
         b2_times_w_d2, aux_a, aux_b :
           SFIXED((g_COEFF_INT_WIDTH + g_X_INT_WIDTH + g_EXTRA_BITS)-1 DOWNTO
                  -(g_COEFF_FRAC_WIDTH + g_X_FRAC_WIDTH + g_EXTRA_BITS)) :=
             (OTHERS => '0');

  -- Signals to hold full precision operations' results
  SIGNAL b0_times_w_tmp, a1_times_w_d1_tmp, a2_times_w_d2_tmp,
         b1_times_w_d1_tmp, b2_times_w_d2_tmp :
           SFIXED((g_COEFF_INT_WIDTH + w'LEFT + 1)-1 DOWNTO
                  -g_COEFF_FRAC_WIDTH + w'RIGHT) := (OTHERS => '0');
  SIGNAL w_tmp :
           SFIXED(MAXIMUM(g_X_INT_WIDTH-1, aux_a'LEFT)+1 DOWNTO
                  MINIMUM(-g_X_FRAC_WIDTH, aux_a'RIGHT)) := (OTHERS => '0');
  SIGNAL aux_a_tmp :
           SFIXED(MAXIMUM(a1_times_w_d1'LEFT+1, a2_times_w_d2'LEFT)+1 DOWNTO
                  MINIMUM(a1_times_w_d1'RIGHT, a2_times_w_d2'RIGHT)) :=
             (OTHERS => '0');
  SIGNAL aux_b_tmp :
           SFIXED(MAXIMUM(b1_times_w_d1'LEFT, b2_times_w_d2'LEFT)+1 DOWNTO
                  MINIMUM(b1_times_w_d1'RIGHT, b2_times_w_d2'RIGHT)) :=
             (OTHERS => '0');
  SIGNAL y_tmp :
           SFIXED(MAXIMUM(b0_times_w'LEFT, aux_b'LEFT)+1 DOWNTO
                  MINIMUM(b0_times_w'RIGHT, aux_b'RIGHT)) := (OTHERS => '0');

  SIGNAL state : NATURAL RANGE 0 TO 6 := 0;
BEGIN
  PROCESS(clk_i) IS
  BEGIN
    IF rising_edge(clk_i) THEN
      IF rst_n_i = '0' THEN
        w <= (OTHERS => '0');
        w_d1 <= (OTHERS => '0');
        w_d2 <= (OTHERS => '0');
        b0_times_w <= (OTHERS => '0');
        a1_times_w_d1 <= (OTHERS => '0');
        a2_times_w_d2 <= (OTHERS => '0');
        b1_times_w_d1 <= (OTHERS => '0');
        b2_times_w_d2 <= (OTHERS => '0');
        aux_a <= (OTHERS => '0');
        aux_b <= (OTHERS => '0');
        w_tmp <= (OTHERS => '0');
        b0_times_w_tmp <= (OTHERS => '0');
        a1_times_w_d1_tmp <= (OTHERS => '0');
        a2_times_w_d2_tmp <= (OTHERS => '0');
        b1_times_w_d1_tmp <= (OTHERS => '0');
        b2_times_w_d2_tmp <= (OTHERS => '0');
        aux_a_tmp <= (OTHERS => '0');
        aux_b_tmp <= (OTHERS => '0');
        state <= 0;
        y_valid_o <= '0';
      ELSE
        y_valid_o <= '0';

        CASE state IS
          -- Computes: w[n] = x[n] - a1*w[n - 1] - a2*w[n - 2] (full precision)
          WHEN 0 =>
            IF x_valid_i THEN
              w_tmp <= x_i + aux_a;
              state <= 1;
            END IF;

          -- Computes: w[n] (resized)
          WHEN 1 =>
            w <= resize(w_tmp, w'LEFT, w'RIGHT);
            state <= 2;

          -- Computes: b0*w[n] (full precision)
          --           w[n - 1] for the next iteration
          --           w[n - 2] for the next iteration
          WHEN 2 =>
            b0_times_w_tmp <= coeffs_i.b0*w;
            w_d1 <= w;
            w_d2 <= w_d1;
            state <= 3;

          -- Computes: b0*w[n] (resized)
          --           a1*w[n - 1] for the next iteration (full precision)
          --           a2*w[n - 2] for the next iteration (full precision)
          --           b1*w[n - 1] for the next iteration (full precision)
          --           b2*w[n - 2] for the next iteration (full precision)
          WHEN 3 =>
            b0_times_w <= resize(b0_times_w_tmp, b0_times_w'LEFT,
                                 b0_times_w'RIGHT);
            a1_times_w_d1_tmp <= coeffs_i.a1*w_d1;
            a2_times_w_d2_tmp <= coeffs_i.a2*w_d2;
            b1_times_w_d1_tmp <= coeffs_i.b1*w_d1;
            b2_times_w_d2_tmp <= coeffs_i.b2*w_d2;
            state <= 4;

          -- Computes:  a1*w[n - 1] for the next iteration (resized)
          --            a2*w[n - 2] for the next iteration (resized)
          --            b1*w[n - 1] for the next iteration (resized)
          --            b2*w[n - 2] for the next iteration (resized)
          --            y[n] = w[n] + b1*w[n - 1] + b2*w[n - 2] (full precision)
          WHEN 4 =>
            a1_times_w_d1 <= resize(a1_times_w_d1_tmp, a1_times_w_d1'LEFT,
                                    a1_times_w_d1'RIGHT);
            a2_times_w_d2 <= resize(a2_times_w_d2_tmp, a2_times_w_d2'LEFT,
                                    a2_times_w_d2'RIGHT);
            b1_times_w_d1 <= resize(b1_times_w_d1_tmp, b1_times_w_d1'LEFT,
                                    b1_times_w_d1'RIGHT);
            b2_times_w_d2 <= resize(b2_times_w_d2_tmp, b2_times_w_d2'LEFT,
                                    b2_times_w_d2'RIGHT);
            y_tmp <= b0_times_w + aux_b;
            state <= 5;

          -- Computes: -a1*w[n - 1] - a2*w[n - 2] for the next iteration (full precision)
          --            b1*w[n - 1] + b2*w[n - 2] for the next iteration (full precision)
          --            y[n] (resized)
          WHEN 5 =>
            aux_a_tmp <= -a1_times_w_d1 - a2_times_w_d2;
            aux_b_tmp <= b1_times_w_d1 + b2_times_w_d2;
            y_o <= resize(y_tmp, y_o'LEFT, y_o'RIGHT);
            y_valid_o <= '1';
            state <= 6;

          -- Computes: -a1*w[n - 1] - a2*w[n - 2] for the next iteration (resized)
          --            b1*w[n - 1] + b2*w[n - 2] for the next iteration (resized)
          WHEN 6 =>
            aux_a <= resize(aux_a_tmp, aux_a'LEFT, aux_a'RIGHT);
            aux_b <= resize(aux_b_tmp, aux_b'LEFT, aux_b'RIGHT);
            state <= 0;
        END CASE;
      END IF;
    END IF;
  END PROCESS;

  busy_o <= '1' WHEN (state = 0 AND x_valid_i = '1') ELSE
            '1' WHEN state = 1 ELSE
            '1' WHEN state = 2 ELSE
            '1' WHEN state = 3 ELSE
            '1' WHEN state = 4 ELSE
            '1' WHEN state = 5 ELSE
            '0';
END ARCHITECTURE behave;
