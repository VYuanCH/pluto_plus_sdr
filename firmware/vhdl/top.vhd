library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.axil_interface_pkg.all;
use work.array_types.all;
use work.axi_datamover_pkg.all;
use IEEE.NUMERIC_STD.ALL;

entity top is
  Port ( 
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    SPI0_MISO_I : in STD_LOGIC;
    SPI0_MOSI_O : out STD_LOGIC;
    SPI0_SCLK_O : out STD_LOGIC;
    SPI0_SS_O : out STD_LOGIC;

    adc_clk_out : in STD_LOGIC;
    enable : out STD_LOGIC;
    adc_rst : out STD_LOGIC;
    rx_clk_in_n : in STD_LOGIC;
    rx_clk_in_p : in STD_LOGIC;
    rx_data_in_n : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rx_data_in_p : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rx_frame_in_n : in STD_LOGIC;
    rx_frame_in_p : in STD_LOGIC;
    tx_clk_out_n : out STD_LOGIC;
    tx_clk_out_p : out STD_LOGIC;
    tx_data_out_n : out STD_LOGIC_VECTOR ( 5 downto 0 );
    tx_data_out_p : out STD_LOGIC_VECTOR ( 5 downto 0 );
    tx_frame_out_n : out STD_LOGIC;
    tx_frame_out_p : out STD_LOGIC;
    txnrx : out STD_LOGIC
    
  );
end top;

architecture Behavioral of top is

constant DMA_NUM_OF_WORDS_WIDTH       : natural := 32;
constant TOP_REG_BASE_ADDRESS         : unsigned(AXIL_ADDR_W - 1 downto 0) := x"43C20000";
constant TOP_REG_NUMBER_OF_REG        : natural := 16;
constant TOP_REG_I_TEST_DATA_IDX      : natural := 1;
constant TOP_REG_Q_TEST_DATA_IDX      : natural := 2;
constant TOP_REG_USE_TEST_DATA_IDX    : natural := 3;
constant TOP_REG_POWER_READING_IDX    : natural := 4;
constant TOP_REG_WRITE_MASK           : std_logic_vector(TOP_REG_NUMBER_OF_REG - 1 downto 0) := (
    TOP_REG_I_TEST_DATA_IDX       => '1',
    TOP_REG_Q_TEST_DATA_IDX       => '1',
    TOP_REG_USE_TEST_DATA_IDX     => '1',
    TOP_REG_POWER_READING_IDX     => '0',
    others=>'1'
);

signal top_reg_rd                     : array_slv_t(0 to TOP_REG_NUMBER_OF_REG - 1 )(AXIL_DATA_W - 1 downto 0);
signal top_reg_wr                     : array_slv_t(0 to TOP_REG_NUMBER_OF_REG - 1 )(AXIL_DATA_W - 1 downto 0); 
signal top_reg_axil_master            : axil_master_t;
signal top_reg_axil_slave             : axil_slave_t;
signal adc_data_i0                    : STD_LOGIC_VECTOR ( 15 downto 0 );
signal adc_data_i1                    : STD_LOGIC_VECTOR ( 15 downto 0 );
signal adc_data_q0                    : STD_LOGIC_VECTOR ( 15 downto 0 );
signal adc_data_q1                    : STD_LOGIC_VECTOR ( 15 downto 0 );
signal adc_valid                      : std_logic;
signal dac_valid                      : std_logic;
signal dac_data_i0                    : STD_LOGIC_VECTOR ( 15 downto 0 ) := (others=>'0');
signal dac_data_i1                    : STD_LOGIC_VECTOR ( 15 downto 0 ) := (others=>'0');
signal dac_data_q0                    : STD_LOGIC_VECTOR ( 15 downto 0 ) := (others=>'0');
signal dac_data_q1                    : STD_LOGIC_VECTOR ( 15 downto 0 ) := (others=>'0');
signal adc_clk                        : std_logic;
signal clk_out_adc                    : std_logic;
signal clk_200mhz                     : std_logic;
signal dma_axil_reg_master            : axil_master_t;
signal dma_axil_reg_slave             : axil_slave_t;
signal dma_controller_m_tdata         : std_logic_vector(MM2S_DATA_WIDTH - 1 downto 0); 
signal dma_controller_m_tvalid        : std_logic;   
signal dma_controller_m_tready        : std_logic;   
signal dma_controller_m_tlast         : std_logic; 
signal dma_controller_s_tdata         : std_logic_vector(S2MM_DATA_WIDTH - 1 downto 0); 
signal dma_controller_s_tvalid        : std_logic;   
signal dma_controller_s_tready        : std_logic; -- Usually this is an output, but in this case the axi datamover controller only monitors the master channel of datamover, the slave module receiving the data should assign the tready.   
signal dma_controller_s_tlast         : std_logic;
signal dma_interface_master           : dma_ports_master_t;
signal dma_interface_slave            : dma_ports_slave_t;

