
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.axil_interface_pkg.all;
use work.array_types.all;
use work.basic_pkg.all;
use work.axi_datamover_pkg.all;
entity axi_datamover_controller is
  generic (
      NUM_OF_WORDS_WIDTH  : natural := 32
  );
  port (
    clk_i                : in std_logic;
    reset_i              : in std_logic;

    write_address_i      : in unsigned(ADDRESS_WIDTH - 1 downto 0);
    write_num_of_words_i : in unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);
    write_start_i        : in std_logic;
    read_address_i       : in unsigned(ADDRESS_WIDTH - 1 downto 0);
    read_num_of_words_i  : in unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);
    read_start_i         : in std_logic;
    repeated_read_i      : in std_logic;
    repeated_write_i     : in std_logic;

    data_m_tdata_o       : out std_logic_vector(MM2S_DATA_WIDTH - 1 downto 0);
    data_m_tvalid_o      : out std_logic;
    data_m_tready_i      : in  std_logic;
    data_m_tlast_o       : out std_logic;
    data_s_tdata_i       : in  std_logic_vector(S2MM_DATA_WIDTH - 1 downto 0);
    data_s_tvalid_i      : in  std_logic;
    data_s_tready_o      : out std_logic; -- Usually this is an output, but in this case the axi datamover controller only monitors the master channel of datamover, the slave module receiving the data should assign the tready.
    data_s_tlast_i       : in  std_logic;
    
    -- Axi Datamover interface
    -- axi_datamover axis interface
    axis_s2mm_tdata_o       : out std_logic_vector(S2MM_DATA_WIDTH - 1 downto 0);
    axis_s2mm_tvalid_o      : out std_logic;
    axis_s2mm_tready_i      : in  std_logic;
    axis_s2mm_tlast_o       : out std_logic;
    axis_mm2s_tdata_i       : in  std_logic_vector(MM2S_DATA_WIDTH - 1 downto 0);
    axis_mm2s_tvalid_i      : in  std_logic;
    axis_mm2s_tready_o      : out std_logic; -- Usually this is an output, but in this case the axi datamover controller only monitors the master channel of datamover, the slave module receiving the data should assign the tready.
    axis_mm2s_tlast_i       : in  std_logic;
    
    -- axi_datamover cmd interface
    mm2s_cmd_m_tdata_o   : out std_logic_vector(MM2S_CMD_WIDTH - 1 downto 0);
    mm2s_cmd_m_tvalid_o  : out std_logic;
    mm2s_cmd_m_tready_i  : in  std_logic;

    -- axi_datamover cmd interface
    s2mm_cmd_m_tdata_o   : out std_logic_vector(S2MM_CMD_WIDTH - 1 downto 0);
    s2mm_cmd_m_tvalid_o  : out std_logic;
    s2mm_cmd_m_tready_i  : in  std_logic;

    mm2s_sts_tdata_i     : in std_logic_vector(MM2S_STS_WIDTH - 1 downto 0);  
    mm2s_sts_tvalid_i    : in std_logic;
    mm2s_sts_tready_o    : out std_logic;   
    s2mm_sts_tdata_i     : in std_logic_vector(S2MM_STS_WIDTH - 1 downto 0); 
    s2mm_sts_tvalid_i    : in std_logic;   
    s2mm_sts_tready_o    : out std_logic     
    
  );
end entity;

architecture Behavioral of axi_datamover_controller is
  constant TRANSFER_SIZE_BYTES  : natural := 1024;
  constant ADDR_BYTES      : natural := ceil_divide(ADDRESS_WIDTH,8)*8;
  constant BYTES_EACH_WORD_READ  : natural := MM2S_DATA_WIDTH/8;
  constant BYTES_EACH_WORD_WRITE : natural := S2MM_DATA_WIDTH/8;
  constant READ_TRANSFER_SIZE_WORDS  : natural := TRANSFER_SIZE_BYTES/ BYTES_EACH_WORD_READ;
  constant WRITE_TRANSFER_SIZE_WORDS  : natural := TRANSFER_SIZE_BYTES / BYTES_EACH_WORD_WRITE;
  type datamover_read_t is (IDLE, INIT, SET_CMD,WAIT_CMD_READY,READ_DATA,WAIT_FOR_LAST_SAMPLE, WAIT_FOR_STS,DONE);
  signal datamover_read_sm : datamover_read_t := IDLE;

  type datamover_write_t is (IDLE, INIT, SET_CMD,WAIT_CMD_READY,WRITE_DATA,WAIT_FOR_LAST_SAMPLE, WAIT_FOR_STS,DONE);
  signal datamover_write_sm : datamover_write_t := IDLE;
  signal read_prev : std_logic;

  signal last_read_transfer         : std_logic;   
  signal read_address_reg           : unsigned(ADDRESS_WIDTH - 1 downto 0); 
  signal read_num_of_words_reg      : unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);       
  signal read_bytes_remain          : unsigned(NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_READ) downto 0);       
  signal read_bytes_counter         : unsigned(NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_READ) downto 0);      


  signal write_prev                 : std_logic;
  signal last_write_transfer        : std_logic;          
  signal write_address_reg          : unsigned(ADDRESS_WIDTH - 1 downto 0);        
  signal write_num_of_words_reg     : unsigned(NUM_OF_WORDS_WIDTH - 1 downto 0);        
  signal write_bytes_remain         : unsigned(NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_WRITE) downto 0);        
  signal write_bytes_counter        : unsigned(NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_WRITE) downto 0); 
  signal write_enable               : std_logic := '0';
  signal repeated_read              : std_logic := '0';
  signal repeated_write             : std_logic := '0';
