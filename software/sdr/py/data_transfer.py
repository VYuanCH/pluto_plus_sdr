import argparse
import dma

def transfer_data():
  parser = argparse.ArgumentParser(description="Transfer Data between FPGA and Filesystem through DMA")
  #parser.add_argument("file_name", help="File Name")
  parser.add_argument("-r","--receive", type=str, default="Data.bin", help="Receive Data from FPGA and write to file")
  parser.add_argument("-s","--send", type=str, default="Data.bin", help="Send Data in file to FPGA")
  parser.add_argument("-p","--PathToTx", type=int, default=1, help="Tx path 1: File to bmem, 2: file to dma, 3: ddr to dma")
  parser.add_argument("-l","--length", type=int, default=1024, help="Transfer Length, Number of 64 bits words")
  parser.add_argument("-m","--TxMode", type=int, default=0, help="Transmit mode, 0 - transmit waveform once, 1 - transmit waveform continously")
  args = parser.parse_args()
  print("receive file:", args.receive)
  print("send file:", args.send)
  print("length: ", args.length)
  if (args.receive!="" and args.length >0):
    dma.write_rx_data_to_file(args.length,args.receive)
  
  if args.PathToTx == 1:
    if (args.send!="" and args.length >0):
      dma.tx_from_file_mem(args.length,args.send,args.TxMode)
  if args.PathToTx == 2:
    if (args.send!="" and args.length >0):
      dma.tx_from_file_direct_dma(args.length,args.send,args.TxMode)
  if args.PathToTx == 3:
    if (args.send!="" and args.length >0):
      dma.tx_from_ddr_direct_dma(args.length,args.TxMode)


if __name__ == "__main__":
    transfer_data()