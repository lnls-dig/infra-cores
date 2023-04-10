//! # Wishbone TCP server
//! Provides an interface for VHDL code to comunicate via TCP sockets.
//!
//! ## Building instructions
//!
//! ```bash
//! $ ghdl -a --std=08 <path_to_wishbone_tcp_server>/wishbone_tcp_server_pkg.vhd
//! $ ghdl -a --std=08 testbench.vhd
//! $ cargo build --release --manifest-path <path_to_wishbone_tcp_server>/tcp_server/Cargo.toml
//! $ ghdl -e --std=08 -Wl,<path_to_wishbone_tcp_server>/tcp_server/target/release/libtcp_server.a -Wl,-lpthread testbench
//! ```
//!
//! ## Usage example
//!
//! ```vhdl
//! library ieee;
//! use ieee.std_logic_1164.all;
//! use ieee.numeric_std.all;
//!
//! library work;
//! use work.wishbone_tcp_server_pkg.all;
//!
//! entity testbench is
//! end entity testbench;
//!
//! architecture simu of testbench is
//! begin
//!
//!   process
//!     variable wishbone_tcp_server: t_wishbone_tcp_server;
//!     variable msg_type   : t_wishbone_tcp_server_msg_type;
//!     variable data       : std_logic_vector(31 downto 0);
//!     variable addr       : std_logic_vector(31 downto 0);
//!   begin
//!     wishbone_tcp_server := new_wishbone_tcp_server("127.0.0.1:10022");
//!     loop
//!       wishbone_tcp_server_wait_con(wishbone_tcp_server);
//!       loop
//!         wishbone_tcp_server_wait_data(wishbone_tcp_server, msg_type);
//!         case msg_type is
//!           when READ_DATA =>
//!             wishbone_tcp_server_get_addr_data(wishbone_tcp_server, addr, data);
//!             report "Data read from address 0x" & to_hex_string(addr);
//!             wishbone_tcp_server_write_data(wishbone_tcp_server, x"DEADBEEF");
//!
//!           when WRITE_DATA =>
//!             wishbone_tcp_server_get_addr_data(wishbone_tcp_server, addr, data);
//!             report "Write data 0x" & to_hex_string(data) & " to address 0x" & to_hex_string(addr);
//!
//!           when WAIT_EVENT =>
//!             wishbone_tcp_server_write_event(wishbone_tcp_server, "evt1");
//!             report "Wait event";
//!
//!           when DEBUG =>
//!             report "Debug event";
//!
//!           when DISCONNECTED =>
//!             report "Client disconnected";
//!
//!           when PARSING_ERR =>
//!             report "Parsing error";
//!
//!           when EXIT_SIMU =>
//!             report "Exit simulation";
//!             std.env.finish;
//!         end case;
//!       end loop;
//!     end loop;
//!
//!     std.env.finish;
//!   end process;
//! end architecture simu;
//! ```
//!
//! ## TCP text protocol
//!
//! The `tcp_server` library implements a simple synchronous text
//! protocol, one command per line. Some commands return values, some
//! don't. All numbers should be represented by a hexadecimal string
//! without the leading '0x', all responses will be followed by a '\n'
//! character.
//!
//! The following commands are implemented:
//! * `write <addr> <data>` Write a 32 bits word `data` to the address `addr`. This command doesn't return anything;
//! * `read <addr>` Read a 32 bits word from address `addr`, returns the data read;
//! * `wait_event` Wait for an event / interrupt (defined by the VHDL side), returns a string identifying the event;
//! * `debug` Prints internal debug information to the simulation process stdout. This command doesn't return anything;
//! * `disconnect` Closes the current tcp socket. This command doesn't return anything;
//! * `exit` Terminate the simulation process. This command doesn't return anything.

// Copyright (c) 2023 CNPEM
// Licensed under GNU Lesser General Public License (LGPL) v3.0
// Author: Augusto Fraga Giachero

use std::net::{TcpListener, TcpStream, ToSocketAddrs, Shutdown};
use std::io::prelude::*;
use std::io::BufReader;
use std::slice;
use std::str;

/// GHDL IEEE std_logic states representation.
/// [Reference](https://github.com/ghdl/ghdl-cosim/blob/623f17f59aa2d33fb453fbbe9680ac00f88511f8/vhpidirect/vhpi_user.h#L844-L853).
#[allow(dead_code)]
enum IEEEStdLogic {
    Unitialized = 0,
    Unknown = 1,
    Low = 2,
    High = 3,
    HighImpedance = 4,
    WeakUnknown = 5,
    WeakLow = 6,
    WeakHigh = 7,
    DontCare = 8,
}

