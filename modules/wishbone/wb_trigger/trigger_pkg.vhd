library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;
use work.trigger_common_pkg.all;

package trigger_pkg is

  -- Components
  component trigger_resolver
  generic (
    g_trig_num             : natural := 8;
    g_num_mux_interfaces   : natural := 2;
    g_out_resolver         : string := "fanout";
    g_in_resolver          : string := "or";
    g_with_input_sync      : boolean := true;
    g_with_output_sync     : boolean := true
  );
  port (
    -- Reference clock for physical component (e.g., backplane, board)
    ref_clk_i   : in std_logic;
    ref_rst_n_i : in std_logic;

    -- Synchronization clocks for different domains
    fs_clk_array_i    : in std_logic_vector(g_num_mux_interfaces-1 downto 0);
    fs_rst_n_array_i  : in std_logic_vector(g_num_mux_interfaces-1 downto 0);

    -------------------------------
    --- Trigger ports
    -------------------------------

    trig_resolved_out_o : out t_trig_channel_array(g_trig_num-1 downto 0);
    trig_resolved_in_i  : in  t_trig_channel_array(g_trig_num-1 downto 0);

    trig_mux_out_o : out t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_trig_num-1 downto 0);
    trig_mux_in_i  : in  t_trig_channel_array2d(g_num_mux_interfaces-1 downto 0, g_trig_num-1 downto 0)
  );
  end component;

end trigger_pkg;

