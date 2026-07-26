import mmap
import os
import struct

def write_reg(reg_base_addr,reg_index, value):
  # === OPEN /dev/mem ===
  AXIL_RANGE     = 0x1000
  fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
  # === MEMORY MAP AXI REGION ===
  mem = mmap.mmap(fd, AXIL_RANGE, mmap.MAP_SHARED,
                  mmap.PROT_READ | mmap.PROT_WRITE,
                  offset=reg_base_addr)
  """Write a 32-bit value to the AXI register at the given offset"""
  mem.seek(reg_index*4)
  mem.write(struct.pack("<I", value))  # little-endian 32-bit
  mem.close()
  os.close(fd)

def read_reg(reg_base_addr,reg_index):
  # === OPEN /dev/mem ===
  AXIL_RANGE     = 0x1000
  fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
  # === MEMORY MAP AXI REGION ===
  mem = mmap.mmap(fd, AXIL_RANGE, mmap.MAP_SHARED,
                  mmap.PROT_READ | mmap.PROT_WRITE,
                  offset=reg_base_addr)
  """Read a 32-bit value from the AXI register at the given offset"""
  mem.seek(reg_index*4)
  data = mem.read(4)
  mem.close()
  os.close(fd)
  return struct.unpack("<I", data)[0]

