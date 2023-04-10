-------------------------------------------------------------------------------
-- Title      : Wishbone TCP Server
-------------------------------------------------------------------------------
-- Author     : Augusto Fraga Giachero
-- Company    : CNPEM LNLS-GIE
-- Platform   : Simulation / GHDL
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: Interface between the fofb_server library using VHPIDIRECT
-------------------------------------------------------------------------------
-- Copyright (c) 2023 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2023-05-04  1.0      augusto.fraga         Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package wishbone_tcp_server_pkg is
  -- VHDL doesn't have pointers like other languages, so when interfacing with
  -- Rust code we need a type that can hold an opaque pointer that refers to
  -- the object instance. Turns out that an 'access' type is effectively a
  -- pointer from the GHDL perspective, so we can use it to hold the wishbone
  -- tcp server struct reference. The only caveats are that we can only pass
  -- it as an argument to procedures and it seems that GHDL will automatically
  -- free the memory pointed by the 'access' type.
  type t_wishbone_tcp_server is access integer;
  type t_wishbone_tcp_server_msg_type is (READ_DATA, WRITE_DATA, WAIT_EVENT, DEBUG, DISCONNECTED, PARSING_ERR, EXIT_SIMU);

  -- Create a new wishbone tcp server instance.
  impure function new_wishbone_tcp_server (hostname : string)
                                           return t_wishbone_tcp_server;
  attribute foreign of new_wishbone_tcp_server : function is "VHPIDIRECT new_wishbone_tcp_server";

  -- Wait for a new client connection.
  procedure wishbone_tcp_server_wait_con(variable obj : in  t_wishbone_tcp_server);
  attribute foreign of wishbone_tcp_server_wait_con: procedure is "VHPIDIRECT wishbone_tcp_server_wait_con";

  -- Wait for new data from the client, should only be called when there is an
  -- active connection with the client. The message type will be written to
  -- msg_type, so the message data can be retrieved by the corresponding read
  -- procedures
  procedure wishbone_tcp_server_wait_data(variable obj      : in  t_wishbone_tcp_server;
                                          variable msg_type : out t_wishbone_tcp_server_msg_type);
  attribute foreign of wishbone_tcp_server_wait_data: procedure is "VHPIDIRECT wishbone_tcp_server_wait_data";

  -- Get the address and data. If the previous request was for reading
  -- data, you should ignore the 'data' variable output. It is non-blocking,
  -- always return a copy of the last received data.
  procedure wishbone_tcp_server_get_addr_data(variable obj  : in  t_wishbone_tcp_server;
                                              variable addr : out std_logic_vector(31 downto 0);
                                              variable data : out std_logic_vector(31 downto 0));
  attribute foreign of wishbone_tcp_server_get_addr_data : procedure is "VHPIDIRECT wishbone_tcp_server_get_addr_data";

  -- Send the read data from the wishbone bus to the client
  procedure wishbone_tcp_server_write_data(variable obj  : in t_wishbone_tcp_server;
                                                    data : in std_logic_vector(31 downto 0));
  attribute foreign of wishbone_tcp_server_write_data: procedure is "VHPIDIRECT wishbone_tcp_server_write_data";

  -- Send the an event string to the client
  procedure wishbone_tcp_server_write_event(variable obj   : in t_wishbone_tcp_server;
                                                     event : in string);
  attribute foreign of wishbone_tcp_server_write_event: procedure is "VHPIDIRECT wishbone_tcp_server_write_event";

end package wishbone_tcp_server_pkg;

package body wishbone_tcp_server_pkg is
  impure function new_wishbone_tcp_server (hostname : string)
                                           return t_wishbone_tcp_server is
  begin report "VHPIDIRECT new_wishbone_tcp_server" severity failure; end;

  procedure wishbone_tcp_server_wait_con(variable obj : in  t_wishbone_tcp_server
                                 ) is
  begin report "VHPIDIRECT wishbone_tcp_server_wait_con" severity failure; end;

  procedure wishbone_tcp_server_wait_data(variable obj      : in  t_wishbone_tcp_server;
                                          variable msg_type : out t_wishbone_tcp_server_msg_type
                                          ) is
  begin report "VHPIDIRECT wishbone_tcp_server_wait_data" severity failure; end;

  procedure wishbone_tcp_server_get_addr_data(variable obj  : in  t_wishbone_tcp_server;
                                              variable addr : out std_logic_vector(31 downto 0);
                                              variable data : out std_logic_vector(31 downto 0)) is
  begin report "VHPIDIRECT wishbone_tcp_server_get_addr_data" severity failure; end;

  procedure wishbone_tcp_server_write_data(variable obj  : in t_wishbone_tcp_server;
                                                    data : in std_logic_vector(31 downto 0)) is
  begin report "VHPIDIRECT wishbone_tcp_server_write_data" severity failure; end;

  procedure wishbone_tcp_server_write_event(variable obj   : in t_wishbone_tcp_server;
                                                     event : in string) is
  begin report "VHPIDIRECT wishbone_tcp_server_write_event" severity failure; end;
end package body wishbone_tcp_server_pkg;
