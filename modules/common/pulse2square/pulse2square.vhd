library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse2square is
port
(
  clk_i                                    : in std_logic;
  rst_n_i                                  : in std_logic;

  -- Pulse input
  pulse_i                                  : in std_logic;
  -- Clear square
  clr_i                                    : in std_logic;
  -- square output
  square_o                                 : out std_logic
);
end pulse2square;

architecture rtl of pulse2square is
  signal square                            : std_logic := '0';
begin

  -- Convert from pulse to square signal
  p_pulse_to_square : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        square <= '0';
      else
        if clr_i = '1'then
          square <= '0';
        elsif pulse_i = '1' then
          square <= not square;
        end if;
      end if;
    end if;
  end process;

  square_o <= square;

end rtl;