attribute mark_debug : string;
attribute mark_debug of datamover_read_sm : signal is "true";
attribute mark_debug of datamover_write_sm : signal is "true";
attribute mark_debug of read_bytes_counter : signal is "true";
begin

  data_s_tready_o <= axis_s2mm_tready_i and write_enable;
  axis_mm2s_tready_o <= data_m_tready_i;

  data_m_tdata_o <= axis_mm2s_tdata_i;
  data_m_tvalid_o <= axis_mm2s_tvalid_i;
  
  axis_s2mm_tdata_o <= data_s_tdata_i;
  axis_s2mm_tvalid_o <= data_s_tvalid_i and write_enable;
  
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      read_prev     <= read_start_i;
      repeated_read <= repeated_read_i;
      case datamover_read_sm is 
        when IDLE =>
        last_read_transfer <= '0'; 
          if read_start_i = '1' and read_prev = '0' then
            read_num_of_words_reg <= read_num_of_words_i;
            datamover_read_sm <= INIT;
          end if;
        when INIT =>
          read_address_reg      <= read_address_i;
          read_bytes_remain <= to_unsigned(BYTES_EACH_WORD_READ,ceil_log2(BYTES_EACH_WORD_READ)+1) * read_num_of_words_reg;
          datamover_read_sm <= SET_CMD;
        when SET_CMD => -- Axi datamover should be in full mode. 
          mm2s_cmd_m_tdata_o(22 downto MM2S_BTT_WIDTH)    <= (others =>'0');
          if read_bytes_remain > TRANSFER_SIZE_BYTES then
            mm2s_cmd_m_tdata_o(MM2S_BTT_WIDTH - 1 downto 0) <= std_logic_vector(to_unsigned(TRANSFER_SIZE_BYTES,MM2S_BTT_WIDTH));
            read_bytes_counter <= to_unsigned(TRANSFER_SIZE_BYTES - BYTES_EACH_WORD_READ,NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_READ)+1);
          else 
            mm2s_cmd_m_tdata_o(MM2S_BTT_WIDTH - 1 downto 0) <= std_logic_vector(read_bytes_remain(MM2S_BTT_WIDTH - 1 downto 0));
            read_bytes_counter <= read_bytes_remain - BYTES_EACH_WORD_READ;
            last_read_transfer <= '1';
          end if;
          mm2s_cmd_m_tdata_o(23)           <= '1';
          mm2s_cmd_m_tdata_o(29 downto 24) <= (others => '0');
          mm2s_cmd_m_tdata_o(30)           <= '1'; --EOF
          mm2s_cmd_m_tdata_o(31)           <= '0';
          mm2s_cmd_m_tdata_o(ADDR_BYTES + 31 downto 32) <= std_logic_vector(resize(read_address_reg,ADDR_BYTES));
          mm2s_cmd_m_tdata_o(ADDR_BYTES + 35 downto ADDR_BYTES + 32) <= (others => '0');
          mm2s_cmd_m_tdata_o(ADDR_BYTES + 39 downto ADDR_BYTES + 36) <= (others => '0');
          mm2s_cmd_m_tvalid_o <= '1';
          datamover_read_sm <= WAIT_CMD_READY;

        when WAIT_CMD_READY =>
          if mm2s_cmd_m_tready_i = '1' then
            mm2s_cmd_m_tvalid_o <= '0';
            datamover_read_sm <= READ_DATA;
            if read_bytes_counter = 0 then -- Special case where there is only 1 word in this transfer
              data_m_tlast_o <= '1';
              datamover_read_sm <= WAIT_FOR_LAST_SAMPLE;
            end if;
          end if;
          
        when READ_DATA =>
          
          if axis_mm2s_tvalid_i = '1' and data_m_tready_i = '1' then 
            read_bytes_counter <= read_bytes_counter - BYTES_EACH_WORD_READ;
            if read_bytes_counter = BYTES_EACH_WORD_READ then
              datamover_read_sm <= WAIT_FOR_LAST_SAMPLE;
              if last_read_transfer = '1' then 
                data_m_tlast_o <= '1';
              end if;
            end if; 
          end if;

        when WAIT_FOR_LAST_SAMPLE =>
          if axis_mm2s_tvalid_i = '1' and data_m_tready_i = '1' then
            data_m_tlast_o <= '0';
            datamover_read_sm <= WAIT_FOR_STS;
          end if;

        when WAIT_FOR_STS =>
            if last_read_transfer = '1' then
              datamover_read_sm <= DONE;
            else
              read_address_reg  <= read_address_reg + TRANSFER_SIZE_BYTES;
              read_bytes_remain <= read_bytes_remain - TRANSFER_SIZE_BYTES;
              datamover_read_sm <= SET_CMD;
            end if;

        when DONE =>
          if repeated_read = '1' then 
            datamover_read_sm <= INIT;
            last_read_transfer <= '0'; 
          else
            datamover_read_sm <= IDLE;
          end if;
      end case;
    end if;
  end process;


  process(clk_i)
  begin
    if rising_edge(clk_i) then
      write_prev     <= write_start_i;
      repeated_write <= repeated_write_i;
      case datamover_write_sm is 

        when IDLE =>
        write_enable <= '0';
        last_write_transfer <= '0'; 
          if write_start_i = '1' and write_prev = '0' then
            write_num_of_words_reg <= write_num_of_words_i;
            datamover_write_sm <= INIT;
          end if;

        when INIT =>
          write_address_reg      <= write_address_i;
          write_bytes_remain <= to_unsigned(BYTES_EACH_WORD_WRITE,ceil_log2(BYTES_EACH_WORD_WRITE)+1) * write_num_of_words_reg;
          datamover_write_sm <= SET_CMD;

        when SET_CMD => -- Axi datamover should be in full mode.
          s2mm_cmd_m_tdata_o(22 downto S2MM_BTT_WIDTH)    <= (others =>'0');
          datamover_write_sm <= WAIT_CMD_READY;
          if write_bytes_remain > TRANSFER_SIZE_BYTES then
            s2mm_cmd_m_tdata_o(S2MM_BTT_WIDTH - 1 downto 0) <= std_logic_vector(to_unsigned(TRANSFER_SIZE_BYTES,S2MM_BTT_WIDTH));
            write_bytes_counter <= to_unsigned(TRANSFER_SIZE_BYTES - BYTES_EACH_WORD_WRITE,NUM_OF_WORDS_WIDTH + ceil_log2(BYTES_EACH_WORD_WRITE)+1);
          else 
            s2mm_cmd_m_tdata_o(S2MM_BTT_WIDTH - 1 downto 0) <= std_logic_vector(write_bytes_remain(S2MM_BTT_WIDTH - 1 downto 0));
            write_bytes_counter <= write_bytes_remain - BYTES_EACH_WORD_WRITE;
            last_write_transfer <= '1';
          end if;
          s2mm_cmd_m_tdata_o(23)           <= '1';
          s2mm_cmd_m_tdata_o(29 downto 24) <= (others => '0');
          s2mm_cmd_m_tdata_o(30)           <= '1'; --EOF
          s2mm_cmd_m_tdata_o(31)           <= '0';
          s2mm_cmd_m_tdata_o(ADDR_BYTES + 31 downto 32) <= std_logic_vector(resize(write_address_reg,ADDR_BYTES));
          s2mm_cmd_m_tdata_o(ADDR_BYTES + 35 downto ADDR_BYTES + 32) <= (others => '0');
          s2mm_cmd_m_tdata_o(ADDR_BYTES + 39 downto ADDR_BYTES + 36) <= (others => '0');
          s2mm_cmd_m_tvalid_o <= '1';
          
        when WAIT_CMD_READY =>
          if s2mm_cmd_m_tready_i = '1' then
            s2mm_cmd_m_tvalid_o <= '0';
            datamover_write_sm <= WRITE_DATA;
            write_enable <= '1';
            if write_bytes_counter = 0 then -- Special case where there is only 1 words to write
              datamover_write_sm <= WAIT_FOR_LAST_SAMPLE;
              axis_s2mm_tlast_o <= '1';
            end if;
          end if;
          
        when WRITE_DATA =>
          
          if axis_s2mm_tready_i = '1' and data_s_tvalid_i = '1' then 
            write_bytes_counter <= write_bytes_counter - BYTES_EACH_WORD_WRITE;
            if write_bytes_counter = BYTES_EACH_WORD_WRITE then
              datamover_write_sm <= WAIT_FOR_LAST_SAMPLE;
              axis_s2mm_tlast_o <= '1';
            end if; 
          end if;

        when WAIT_FOR_LAST_SAMPLE =>
          if axis_s2mm_tready_i = '1' and data_s_tvalid_i = '1'  then
            axis_s2mm_tlast_o <= '0';
            write_enable <= '0';
            datamover_write_sm <= WAIT_FOR_STS;
          end if;

        when WAIT_FOR_STS => 
            if last_write_transfer = '1' then
              datamover_write_sm <= DONE;
            else
              write_address_reg  <= write_address_reg   + TRANSFER_SIZE_BYTES;
              write_bytes_remain <= write_bytes_remain - TRANSFER_SIZE_BYTES;
              datamover_write_sm <= SET_CMD;
            end if;
          --end if;
        when DONE =>
          if repeated_write = '1' then 
            datamover_write_sm <= INIT;
            last_write_transfer <= '0'; 
          else 
            datamover_write_sm <= IDLE;
          end if;
      end case;
    end if;
  end process;

  s2mm_sts_tready_o <= '1';
  mm2s_sts_tready_o <= '1';

end Behavioral;