attribute mark_debug : string;
attribute mark_debug of adc_valid   : signal is "true";
attribute mark_debug of dac_valid   : signal is "true";
attribute mark_debug of dac_data_i0 : signal is "true";
attribute mark_debug of dac_data_q0 : signal is "true";
attribute mark_debug of dac_data_i1 : signal is "true";
attribute mark_debug of dac_data_q1 : signal is "true";
attribute mark_debug of adc_data_i0 : signal is "true";
attribute mark_debug of adc_data_q0 : signal is "true";
attribute mark_debug of adc_data_i1 : signal is "true";
attribute mark_debug of adc_data_q1 : signal is "true";
begin

adc_rst <= '1';

i_ad9361 : entity work.ad9361_2r2t_ddr_fdd_lvds
port map(
  rx_clk_in_n      => rx_clk_in_n,
  rx_clk_in_p      => rx_clk_in_p,
  rx_data_in_n     => rx_data_in_n,
  rx_data_in_p     => rx_data_in_p,
  rx_frame_in_n    => rx_frame_in_n,
  rx_frame_in_p    => rx_frame_in_p,
  tx_clk_out_n     => tx_clk_out_n,
  tx_clk_out_p     => tx_clk_out_p,
  tx_data_out_n    => tx_data_out_n,
  tx_data_out_p    => tx_data_out_p,
  tx_frame_out_n   => tx_frame_out_n,
  tx_frame_out_p   => tx_frame_out_p,
  adc_clk_o        => adc_clk,
  data_valid_o     => adc_valid, 
  std_logic_vector(adc_data_ch0_r_o) => adc_data_i0(15 downto 0),
  std_logic_vector(adc_data_ch0_i_o) => adc_data_q0(15 downto 0),
  std_logic_vector(adc_data_ch1_r_o) => adc_data_i1(15 downto 0),
  std_logic_vector(adc_data_ch1_i_o) => adc_data_q1(15 downto 0),
  data_valid_i     => dac_valid,
  dac_data_ch0_r_i => signed(dac_data_i0(15 downto 0)),
  dac_data_ch0_i_i => signed(dac_data_q0(15 downto 0)),
  dac_data_ch1_r_i => signed(dac_data_i1(15 downto 0)),
  dac_data_ch1_i_i => signed(dac_data_q1(15 downto 0))
);

