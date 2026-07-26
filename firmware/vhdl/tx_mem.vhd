
library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use work.array_types.all;
use work.basic_pkg.all;

entity tx_mem is
  generic (
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
    dst_next_i      : in std_logic;
    
    mode_i          : in std_logic; -- Mode : 0, play once. Mode 1 : play repeatedly
    mem_high_addr_i : in unsigned(ceil_log2(MEM_DEPTH) - 1 downto 0);
    load_data_i     : in std_logic;
    play_data_i     : in std_logic

  );
end entity;

architecture Behavioral of tx_mem is
type tx_mem_state_t is (IDLE, LOAD_DATA,PLAY_DATA,DONE);
signal tx_mem_state_sm : tx_mem_state_t; 
signal src_data         : std_logic_vector(DATA_W - 1 downto 0);
signal src_valid        : std_logic := '0';  
signal src_ready        : std_logic := '0';
signal load_data_reg    : std_logic := '0';  
signal play_data_reg    : std_logic := '0';  
signal load_data_prev   : std_logic := '0';      
signal play_data_prev   : std_logic := '0';      
signal load_data_start  : std_logic := '0';
signal play_data_start  : std_logic := '0';
signal dst_next         : std_logic := '0';
signal dst_data_z0      : std_logic_vector(DATA_W - 1 downto 0);
signal dst_valid_z0     : std_logic := '0';
signal dst_data_z1      : std_logic_vector(DATA_W - 1 downto 0);
signal dst_valid_z1     : std_logic := '0';
signal mode             : std_logic := '0';
signal mem_addr         : unsigned(ceil_log2(MEM_DEPTH) - 1 downto 0);
signal mem_high_addr    : unsigned(ceil_log2(MEM_DEPTH) - 1 downto 0);
signal mem_high_addr_reg : unsigned(ceil_log2(MEM_DEPTH) - 1 downto 0);
signal mem              : array_slv_t(0 to MEM_DEPTH - 1)(DATA_W - 1 downto 0);

attribute ram_style : string;
attribute ram_style of mem : signal is "block";

attribute mark_debug : string;
attribute mark_debug of mode            : signal is "true";
attribute mark_debug of src_data        : signal is "true";
attribute mark_debug of src_valid       : signal is "true";
attribute mark_debug of src_ready       : signal is "true";
attribute mark_debug of tx_mem_state_sm : signal is "true";
attribute mark_debug of mem_addr        : signal is "true";
attribute mark_debug of mem_high_addr   : signal is "true";
attribute mark_debug of dst_next   : signal is "true";
begin 

  dst_data_o  <= dst_data_z1;   
  dst_valid_o <= dst_valid_z1;
  src_ready_o <= src_ready;
  
  process(clk_i)
  begin
    if rising_edge(clk_i) then 
      dst_valid_z0   <= '0';
      mode           <= mode_i;
      src_data       <= src_data_i;
      src_valid      <= src_valid_i;
      load_data_reg  <= load_data_i;
      play_data_reg  <= play_data_i;
      load_data_prev <= load_data_reg;
      play_data_prev <= play_data_reg;
      mem_high_addr  <= mem_high_addr_i;
      dst_next       <= dst_next_i;
      
      if load_data_reg = '1' and load_data_prev = '0' then 
        load_data_start <= '1';
      end if;
      if play_data_reg = '1' and play_data_prev = '0' then 
        play_data_start <= '1';
      end if;

      case tx_mem_state_sm is 

        when IDLE =>
        
        mem_high_addr_reg <= mem_high_addr;  
        mem_addr  <= (others=>'0');

        if play_data_start = '1' then 
          tx_mem_state_sm <= PLAY_DATA;  
        end if;
        if load_data_start = '1' then 
          tx_mem_state_sm <= LOAD_DATA;  
        end if;
        
        when LOAD_DATA =>

        load_data_start <= '0';
        src_ready <= '1';
        
        if (src_ready = '1' and src_valid = '1') then 
          mem(to_integer(mem_addr)) <= src_data;
          mem_addr <= mem_addr + 1;
          
          if (mem_addr = mem_high_addr_reg) then 
            tx_mem_state_sm <= DONE;
            src_ready <= '0';
          end if;

        end if;

        when PLAY_DATA =>

          play_data_start <= '0';

          if dst_next = '1' then 
            dst_data_z0  <= mem(to_integer(mem_addr));
            dst_valid_z0 <= '1';
            mem_addr     <= mem_addr + 1;

            if (mem_addr = mem_high_addr_reg) then 
              if mode = '1' then 
                mem_addr <= (others=>'0');
              elsif mode = '0' then
                tx_mem_state_sm <= DONE;
              end if;
            end if;

          end if;

          if load_data_start = '1' then 
            tx_mem_state_sm <= IDLE;
          end if;
        
        when DONE =>

        tx_mem_state_sm <= IDLE;

      end case;

      dst_data_z1  <= dst_data_z0;
      dst_valid_z1 <= dst_valid_z0;

      if reset_i = '1' then 
        tx_mem_state_sm <= IDLE;
      end if;
    end if;
  end process;
end Behavioral;
