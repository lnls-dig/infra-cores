#!/usr/bin/env python3

import argparse
import socket
import json

class RegField:
    def __init__(self, bitshift: int, mask: int, state_dict=None):
        """mask will be applied after the bitshift"""
        self._bitshift = bitshift
        self._mask = mask
        if state_dict == None:
            self._is_numeric = True
        else:
            self._is_numeric = False
            self._state_to_value = state_dict
            self._value_to_state = {val: key for key, val in state_dict.items()}

    def to_reg(self, state, reg_read=0):
        """You can do a read-modify-write operation by reading the register and calling this method with reg_read set to the read value"""
        if self._is_numeric == True:
            val = state
        else:
            val = self._state_to_value[state]
        reg_read = reg_read & ~(self._mask << self._bitshift)
        reg_read = reg_read | ((val & self._mask) << self._bitshift)
        return reg_read

    def to_state(self, reg: int):
        if self._is_numeric == True:
            return (reg >> self._bitshift) & self._mask
        else:
            return self._value_to_state[(reg >> self._bitshift) & self._mask]

class Reg:
    def __init__(self, fields_dict, addr: int):
        self._reg_fields = fields_dict
        self.addr = addr

    def read(self, reg: int):
        fields = {}
        for field, _ in self._reg_fields.items():
            fields[field] = self._reg_fields[field].to_state(reg)
        return fields

    def modify(self, reg: int, fields) -> int:
        for field, value in fields.items():
            reg = self._reg_fields[field].to_reg(value, reg)
        return reg

