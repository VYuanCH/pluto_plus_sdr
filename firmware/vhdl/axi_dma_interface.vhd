
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.axil_interface_pkg.all;
use work.array_types.all;
use work.basic_pkg.all;
use work.axi_datamover_pkg.all;
use work.axi_reg_datamover_pkg.all;


entity axi_dma_interface is
  generic (
      AXIL_REG_BASE_ADDRESS : UNSIGNED(AXIL_ADDR_W - 1 downto 0);
      NUM_OF_WORDS_WIDTH    : natural := 32
  );
  port (
    clk_i                : in std_logic;
    reset_i              : in std_logic;
    data_m_tdata_o       : out std_logic_vector(MM2S_DATA_WIDTH - 1 downto 0);
    data_m_tvalid_o      : out std_logic;
    data_m_tready_i      : in  std_logic;
    data_m_tlast_o       : out std_logic;
    data_s_tdata_i       : in  std_logic_vector(S2MM_DATA_WIDTH - 1 downto 0);
    data_s_tvalid_i      : in  std_logic;
    data_s_tready_o      : out std_logic; 
    data_s_tlast_i       : in  std_logic;
    -- dma interface and axil register interface
    dma_interface_master_i   : in dma_ports_master_t;
    dma_interface_slave_o    : out dma_ports_slave_t;
    axil_reg_master_i        : in axil_master_t;
    axil_reg_slave_o         : out axil_slave_t;
    ext_wr_start_i           : in std_logic
    
  );
end entity;


architecture Behavioral of axi_dma_interface is
  signal dma_controller_write_address         : unsigned(ADDRESS_WIDTH - 1 downto 0);       
  signal dma_controller_write_num_of_words    : unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);             
  signal dma_controller_write_start           : std_logic;     
  signal dma_controller_read_address          : unsigned(ADDRESS_WIDTH - 1 downto 0);       
  signal dma_controller_read_num_of_words     : unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);           
  signal dma_controller_read_start            : std_logic;   
  signal axil_write_regs  : array_slv_t(0 to NUMBER_OF_REG - 1)(AXIL_DATA_W - 1 downto 0);
  signal axil_read_regs   : array_slv_t(0 to NUMBER_OF_REG - 1)(AXIL_DATA_W - 1 downto 0);
  signal use_ext_wr_start : std_logic;
begin

  process(clk_i)
  begin
    if rising_edge(clk_i) then 
      if use_ext_wr_start = '1' then 
        dma_controller_write_start <= ext_wr_start_i;
      else
        dma_controller_write_start                   <= axil_write_regs(WRITE_START_IDX)(0);
      end if;
      dma_controller_write_address(31 downto 0)      <= unsigned(axil_write_regs(WRITE_ADDRESS_L_IDX)(31 downto 0));
      dma_controller_write_num_of_words(31 downto 0) <= unsigned(axil_write_regs(WRITE_NUM_OF_WORDS_IDX)(31 downto 0));
      use_ext_wr_start                               <= axil_write_regs(USE_EXT_WR_TRIGGER_IDX)(0);
      dma_controller_read_start                      <= axil_write_regs(READ_START_IDX)(0);
      dma_controller_read_address(31 downto 0)       <= unsigned(axil_write_regs(READ_ADDRESS_L_IDX)(31 downto 0));
      dma_controller_read_num_of_words(31 downto 0)  <= unsigned(axil_write_regs(READ_NUM_OF_WORDS_IDX)(31 downto 0));
    end if;
  end process;

  iaxi_reg : entity work.axi_registers
  generic map (
    AXIL_BASE_ADDRESS   => AXIL_REG_BASE_ADDRESS,
    NUMBER_OF_REGISTERS => NUMBER_OF_REG,
    WRITE_MASK          => WRITE_MASK
  )
  port map(
    clk_i             => clk_i,
    reset_i           => '0',
    axil_master_i     => axil_reg_master_i,
    axil_slave_o      => axil_reg_slave_o,
    read_reg_i        => (others=>( others =>'0')),
    write_reg_o       => axil_write_regs
  );

  iaxi_datamover_controller : entity work.axi_datamover_controller
  generic map (
    NUM_OF_WORDS_WIDTH   => NUM_OF_WORDS_WIDTH
  )
  port map(
    clk_i                => clk_i,
    reset_i              => reset_i,
    write_address_i      => dma_controller_write_address, 
    write_num_of_words_i => dma_controller_write_num_of_words,
    write_start_i        => dma_controller_write_start,
    read_address_i       => dma_controller_read_address,
    read_num_of_words_i  => dma_controller_read_num_of_words,
    read_start_i         => dma_controller_read_start,

    data_m_tdata_o       => data_m_tdata_o,
    data_m_tvalid_o      => data_m_tvalid_o,
    data_m_tready_i      => data_m_tready_i,
    data_m_tlast_o       => data_m_tlast_o,
    data_s_tdata_i       => data_s_tdata_i,
    data_s_tvalid_i      => data_s_tvalid_i,
    data_s_tready_o      => data_s_tready_o,
    data_s_tlast_i       => data_s_tlast_i,    
    -- Axi Datamover interface
    -- axi_datamover axis interface
    axis_s2mm_tdata_o    => dma_interface_slave_o.axis_s2mm_tdata, 
    axis_s2mm_tvalid_o   => dma_interface_slave_o.axis_s2mm_tvalid,
    axis_s2mm_tready_i   => dma_interface_master_i.axis_s2mm_tready,
    axis_s2mm_tlast_o    => dma_interface_slave_o.axis_s2mm_tlast, 
    axis_mm2s_tdata_i    => dma_interface_master_i.axis_mm2s_tdata, 
    axis_mm2s_tvalid_i   => dma_interface_master_i.axis_mm2s_tvalid,
    axis_mm2s_tready_o   => dma_interface_slave_o.axis_mm2s_tready,
    axis_mm2s_tlast_i    => dma_interface_master_i.axis_mm2s_tlast, 
    mm2s_cmd_m_tdata_o   => dma_interface_slave_o.mm2s_cmd_tdata,
    mm2s_cmd_m_tvalid_o  => dma_interface_slave_o.mm2s_cmd_tvalid,  
    mm2s_cmd_m_tready_i  => dma_interface_master_i.mm2s_cmd_tready,  
    s2mm_cmd_m_tdata_o   => dma_interface_slave_o.s2mm_cmd_tdata, 
    s2mm_cmd_m_tvalid_o  => dma_interface_slave_o.s2mm_cmd_tvalid,  
    s2mm_cmd_m_tready_i  => dma_interface_master_i.s2mm_cmd_tready,
    
    mm2s_sts_tdata_i   => dma_interface_master_i.mm2s_sts_tdata,
    mm2s_sts_tvalid_i  => dma_interface_master_i.mm2s_sts_tvalid,  
    mm2s_sts_tready_o  => dma_interface_slave_o.mm2s_sts_tready,  
    s2mm_sts_tdata_i   => dma_interface_master_i.s2mm_sts_tdata, 
    s2mm_sts_tvalid_i  => dma_interface_master_i.s2mm_sts_tvalid,  
    s2mm_sts_tready_o  => dma_interface_slave_o.s2mm_sts_tready 
    
  );

end Behavioral;