/// Range/bounds of a dimension of an unconstrained array with dimensions of type 'natural'.
/// [Reference](https://github.com/ghdl/ghdl-cosim/blob/623f17f59aa2d33fb453fbbe9680ac00f88511f8/vhpidirect/vffi_user.h#L76-L82).
#[repr(C)]
pub struct GHDLRange{
  left: i32,
  right: i32,
  dir: i32,
  len: i32,
}

/// Unconstrained array with dimensions of type 'natural'.
/// [Reference](https://github.com/ghdl/ghdl-cosim/blob/623f17f59aa2d33fb453fbbe9680ac00f88511f8/vhpidirect/vffi_user.h#L84-L88).
#[repr(C)]
pub struct GHDLNaturalDimArr <'a> {
  array: &'a u8,
  bounds: &'a GHDLRange,
}

/// Indicate the message type
#[repr(C)]
pub enum WBMsgType {
    /// Write word from wishbone bus
    ReadData,
    /// Write word to wishbone bus
    WriteData,
    /// Wait for some event/interrupt
    WaitEvent,
    /// Debug event
    Debug,
    /// Client disconnected
    Disconnected,
    /// Parsing error
    ParsingErr,
    /// Exit command received
    Exit,
}

/// FOFB Server struct
pub struct WBServer {
    listener: TcpListener,
    stream: Option<TcpStream>,
    reader: Option<BufReader<TcpStream>>,
    addr: u32,
    data: u32,
}

impl<'a> GHDLNaturalDimArr<'a> {
    /// Get a Result<> with an `str` reference or an error
    fn get_str(&self) -> Result<&str, str::Utf8Error> {
        unsafe {
            // First, we build a &[u8]...
            let slice = slice::from_raw_parts(self.array, self.bounds.len as usize);

            // ... and then convert that slice into a string slice
            str::from_utf8(slice)
        }
    }
}

/// Returns a pointer to a new `WBServer` instance
///
/// # Arguments
/// * `hostname` - GHDL string with hostname and port in the format "hostname:port"
#[no_mangle]
pub extern fn new_wishbone_tcp_server(hostname: &GHDLNaturalDimArr) -> *mut WBServer {
    let host_str = hostname.get_str().unwrap();
    let mut addr_iter = host_str.to_socket_addrs().unwrap();
    let addr = addr_iter.next().unwrap();
    Box::into_raw(Box::new(
        WBServer {
            listener: TcpListener::bind(addr).unwrap(),
            stream: None,
            reader: None,
            addr: 0,
            data: 0,
        }))
}

/// Wait for a new TCP connection
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
#[no_mangle]
pub extern fn wishbone_tcp_server_wait_con(fsrv: &mut WBServer) {
    let (socket, addr) = fsrv.listener.accept().unwrap();
    println!("Connected! {:?}", addr);
    fsrv.reader = Some(BufReader::new(socket.try_clone().unwrap()));
    fsrv.stream = Some(socket);
}

/// Print internal state of the WBServer struct
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
fn print_state(fsrv: &WBServer) {
    println!("Address: 0x{:08x}", fsrv.addr);
    println!("Data: 0x{:08x}", fsrv.data);
}

fn parse_line(fsrv: &mut WBServer, line: &String) -> WBMsgType {
    let args: Vec<&str> = line.trim_matches(|c| c == ' '  ||
                                                c == '\n' ||
                                                c == '\r').split(" ").collect();

    if args.len() > 0 {
        // This parsing logic is written in a cryptic way, maybe there
        // is a better syntax for reading hex values and abort on any
        // syntax error
        match &args[0] {
            &"write" => {
                if args.len() == 3 {
                    match u32::from_str_radix(args[1], 16) {
                        Ok(addr) => {
                            match u32::from_str_radix(args[2], 16) {
                                Ok(data) => {
                                    fsrv.addr = addr;
                                    fsrv.data = data;
                                    WBMsgType::WriteData
                                },
                                Err(_) => WBMsgType::ParsingErr,
                            }
                        },
                        Err(_) => WBMsgType::ParsingErr,
                    }
                } else {
                    WBMsgType::ParsingErr
                }
            },
            &"read" => {
                if args.len() == 2 {
                    match u32::from_str_radix(args[1], 16) {
                        Ok(addr) => {
                            fsrv.addr = addr;
                            WBMsgType::ReadData
                        },
                        Err(_) => WBMsgType::ParsingErr,
                    }
                } else {
                    WBMsgType::ParsingErr
                }
            },
            // wait_event command action will be defined by the VHDL side
            &"wait_event" => {
                WBMsgType::WaitEvent
            },
            &"debug" => {
                print_state(fsrv);
                WBMsgType::Debug
            },
            &"disconnect" => {
                fsrv.stream.as_mut().unwrap().shutdown(Shutdown::Both).unwrap();
                WBMsgType::Disconnected
            },
            &"exit" => WBMsgType::Exit,
            _ => {WBMsgType::ParsingErr},
        }
    } else {
        WBMsgType::ParsingErr
    }
}