i_bd_1 : entity work.system_1
port map(
  clk_200_mhz               => clk_200mhz,
  adc_clk                   => adc_clk,
  DDR_addr(14 downto 0)     => DDR_addr(14 downto 0),
  DDR_ba(2 downto 0)        => DDR_ba(2 downto 0),
  DDR_cas_n                 => DDR_cas_n,
  DDR_ck_n                  => DDR_ck_n,
  DDR_ck_p                  => DDR_ck_p,
  DDR_cke                   => DDR_cke,
  DDR_cs_n                  => DDR_cs_n,
  DDR_dm(3 downto 0)        => DDR_dm(3 downto 0),
  DDR_dq(31 downto 0)       => DDR_dq(31 downto 0),
  DDR_dqs_n(3 downto 0)     => DDR_dqs_n(3 downto 0),
  DDR_dqs_p(3 downto 0)     => DDR_dqs_p(3 downto 0),
  DDR_odt                   => DDR_odt,
  DDR_ras_n                 => DDR_ras_n,
  DDR_reset_n               => DDR_reset_n,
  DDR_we_n                  => DDR_we_n,
  FIXED_IO_ddr_vrn          => FIXED_IO_ddr_vrn,
  FIXED_IO_ddr_vrp          => FIXED_IO_ddr_vrp,
  FIXED_IO_mio(53 downto 0) => FIXED_IO_mio(53 downto 0),
  FIXED_IO_ps_clk           => FIXED_IO_ps_clk,
  FIXED_IO_ps_porb          => FIXED_IO_ps_porb,
  FIXED_IO_ps_srstb         => FIXED_IO_ps_srstb,
  SPI0_MISO_I_0             => SPI0_MISO_I,
  SPI0_MOSI_O_0             => SPI0_MOSI_O,
  SPI0_SCLK_O_0             => SPI0_SCLK_O,
  SPI0_SS_O_0               => SPI0_SS_O,

  dma_reg_awaddr            => dma_axil_reg_master.awaddr,    
  dma_reg_awprot            => dma_axil_reg_master.awprot,    
  dma_reg_awvalid           => dma_axil_reg_master.awvalid,    
  dma_reg_wdata             => dma_axil_reg_master.wdata,  
  dma_reg_wstrb             => dma_axil_reg_master.wstrb,  
  dma_reg_wvalid            => dma_axil_reg_master.wvalid,    
  dma_reg_bready            => dma_axil_reg_master.bready,    
  dma_reg_araddr            => dma_axil_reg_master.araddr,    
  dma_reg_arprot            => dma_axil_reg_master.arprot,    
  dma_reg_arvalid           => dma_axil_reg_master.arvalid,    
  dma_reg_rready            => dma_axil_reg_master.rready,

  dma_reg_awready           => dma_axil_reg_slave.awready,    
  dma_reg_wready            => dma_axil_reg_slave.wready,    
  dma_reg_bresp             => dma_axil_reg_slave.bresp,  
  dma_reg_bvalid            => dma_axil_reg_slave.bvalid,    
  dma_reg_arready           => dma_axil_reg_slave.arready,    
  dma_reg_rdata             => dma_axil_reg_slave.rdata,  
  dma_reg_rresp             => dma_axil_reg_slave.rresp,  
  dma_reg_rvalid            => dma_axil_reg_slave.rvalid,

  top_reg_awaddr            => top_reg_axil_master.awaddr,    
  top_reg_awprot            => top_reg_axil_master.awprot,    
  top_reg_awvalid           => top_reg_axil_master.awvalid,    
  top_reg_wdata             => top_reg_axil_master.wdata,  
  top_reg_wstrb             => top_reg_axil_master.wstrb,  
  top_reg_wvalid            => top_reg_axil_master.wvalid,    
  top_reg_bready            => top_reg_axil_master.bready,    
  top_reg_araddr            => top_reg_axil_master.araddr,    
  top_reg_arprot            => top_reg_axil_master.arprot,    
  top_reg_arvalid           => top_reg_axil_master.arvalid,    
  top_reg_rready            => top_reg_axil_master.rready,
   
  top_reg_awready           => top_reg_axil_slave.awready,    
  top_reg_wready            => top_reg_axil_slave.wready,    
  top_reg_bresp             => top_reg_axil_slave.bresp,  
  top_reg_bvalid            => top_reg_axil_slave.bvalid,    
  top_reg_arready           => top_reg_axil_slave.arready,    
  top_reg_rdata             => top_reg_axil_slave.rdata,  
  top_reg_rresp             => top_reg_axil_slave.rresp,  
  top_reg_rvalid            => top_reg_axil_slave.rvalid,

  M_AXIS_MM2S_STS_0_tdata   => dma_interface_master.mm2s_sts_tdata,    
  M_AXIS_MM2S_STS_0_tkeep   => open,    
  M_AXIS_MM2S_STS_0_tlast   => dma_interface_master.mm2s_sts_tlast,    
  M_AXIS_MM2S_STS_0_tready  => dma_interface_slave.mm2s_sts_tready,      
  M_AXIS_MM2S_STS_0_tvalid  => dma_interface_master.mm2s_sts_tvalid,      
  M_AXIS_S2MM_STS_0_tdata   => dma_interface_master.s2mm_sts_tdata,    
  M_AXIS_S2MM_STS_0_tkeep   => open,    
  M_AXIS_S2MM_STS_0_tlast   => dma_interface_master.s2mm_sts_tlast,    
  M_AXIS_S2MM_STS_0_tready  => dma_interface_slave.s2mm_sts_tready,      
  M_AXIS_S2MM_STS_0_tvalid  => dma_interface_master.s2mm_sts_tvalid,      

  M_AXIS_MM2S_0_tdata       => dma_interface_master.axis_mm2s_tdata,
  M_AXIS_MM2S_0_tkeep       => open,
  M_AXIS_MM2S_0_tlast       => dma_interface_master.axis_mm2s_tlast,
  M_AXIS_MM2S_0_tready      => dma_interface_slave.axis_mm2s_tready,  
  M_AXIS_MM2S_0_tvalid      => dma_interface_master.axis_mm2s_tvalid,    
  S_AXIS_MM2S_CMD_0_tdata   => dma_interface_slave.mm2s_cmd_tdata,    
  S_AXIS_MM2S_CMD_0_tready  => dma_interface_master.mm2s_cmd_tready,      
  S_AXIS_MM2S_CMD_0_tvalid  => dma_interface_slave.mm2s_cmd_tvalid,      
  S_AXIS_S2MM_0_tdata       => dma_interface_slave.axis_s2mm_tdata,
  S_AXIS_S2MM_0_tkeep       => (others => '1'),
  S_AXIS_S2MM_0_tlast       => dma_interface_slave.axis_s2mm_tlast,
  S_AXIS_S2MM_0_tready      => dma_interface_master.axis_s2mm_tready,  
  S_AXIS_S2MM_0_tvalid      => dma_interface_slave.axis_s2mm_tvalid,  
  S_AXIS_S2MM_CMD_0_tdata   => dma_interface_slave.s2mm_cmd_tdata,    
  S_AXIS_S2MM_CMD_0_tready  => dma_interface_master.s2mm_cmd_tready,      
  S_AXIS_S2MM_CMD_0_tvalid  => dma_interface_slave.s2mm_cmd_tvalid

);