class ACQ:
    def __init__(self, hostname: str, port: int):
        self._hostname = hostname
        self._port = port
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        ## CTL ##
        reg_fields = {
            "FSM_START_ACQ": RegField(0, 0x01, {
                "DO_NOTHING": 0,
                "START": 1,
            }),
            "FSM_STOP_ACQ": RegField(1, 0x01, {
                "DO_NOTHING": 0,
                "STOP": 1,
            }),
            "FSM_ACQ_NOW": RegField(16, 0x01, {
                "WAIT_TRIG": 0,
                "IMMEDIATE": 1,
            })
        }
        self._reg_ctl = Reg(reg_fields, 0x00)

        ## STA ##
        reg_fields = {
            "FSM_STATE": RegField(0, 0x03, {
                "ILLEGAL0": 0,
                "IDLE": 1,
                "PRE_TRIG": 2,
                "WAIT_TRIG": 3,
                "POST_TRIG": 4,
                "DECR_SHOT": 5,
                "ILLEGAL6": 6,
                "ILLEGAL7": 7,
            }),
            "FSM_ACQ_DONE": RegField(3, 0x01, {
                "IN_PROGRESS": 0,
                "COMPLETED": 1,
            }),
            "FC_TRANS_DONE": RegField(8, 0x01, {
                "IN_PROGRESS": 0,
                "COMPLETED": 1,
            }),
            "FC_FULL": RegField(9, 0x01, {
                "NOT_FULL": 0,
                "FULL": 1,
            }),
            "DDR3_TRANS_DONE": RegField(16, 0x01, {
                "IN_PROGRESS": 0,
                "COMPLETED": 1,
            }),
        }
        self._reg_sta = Reg(reg_fields, 0x04)

        ## TRIG_CFG ##
        reg_fields = {
            "HW_TRIG_SEL": RegField(0, 0x01, {
                "INTERNAL": 0,
                "EXTERNAL": 1,
            }),
            "HW_TRIG_POL": RegField(1, 0x01, {
                "POS_EDGE": 0,
                "NEG_EDGE": 1,
            }),
            "HW_TRIG_EN": RegField(2, 0x01, {
                "DISABLED": 0,
                "ENABLED": 1,
            }),
            "SW_TRIG_EN": RegField(3, 0x01, {
                "DISABLED": 0,
                "ENABLED": 1,
            }),
            "INT_TRIG_SEL": RegField(4, 0x1F),
        }
        self._reg_trig_cfg = Reg(reg_fields, 0x08)

        ## TRIG_DATA_CFG ##
        reg_fields = {
            "THRES_FILT": RegField(0, 0xFF),
        }
        self._reg_trig_data_cfg = Reg(reg_fields, 0x0C)

        ## SHOTS ##
        reg_fields = {
            "NB": RegField(0, 0xFFFF),
            "MULTISHOT_RAM_SIZE_IMPL": RegField(16, 0x01, {
                False: 0,
                True: 1,
            }),
            "MULTISHOT_RAM_SIZE": RegField(17, 0x7FFF),
        }
        self._reg_shots = Reg(reg_fields, 0x1C)

        ## ACQ_CHAN_CTL ##
        reg_fields = {
            "WHICH": RegField(0, 0x1F),
            "DTRIG_WHICH": RegField(8, 0x1F),
            "NUM_CHAN": RegField(16, 0x1F),
        }
        self._reg_acq_chan_ctl = Reg(reg_fields, 0x38)

        ## CH_DESC ##
        reg_fields = {
            "INT_WIDTH": RegField(0, 0xFFFF),
            "NUM_COALESCE": RegField(16, 0xFFFF),
        }
        self._reg_ch_desc = Reg(reg_fields, 0x3C)

        ## CH_ATOM_DESC ##
        reg_fields = {
            "NUM_ATOMS": RegField(0, 0xFFFF),
            "ATOM_WIDTH": RegField(16, 0xFFFF),
        }
        self._reg_ch_atom_desc = Reg(reg_fields, 0x40)

    def connect(self):
        self._socket.connect((self._hostname, self._port))

    def _write_reg(self, addr: int, data: int):
        self._socket.send("write {:08x} {:08x}\n".format(addr, data).encode("UTF-8"))

    def _read_reg(self, addr: int) -> int:
        self._socket.send("read {:08x}\n".format(addr).encode("UTF-8"))
        resp = self._socket.makefile().readline()
        return int(resp, 16)

    def read_ctl(self):
        addr = self._reg_ctl.addr
        reg = self._read_reg(addr)
        return self._reg_ctl.read(reg)

    def write_ctl(self, fields):
        addr = self._reg_ctl.addr
        reg = self._read_reg(addr)
        reg = self._reg_ctl.modify(reg, fields)
        self._write_reg(addr, reg)

    def read_sta(self):
        addr = self._reg_sta.addr
        reg = self._read_reg(addr)
        return self._reg_sta.read(reg)

    def read_trig_cfg(self):
        addr = self._reg_trig_cfg.addr
        reg = self._read_reg(addr)
        return self._reg_trig_cfg.read(reg)

    def write_trig_cfg(self, fields):
        addr = self._reg_trig_cfg.addr
        reg = self._read_reg(addr)
        reg = self._reg_trig_cfg.modify(reg, fields)
        self._write_reg(addr, reg)

    def read_trig_data_cfg(self):
        addr = self._reg_trig_data_cfg.addr
        reg = self._read_reg(addr)
        return self._reg_trig_data_cfg.read(reg)

    def write_trig_data_cfg(self, fields):
        addr = self._reg_trig_data_cfg.addr
        reg = self._read_reg(addr)
        reg = self._reg_trig_data_cfg.modify(reg, fields)
        self._write_reg(addr, reg)

    def read_trig_data_thres(self):
        return self._read_reg(0x10)

    def write_trig_data_thres(self, val: int):
        self._write_reg(0x10, val)

    def read_trig_dly(self):
        return self._read_reg(0x14)

    def write_trig_dly(self, val: int):
        self._write_reg(0x14, val)

    def send_sw_trig(self):
        self._write_reg(0x18, 0x01)

    def read_shots(self):
        addr = self._reg_shots.addr
        reg = self._read_reg(addr)
        return self._reg_shots.read(reg)

    def write_shots(self, fields):
        addr = self._reg_shots.addr
        reg = self._read_reg(addr)
        reg = self._reg_shots.modify(reg, fields)
        self._write_reg(addr, reg)

    def read_trig_pos(self):
        return self._read_reg(0x20)

    def read_pre_samples(self):
        return self._read_reg(0x24)

    def write_pre_samples(self, val):
        return self._write_reg(0x24, val)

    def read_post_samples(self):
        return self._read_reg(0x28)

    def write_post_samples(self, val):
        return self._write_reg(0x28, val)

    def read_samples_cnt(self):
        return self._read_reg(0x2C)

    def read_ddr3_start_addr(self):
        return self._read_reg(0x30)

    def write_ddr3_start_addr(self, val):
        return self._write_reg(0x30, val)

    def read_ddr3_end_addr(self):
        return self._read_reg(0x34)

    def write_ddr3_end_addr(self, val):
        return self._write_reg(0x34, val)

    def read_acq_chan_ctl(self):
        addr = self._reg_acq_chan_ctl.addr
        reg = self._read_reg(addr)
        return self._reg_acq_chan_ctl.read(reg)

    def write_acq_chan_ctl(self, fields):
        addr = self._reg_acq_chan_ctl.addr
        reg = self._read_reg(addr)
        reg = self._reg_acq_chan_ctl.modify(reg, fields)
        self._write_reg(addr, reg)

    def read_chan_desc(self, ch: int):
        addr = self._reg_ch_desc.addr + (ch * 8)
        reg = self._read_reg(addr)
        fields_desc = self._reg_ch_desc.read(reg)
        addr = self._reg_ch_atom_desc.addr + (ch * 8)
        reg = self._read_reg(addr)
        fields_atom = self._reg_ch_atom_desc.read(reg)
        return {**fields_desc, **fields_atom}

    def read_all(self):
        ch_ctl = self.read_acq_chan_ctl()
        regs = {
            "CTL": self.read_ctl(),
            "STA": self.read_sta(),
            "TRIG_CFG": self.read_trig_cfg(),
            "TRIG_DATA_CFG": self.read_trig_data_cfg(),
            "TRIG_DATA_THRES": self.read_trig_data_thres(),
            "TRIG_DLY": self.read_trig_dly(),
            "SHOTS": self.read_shots(),
            "TRIG_POS": self.read_trig_pos(),
            "PRE_SAMPLES": self.read_pre_samples(),
            "POST_SAMPLES": self.read_post_samples(),
            "SAMPLES_CNT": self.read_samples_cnt(),
            "DDR3_START_ADDR": self.read_ddr3_start_addr(),
            "DDR3_END_ADDR": self.read_ddr3_end_addr(),
            "ACQ_CHAN_CTL": ch_ctl,
            "CH_DESC": [self.read_chan_desc(i) for i in range(ch_ctl["NUM_CHAN"])]
        }
        return regs

    def finish_simu(self):
        self._socket.send("exit\n".encode("UTF-8"))

parser = argparse.ArgumentParser(description="ACQ simulation test")
parser.add_argument("--hostname", help="Wishbone TCP server hostname", required=True, type=str)
parser.add_argument("--port", help="Wishbone TCP server port", required=False, type=int)

args = parser.parse_args()

acq = ACQ(args.hostname, args.port)
acq.connect()
print(json.dumps(acq.read_all(), indent=4))

acq.write_acq_chan_ctl({
    "WHICH": 0,
    "DTRIG_WHICH": 0,
})
acq.write_pre_samples(16)
acq.write_ddr3_start_addr(0x0000)
acq.write_ddr3_end_addr(0x1000)
acq.write_trig_cfg({
    "SW_TRIG_EN": "ENABLED",
})
acq.write_ctl({
    "FSM_ACQ_NOW": "IMMEDIATE",
    "FSM_START_ACQ": "START",
})
acq.send_sw_trig()
print(json.dumps(acq.read_all(), indent=4))
acq.finish_simu()
