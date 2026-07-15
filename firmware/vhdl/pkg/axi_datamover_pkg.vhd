
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package axi_datamover_pkg is
   constant MM2S_DATA_WIDTH : natural := 64;
   constant S2MM_DATA_WIDTH : natural := 64;
   constant MM2S_MEM_DATA_WIDTH : natural := 128;
   constant S2MM_MEM_DATA_WIDTH : natural := 128;
   constant MM2S_MAX_BURST_SIZE : natural := 256;
   constant S2MM_MAX_BURST_SIZE : natural := 256;
   constant MM2S_BTT_WIDTH      : natural := 16;
   constant S2MM_BTT_WIDTH      : natural := 16;
   constant MM2S_CMD_WIDTH      : natural := 72;
   constant S2MM_CMD_WIDTH      : natural := 72;
   constant S2MM_STS_WIDTH      : natural := 8;
   constant MM2S_STS_WIDTH      : natural := 8;
   
   
   constant ADDRESS_WIDTH       : natural := 32;


  type dma_ports_master_t is record
    axis_s2mm_tready      : std_logic;
    axis_mm2s_tdata       : std_logic_vector(MM2S_DATA_WIDTH - 1 downto 0);
    axis_mm2s_tvalid      : std_logic;
    axis_mm2s_tlast       : std_logic;
    mm2s_cmd_tready       : std_logic;
    s2mm_cmd_tready       : std_logic;
    
    s2mm_sts_tdata        : std_logic_vector(S2MM_STS_WIDTH - 1 downto 0);
    s2mm_sts_tlast        : std_logic;
    s2mm_sts_tvalid       : std_logic;
    mm2s_sts_tdata        : std_logic_vector(MM2S_STS_WIDTH - 1 downto 0);
    mm2s_sts_tlast        : std_logic;
    mm2s_sts_tvalid       : std_logic;
  end record;
  
  type dma_ports_slave_t is record
    axis_s2mm_tdata       : std_logic_vector(S2MM_DATA_WIDTH - 1 downto 0);
    axis_s2mm_tvalid      : std_logic;
    axis_s2mm_tlast       : std_logic;
    axis_mm2s_tready      : std_logic; 
    mm2s_cmd_tdata        : std_logic_vector(MM2S_CMD_WIDTH - 1 downto 0);
    mm2s_cmd_tvalid       : std_logic;
    s2mm_cmd_tdata        : std_logic_vector(S2MM_CMD_WIDTH - 1 downto 0);
    s2mm_cmd_tvalid       : std_logic;
    
    s2mm_sts_tready       : std_logic;
    mm2s_sts_tready       : std_logic;
    
  end record;
end package;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package axi_reg_datamover_pkg is
  constant NUMBER_OF_REG   : natural :=16;

  constant WRITE_START_IDX        : natural := 0;
  constant WRITE_ADDRESS_L_IDX    : natural := 1;
  constant WRITE_ADDRESS_H_IDX    : natural := 2;
  constant WRITE_NUM_OF_WORDS_IDX : natural := 3;
  constant READ_START_IDX         : natural := 4;
  constant READ_ADDRESS_L_IDX     : natural := 5;
  constant READ_ADDRESS_H_IDX     : natural := 6;
  constant READ_NUM_OF_WORDS_IDX  : natural := 7;
  constant USE_EXT_WR_TRIGGER_IDX : natural := 8;

  constant WRITE_MASK             : std_logic_vector(NUMBER_OF_REG - 1 downto 0) := (
    WRITE_START_IDX           => '1',
    WRITE_ADDRESS_L_IDX       => '1',
    WRITE_ADDRESS_H_IDX       => '1',
    WRITE_NUM_OF_WORDS_IDX    => '1',
    READ_START_IDX            => '1',
    READ_ADDRESS_L_IDX        => '1',
    READ_ADDRESS_H_IDX        => '1',
    READ_NUM_OF_WORDS_IDX     => '1',
    USE_EXT_WR_TRIGGER_IDX    => '1',
    others                    => '0'
  );
end package;