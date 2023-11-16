-------------------------------------------------------------------------------
-- Title        : Biquadratic (Biquad) Filter Testbench
-- Project      :
-------------------------------------------------------------------------------
-- File         : biquad_tb.vhd
-- Author       : Guilherme Ricioli <guilherme.ricioli@gmail.com>
-- Company      : CNPEM, LNLS - GIE
-- Platform     : Simulation
-- Standard     : VHDL'08
-------------------------------------------------------------------------------
-- Description  : Tests the biquad filter against values computed using
--                floating point arithmetic. The error tolerance is 1%.
-------------------------------------------------------------------------------
-- Copyright (c) 2023
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions    :
-- Date         Version  Author             Description
-- 2023-09-15   1.0      guilherme.ricioli  Created
-------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.fixed_pkg.ALL;

LIBRARY std;
USE std.env.finish;
USE std.textio.ALL;

LIBRARY work;
USE work.ifc_common_pkg.ALL;

ENTITY biquad_tb IS
  GENERIC (
    -- File containing the biquad's coefficients
    g_TEST_COEFFS_FILENAME  : STRING := "../biquad_coeffs.dat";
    -- File containing the values for x and the expected values for y
    g_TEST_X_Y_FILENAME     : STRING := "../biquad_x_y.dat";

    -- Integer width of x
    g_X_INT_WIDTH           : NATURAL := 15;
    -- Fractionary width of x
    g_X_FRAC_WIDTH          : NATURAL := 10;

    -- Integer width of coefficients
    g_COEFF_INT_WIDTH       : NATURAL := 1;
    -- Fractionary width of coefficients
    g_COEFF_FRAC_WIDTH      : NATURAL := 31;

    -- Integer width of y
    g_Y_INT_WIDTH           : NATURAL := 15;
    -- Fractionary width of y
    g_Y_FRAC_WIDTH          : NATURAL := 10;

    -- Extra bits for biquad's internal arithmetic
    g_EXTRA_BITS            : NATURAL := 1
  );
END ENTITY biquad_tb;

ARCHITECTURE test OF biquad_tb IS
  PROCEDURE f_gen_clk(CONSTANT freq : IN    NATURAL;
                      SIGNAL   clk  : INOUT STD_LOGIC) IS
  BEGIN
    LOOP
      WAIT FOR (0.5 / REAL(freq)) * 1 sec;
      clk <= NOT clk;
    END LOOP;
  END PROCEDURE f_gen_clk;

  PROCEDURE f_wait_cycles(SIGNAL   clk    : IN STD_LOGIC;
                          CONSTANT cycles : NATURAL) IS
  BEGIN
    FOR i IN 1 TO cycles LOOP
      WAIT UNTIL rising_edge(clk);
    END LOOP;
  END PROCEDURE f_wait_cycles;

  PROCEDURE f_wait_clocked_signal(SIGNAL clk : IN STD_LOGIC;
                                  SIGNAL sig : IN STD_LOGIC;
                                  val        : IN STD_LOGIC;
                                  timeout    : IN NATURAL := 2147483647) IS
  VARIABLE cnt : NATURAL := timeout;
  BEGIN
    WHILE sig /= val AND cnt > 0 LOOP
      WAIT UNTIL rising_edge(clk);
      cnt := cnt - 1;
    END LOOP;
  END PROCEDURE f_wait_clocked_signal;

  CONSTANT c_SYS_CLOCK_FREQ : NATURAL := 100_000_000;

  SIGNAL clk : STD_LOGIC := '0';
  SIGNAL rst_n : STD_LOGIC := '1';
  SIGNAL x : SFIXED(g_X_INT_WIDTH-1 DOWNTO -g_X_FRAC_WIDTH);
  SIGNAL x_valid : STD_LOGIC := '0';
  SIGNAL coeffs : t_biquad_coeffs(
                    b0(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                    b1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                    b2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                    a1(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH),
                    a2(g_COEFF_INT_WIDTH-1 DOWNTO -g_COEFF_FRAC_WIDTH)
                  );
  SIGNAL busy : STD_LOGIC := '0';
  SIGNAL y : SFIXED(g_Y_INT_WIDTH-1 DOWNTO -g_Y_FRAC_WIDTH);
  SIGNAL y_valid : STD_LOGIC := '0';
BEGIN
  f_gen_clk(c_SYS_CLOCK_FREQ, clk);

  PROCESS
    FILE fin : TEXT;
    VARIABLE lin : LINE;
    VARIABLE aux : REAL;
  BEGIN
    rst_n <= '0';
    f_wait_cycles(clk, 1);
    rst_n <= '1';

    f_wait_cycles(clk, 1);
    file_open(fin, g_TEST_COEFFS_FILENAME, read_mode);
    readline(fin, lin);
    read(lin, aux); coeffs.b0 <= to_sfixed(aux, coeffs.b0'LEFT, coeffs.b0'RIGHT);
    read(lin, aux); coeffs.b1 <= to_sfixed(aux, coeffs.b1'LEFT, coeffs.b1'RIGHT);
    read(lin, aux); coeffs.b2 <= to_sfixed(aux, coeffs.b2'LEFT, coeffs.b2'RIGHT);
    read(lin, aux); coeffs.a1 <= to_sfixed(aux, coeffs.a1'LEFT, coeffs.a1'RIGHT);
    read(lin, aux); coeffs.a2 <= to_sfixed(aux, coeffs.a2'LEFT, coeffs.a2'RIGHT);
    file_close(fin);

    file_open(fin, g_TEST_X_Y_FILENAME, read_mode);
    WHILE NOT endfile(fin)
    LOOP
      readline(fin, lin);

      read(lin, aux);
      x <= to_sfixed(aux, x'LEFT, x'RIGHT);
      f_wait_clocked_signal(clk, busy, '0');
      x_valid <= '1';
      f_wait_cycles(clk, 1);
      x_valid <= '0';
      f_wait_clocked_signal(clk, y_valid, '1');
      read(lin, aux);
      IF ABS(to_real(y)/aux - 1.0) > 0.01 THEN
        REPORT "Too large error (> 1%): got " & REAL'image(to_real(y)) &
               " (expected: " & REAL'image(aux) & ")"
        SEVERITY ERROR;
      END IF;
    END LOOP;
    file_close(fin);

    finish;
  END PROCESS;

  UUT : biquad
    GENERIC MAP (
      g_X_INT_WIDTH       => g_X_INT_WIDTH,
      g_X_FRAC_WIDTH      => g_X_FRAC_WIDTH,
      g_COEFF_INT_WIDTH   => g_COEFF_INT_WIDTH,
      g_COEFF_FRAC_WIDTH  => g_COEFF_FRAC_WIDTH,
      g_Y_INT_WIDTH       => g_Y_INT_WIDTH,
      g_Y_FRAC_WIDTH      => g_Y_FRAC_WIDTH,
      g_EXTRA_BITS        => g_EXTRA_BITS
    )
    PORT MAP (
      clk_i               => clk,
      rst_n_i             => rst_n,
      x_i                 => x,
      x_valid_i           => x_valid,
      coeffs_i            => coeffs,
      busy_o              => busy,
      y_o                 => y,
      y_valid_o           => y_valid
    );
END ARCHITECTURE test;
