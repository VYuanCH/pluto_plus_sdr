import mmap
import axil_reg
import time
import os
DMA_CTRL_REG_BASEADDR= 0x43C10000 
TX_MEM_REG_BASEADDR= 0x43C00000 
DMA_DDR_ADDR_OFFSET = 0x30000000  # DMA buffer physical address
MAP_SIZE  = 0x10000000  # 128 MB
SAMPLE_RATE = 30.72e6
WORD_SIZE = 8
  
def capture_data(dma_capture_samples):
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,8, 0)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,1, DMA_DDR_ADDR_OFFSET)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,2, 0x00000000)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,3, dma_capture_samples)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,0, 0x1)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,0, 0x0)
  time.sleep(dma_capture_samples/SAMPLE_RATE)
  time.sleep(10e-6)



def transfer_data_to_pl(number_of_samples,file_name):
  fd = os.open("/dev/mem", os.O_RDWR | os.O_SYNC)
  ddr_mem = mmap.mmap(fd, MAP_SIZE, mmap.MAP_SHARED,
                mmap.PROT_WRITE, offset=DMA_DDR_ADDR_OFFSET)
  with open(file_name, "rb") as f:
    data = f.read()
    ddr_mem.write(data)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,8, 0)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,5, DMA_DDR_ADDR_OFFSET)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,6, 0x00000000)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,7, number_of_samples)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,4, 0x1)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,4, 0x0)

def start_tx_mem_load(number_of_samples):
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,0,0)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,1,number_of_samples - 1)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,2,1)
  time.sleep(10e-6)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,2,0)


def start_tx_mem_play(number_of_samples,tx_mode):
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,3,0)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,0,tx_mode)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,1,number_of_samples - 1)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,3,1)
  time.sleep(10e-6)
  axil_reg.write_reg(TX_MEM_REG_BASEADDR,3,0)

def write_rx_data_to_file(number_of_samples,file_name):
  capture_data(number_of_samples)
  # Open /dev/mem for read access
  with open("/dev/mem", "rb") as f:
    # Memory-map the DMA region
    mem = mmap.mmap(f.fileno(), MAP_SIZE, mmap.MAP_SHARED,
                    mmap.PROT_READ, offset=DMA_DDR_ADDR_OFFSET)
    # Read raw bytes
    raw_data = mem.read(number_of_samples * WORD_SIZE)
    # Save to binary file
    with open(file_name, "wb") as bin_file:
        bin_file.write(raw_data)
    mem.close()

def send_tx_data_from_file(number_of_samples,file_name,tx_mode):
  start_tx_mem_load(number_of_samples)
  transfer_data_to_pl(number_of_samples,file_name)
  start_tx_mem_play(number_of_samples,tx_mode)