process(adc_clk)
begin
 if rising_edge(adc_clk) then 
    dma_controller_s_tdata(15 downto 0) <= adc_data_i0;
    dma_controller_s_tdata(31 downto 16) <= adc_data_q0;
    dma_controller_s_tdata(47 downto 32) <= adc_data_i1;
    dma_controller_s_tdata(63 downto 48) <= adc_data_q1;
    dma_controller_s_tvalid <= adc_valid;
 end if;
end process;

i_top_reg : entity work.axi_registers
generic map (
  AXIL_BASE_ADDRESS   => TOP_REG_BASE_ADDRESS,
  NUMBER_OF_REGISTERS => TOP_REG_NUMBER_OF_REG,
  WRITE_MASK          => TOP_REG_WRITE_MASK
)
port map(
  clk_i             => adc_clk,
  reset_i           => '0',
  axil_master_i     => top_reg_axil_master,
  axil_slave_o      => top_reg_axil_slave,
  read_reg_i        => top_reg_rd,
  write_reg_o       => top_reg_wr
);

process(adc_clk)
begin
 if rising_edge(adc_clk) then 
  dac_valid <= adc_valid;
  if top_reg_wr(TOP_REG_USE_TEST_DATA_IDX)(0) = '1' then 
    dac_valid <= adc_valid;
    dac_data_i0 <= top_reg_wr(TOP_REG_I_TEST_DATA_IDX)(15 downto 0);
    dac_data_q0 <= top_reg_wr(TOP_REG_Q_TEST_DATA_IDX)(15 downto 0);
    dac_data_i1 <= top_reg_wr(TOP_REG_I_TEST_DATA_IDX)(15 downto 0);
    dac_data_q1 <= top_reg_wr(TOP_REG_Q_TEST_DATA_IDX)(15 downto 0);
  end if;
 end if;
end process;

i_axi_dma_interface : entity work.axi_dma_interface
generic map (
  AXIL_REG_BASE_ADDRESS => x"43C10000", 
  NUM_OF_WORDS_WIDTH   => DMA_NUM_OF_WORDS_WIDTH
)
port map(
  clk_i                => adc_clk,
  reset_i              => '0',

  data_m_tdata_o       => dma_controller_m_tdata,
  data_m_tvalid_o      => dma_controller_m_tvalid,
  data_m_tready_i      => dma_controller_m_tready,
  data_m_tlast_o       => dma_controller_m_tlast,
  data_s_tdata_i       => dma_controller_s_tdata,
  data_s_tvalid_i      => dma_controller_s_tvalid,
  data_s_tready_o      => dma_controller_s_tready,
  data_s_tlast_i       => dma_controller_s_tlast,

  dma_interface_master_i   => dma_interface_master,
  dma_interface_slave_o    => dma_interface_slave,
  axil_reg_master_i        => dma_axil_reg_master,
  axil_reg_slave_o         => dma_axil_reg_slave
);


end Behavioral;