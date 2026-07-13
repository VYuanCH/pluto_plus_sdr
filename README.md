# PlutoSky / Pluto Plus AD9361 PetaLinux Project

Hardware: OpenSourceSDRLab PlutoSky 7020-SDR AD9361 with PA

Required Tools:
PetaLinux 2024.2
Vivado 2024.2

This repository contains custom Vivado and PetaLinux project files for bringing up the OpenSourceSDRLab PlutoSky / Pluto Plus-style SDR board based on:

- Xilinx Zynq-7020
- Analog Devices AD9361
- Custom data interface module ad9361.vhd
- ADI Linux IIO driver stack
- PetaLinux 2024.2

The current focus of this project is AD9361 control and custom FPGA integration using Linux/IIO. 
Linux IIO is used for configuring AD9361 through SPI. 
AD9361 data interface module, ad9361.vhd currently only support lvds fdd 2r2t mode. Supports for other modes will be added later. 
Custom DMA controller is added to transfer Rx/Tx data between FPGA and DDR. Analog Device provides DMA in their VHDL library, but I decided to use my own DMA controller. 
More DSP modules will be added later to experiment with the SDR


## Current Status

Working:

- PetaLinux boots on the target board.
- ad9361 is configured through SPI
- RX LVDS interface is working after fixing AD9361 LVDS bias.
- AD9361 BIST/PRBS and BIST tone were used for digital-interface validation.
- Manual register access through IIO debugfs is working.
- Python/manual DMA capture path has been used for RX sample inspection.
- Tx is currently being verified.

Important discovered setting:

```text
AD9361 register 0x03C = 0x07
adi,lvds-bias-mV = <600>;
Without this setting, RX LVDS data showed occasional corrupted samples.