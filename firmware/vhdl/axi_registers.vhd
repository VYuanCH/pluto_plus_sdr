
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.axil_interface_pkg.all;
use work.array_types.all;
use work.basic_pkg.all;

entity axi_registers is
  generic (
    AXIL_BASE_ADDRESS    : UNSIGNED(AXIL_ADDR_W - 1 downto 0) := x"A0000000";
    NUMBER_OF_REGISTERS  : natural := 10;
    WRITE_MASK           : STD_LOGIC_VECTOR(NUMBER_OF_REGISTERS - 1 downto 0) := (others=>'1')
      
  );
  port (
    clk_i                : in std_logic;
    reset_i              : in std_logic;
    axil_master_i        : in axil_master_t;
    axil_slave_o         : out axil_slave_t;
    read_reg_i           : in array_slv_t(0 to NUMBER_OF_REGISTERS - 1)(AXIL_DATA_W - 1 downto 0);
    write_reg_o          : out array_slv_t(0 to NUMBER_OF_REGISTERS - 1)(AXIL_DATA_W - 1 downto 0)
        
  );
end entity;

architecture Behavioral of axi_registers is

type axil_transaction_t is (IDLE, READ, WRITE,WAIT_READ_READY, WAIT_WRITE_RESP, DONE);

constant BYTES_EACH_REG     : natural := 4;
constant BYTES_BITS_IN_ADDR : natural := ceil_log2(BYTES_EACH_REG);
constant AXIL_HIGH_ADDRESS  : UNSIGNED(AXIL_ADDR_W - 1 downto 0) := AXIL_BASE_ADDRESS + NUMBER_OF_REGISTERS*BYTES_EACH_REG; 

signal axil_transaction_sm  : axil_transaction_t := IDLE;
signal read_addr            : unsigned(AXIL_ADDR_W - 1 downto 0);
signal write_addr           : unsigned(AXIL_ADDR_W - 1 downto 0);
signal read_reg_idx         : unsigned(AXIL_ADDR_W - BYTES_BITS_IN_ADDR - 1 downto 0);
signal write_reg_idx        : unsigned(AXIL_ADDR_W - BYTES_BITS_IN_ADDR - 1 downto 0);
signal write_registers      : array_slv_t(0 to NUMBER_OF_REGISTERS - 1)(AXIL_DATA_W - 1 downto 0);

begin

  read_addr  <= unsigned(axil_master_i.araddr) - AXIL_BASE_ADDRESS;
  write_addr <= unsigned(axil_master_i.awaddr) - AXIL_BASE_ADDRESS;
  write_reg_o <= write_registers;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      case axil_transaction_sm is 

        when IDLE =>
          axil_slave_o.awready <= '1';
          axil_slave_o.arready <= '1';
          axil_slave_o.wready <= '0';
          if axil_master_i.arvalid = '1' and unsigned(axil_master_i.araddr) < AXIL_HIGH_ADDRESS and unsigned(axil_master_i.araddr) >= AXIL_BASE_ADDRESS then 
            axil_slave_o.arready <= '0';
            read_reg_idx         <= read_addr(read_addr'high downto 2);
            axil_transaction_sm  <= READ;
          end if;

          if axil_master_i.awvalid = '1' and unsigned(axil_master_i.awaddr) < AXIL_HIGH_ADDRESS and unsigned(axil_master_i.awaddr) >= AXIL_BASE_ADDRESS then 
            axil_slave_o.awready <= '0';
            axil_slave_o.wready  <= '1';
            write_reg_idx        <= write_addr(write_addr'high downto 2);
            axil_transaction_sm  <= WRITE;
          end if;
          
        when READ =>
          if WRITE_MASK(to_integer(read_reg_idx)) = '1' then
            axil_slave_o.rdata <= write_registers(to_integer(read_reg_idx));
          else
            axil_slave_o.rdata <= read_reg_i(to_integer(read_reg_idx));
          end if;
          axil_slave_o.rresp  <= (others => '0');
          axil_slave_o.rvalid <= '1';
          axil_transaction_sm  <= WAIT_READ_READY;

        when WAIT_READ_READY => 
          if axil_master_i.rready = '1' then 
            axil_slave_o.rvalid <= '0';
            axil_transaction_sm  <= DONE;
          end if;

        when WRITE => 
          if axil_master_i.wvalid = '1' then 
            axil_slave_o.wready <= '0';
            if WRITE_MASK(to_integer(write_reg_idx)) = '1' then
              write_registers(to_integer(write_reg_idx)) <= axil_master_i.wdata;
            end if;
            axil_slave_o.bresp  <= (others => '0');
            axil_slave_o.bvalid <= '1';
            axil_transaction_sm  <= WAIT_WRITE_RESP;
          end if;

        when WAIT_WRITE_RESP =>
          if axil_master_i.bready = '1' then 
            axil_slave_o.bvalid <= '0';
            axil_transaction_sm  <= DONE;
          end if;

        when DONE =>
          axil_slave_o.awready <= '1';
          axil_slave_o.arready <= '1';
          axil_slave_o.wready <= '0';
          axil_transaction_sm <= IDLE;
      end case;
      
    end if;
  end process;

end Behavioral;
