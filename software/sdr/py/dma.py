import mmap
import axil_reg
import time

DMA_CTRL_REG_BASEADDR= 0x43C10000 
DMA_DDR_ADDR_OFFSET = 0x30000000  # DMA buffer physical address
MAP_SIZE  = 0x10000000  # 128 MB
SAMPLE_RATE = 30.72e6
WORD_SIZE = 8
  
def capture_data(dma_capture_samples):
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,8, dma_capture_samples)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,1, DMA_DDR_ADDR_OFFSET)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,2, 0x00000000)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,3, dma_capture_samples)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,0, 0x1)
  axil_reg.write_reg(DMA_CTRL_REG_BASEADDR,0, 0x0)
  time.sleep(dma_capture_samples/SAMPLE_RATE)
  time.sleep(10e-6)

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
