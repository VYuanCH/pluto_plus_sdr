library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use work.array_types.all;
use work.basic_pkg.all;
use work.axil_interface_pkg.all;

entity axi_tx_mem is
  generic (
    AXIL_REG_BASE_ADDRESS : UNSIGNED(AXIL_ADDR_W - 1 downto 0);
    MEM_DEPTH  : natural   := 4096;
    DATA_W     : natural   := 16
  );
  port (
    clk_i           : in std_logic;
    reset_i         : in std_logic;
    src_data_i      : in std_logic_vector(DATA_W - 1 downto 0);
    src_valid_i     : in std_logic;
    src_ready_o     : out std_logic;
    dst_data_o      : out std_logic_vector(DATA_W - 1 downto 0);
    dst_valid_o     : out std_logic;
    dst_next_i      : in  std_logic;
    axil_reg_master_i   : in axil_master_t;
    axil_reg_slave_o    : out axil_slave_t
  );
end entity;

architecture Behavioral of axi_tx_mem is
constant NUMBER_OF_REG  : natural := 8;
constant WRITE_MASK     : std_logic_vector(NUMBER_OF_REG - 1 downto 0) := (others=>'1');

signal axil_write_regs  : array_slv_t(0 to NUMBER_OF_REG - 1)(AXIL_DATA_W - 1 downto 0);
signal axil_read_regs   : array_slv_t(0 to NUMBER_OF_REG - 1)(AXIL_DATA_W - 1 downto 0);

signal mode             : std_logic; -- Mode : 0, play once. Mode 1 : play repeatedly
signal mem_high_addr    : unsigned(ceil_log2(MEM_DEPTH) - 1 downto 0);
signal load_data        : std_logic;
signal play_data        : std_logic;
begin

  process(clk_i)
  begin 
    if rising_edge(clk_i) then 
      mode          <= axil_write_regs(0)(0);
      mem_high_addr <= unsigned(axil_write_regs(1)(ceil_log2(MEM_DEPTH) - 1 downto 0));
      load_data     <= axil_write_regs(2)(0);
      play_data     <= axil_write_regs(3)(0);
    end if; 
  end process;

  i_axi_reg : entity work.axi_registers
  generic map (
    AXIL_BASE_ADDRESS   => AXIL_REG_BASE_ADDRESS,
    NUMBER_OF_REGISTERS => NUMBER_OF_REG,
    WRITE_MASK          => WRITE_MASK
  )
  port map(
    clk_i             => clk_i,
    reset_i           => reset_i,
    axil_master_i     => axil_reg_master_i,
    axil_slave_o      => axil_reg_slave_o,
    read_reg_i        => (others=>( others =>'0')),
    write_reg_o       => axil_write_regs
  );

  i_tx_mem : entity work.tx_mem
  generic map (
    MEM_DEPTH     => MEM_DEPTH,
    DATA_W        => DATA_W
  )
  port map(
    clk_i             => clk_i,
    reset_i           => reset_i,
    src_data_i        => src_data_i,  
    src_valid_i       => src_valid_i,    
    src_ready_o       => src_ready_o,    
    dst_data_o        => dst_data_o,  
    dst_valid_o       => dst_valid_o,    
    dst_next_i        => dst_next_i,
    mode_i            => mode,
    mem_high_addr_i   => mem_high_addr,        
    load_data_i       => load_data,    
    play_data_i       => play_data    

  );

end Behavioral;