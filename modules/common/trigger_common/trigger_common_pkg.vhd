library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package trigger_common_pkg is

  -- Constants

  -- Types
  subtype t_trig_pulse is std_logic;

  type t_trig_pulse_array is array (natural range <>) of t_trig_pulse;
  type t_trig_pulse_array2d is array (natural range <>, natural range <>) of t_trig_pulse;

  type t_trig_channel is record
    pulse : t_trig_pulse;
  end record;

  type t_trig_channel_array is array (natural range <>) of t_trig_channel;
  type t_trig_channel_array2d is array (natural range <>, natural range <>) of t_trig_channel;

  constant c_trig_channel_dummy : t_trig_channel := (pulse => '0');

end package trigger_common_pkg;