/// Wait for the client to send new data
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
/// * `msg_type` - A WBMsgType enum pointer for returning the message type received
#[no_mangle]
pub extern fn wishbone_tcp_server_wait_data(fsrv: &mut WBServer, msg_type: &mut WBMsgType) {
    match &mut fsrv.reader {
        None => *msg_type = WBMsgType::Disconnected,
        Some(reader) => {
            let mut line = String::new();
            let bytes = reader.read_line(&mut line).unwrap();
            if bytes > 0 {
                *msg_type = parse_line(fsrv, &line);
            } else {
                *msg_type = WBMsgType::Disconnected;
            }
        },
    }
}

/// Convert a 32 bits number to GHDL's internal representation of std_logic_vector
///
/// # Arguments
/// * `num` - Input number to be converted
/// * `std_vec` - std_logic_vector(31 downto 0) output
fn u32_to_std_vec(mut num: u32, std_vec: &mut [u8; 32]) {
    for element in std_vec.iter_mut() {
        if num & 0x80000000 == 0 {
            *element = 2;
        } else {
            *element = 3;
        }
        num = num << 1;
    }
}

/// Convert a 32 bits std_logic_vector to u32
///
/// # Arguments
/// * `std_vec` - std_logic_vector(31 downto 0) input
/// # Returns
/// * `num` - Output number
fn std_vec_to_u32(std_vec: &[u8; 32]) -> u32 {
    let mut num: u32 = 0;
    for element in std_vec.iter() {
        num = num << 1;
        if *element == (IEEEStdLogic::High as u8) ||
        *element == (IEEEStdLogic::WeakHigh as u8) {
            num = num | 0x00000001;
        } else if *element != (IEEEStdLogic::Low as u8) &&
        *element != (IEEEStdLogic::WeakLow as u8) {
            eprintln!("std_logic_vector with undefined/unknown/high-z/don't-care bit. Treating it as '0'.");
        }
    }
    num
}

/// Get the address and data to be write / read
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
/// * `addr` - Address buffer as std_logic_vector(31 downto 0)
/// * `data` - Data buffer as std_logic_vector(31 downto 0)
#[no_mangle]
pub extern fn wishbone_tcp_server_get_addr_data(fsrv: &mut WBServer, addr: &mut [u8; 32], data: &mut [u8; 32]) {
    u32_to_std_vec(fsrv.addr, addr);
    u32_to_std_vec(fsrv.data, data);
}

/// Send the data read to the client
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
/// * `data` - Data buffer as std_logic_vector(31 downto 0) to be send to the client
#[no_mangle]
pub extern fn wishbone_tcp_server_write_data(fsrv: &mut WBServer, data: &[u8; 32]) {
    match &mut fsrv.stream {
        Some(stream) => {
            let data_str = format!("{:08x}\n", std_vec_to_u32(data));
            stream.write(data_str.as_bytes()).unwrap();
        },
        None => (),
    }
}

/// Send event string
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
/// * `evt` - GHDL string with the event/interrupt identifier
#[no_mangle]
pub extern fn wishbone_tcp_server_write_event(fsrv: &mut WBServer, evt: &GHDLNaturalDimArr) {
    match &mut fsrv.stream {
        Some(stream) => {
            let data_str = format!("event {}\n", evt.get_str().unwrap());
            stream.write(data_str.as_bytes()).unwrap();
        },
        None => (),
    }
}

/// Delete a WBServer instance
///
/// This is for reference only, GHDL will free the fsrv struct
/// automatically on shutdown, so calling this function will result in
/// a double-free exception. Still, GHDL will not call the
/// 'destructors' for the objects instances inside the fsrv struct,
/// but the process will exit not long after anyway, so it shouldn't
/// matter.
///
/// # Arguments
/// * `fsrv` - WBServer instance pointer
#[no_mangle]
pub extern fn wishbone_tcp_server_delete(fsrv: *mut WBServer) {
    if !fsrv.is_null() {
        unsafe {
            let _ = Box::from_raw(fsrv);
        }
    }
}
