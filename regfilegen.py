"""
Script for generating an AXI memory mapped register file.
"""

from jinja2 import Environment, FileSystemLoader
from math import log2, ceil


class Register(object):
    """A single register in a register file"""
    def __init__(self, address, label, mode, initval=0x00000000):
        super(Register, self).__init__()
        self.addr = address
        self.label = label
        self.mode = mode
        self.initval = initval


def regfilegen(filename, registers, module_name, register_width=32):
    assert int(log2(register_width)) == log2(register_width), "register_width must be power of 2"
    register_byte_width = register_width // 8
    log2_register_byte_width = int(log2(register_byte_width))

    ceil_log2_num_regs = ceil(log2(max(reg.addr for reg in registers) + 1))
    axi_addr_width = ceil_log2_num_regs + log2_register_byte_width
    num_regs = 2**ceil_log2_num_regs

    just_width = max(len(reg.label) for reg in registers)

    env = Environment(loader=FileSystemLoader('templates'))
    template = env.get_template('axi_regfile.vhd')

    with open(filename, "w") as file:
        file.write(
            template.render(
                MODULE_NAME=module_name,
                registers=registers,
                JUST_WIDTH=just_width,
                NUM_REGISTERS=num_regs,
                AXI_ADDR_WIDTH=axi_addr_width,
                REGISTER_WIDTH=register_width,
                REGISTER_BYTE_WIDTH=register_byte_width,
                LOG2_REGISTER_BYTE_WIDTH=log2_register_byte_width
            )
        )

if __name__ == '__main__':
    regs = [
        Register(0, "status", "stat"),
        Register(1, "start", "trig"),
        Register(2, "ctrl1", "ctrl")
    ]

    regfilegen("regfile.vhd", regs, "regfile", 32)
