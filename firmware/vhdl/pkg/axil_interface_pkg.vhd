
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



package axil_interface_pkg is
    constant AXIL_ADDR_W     : natural := 32;
    constant AXIL_DATA_W     : natural := 32;
    constant AXIL_PROT_W     : natural := 3;
    constant AXIL_STRB_W     : natural := 4;
    constant AXIL_RESP_W     : natural := 2;

    type axil_master_t is record
        -- Write address channel
        awaddr   : std_logic_vector(AXIL_ADDR_W - 1 downto 0);
        awprot   : std_logic_vector(AXIL_PROT_W - 1 downto 0);
        awvalid  : std_logic;
        -- Write data channel
        wdata    : std_logic_vector(AXIL_DATA_W - 1 downto 0);
        wstrb    : std_logic_vector(AXIL_STRB_W - 1 downto 0);
        wvalid   : std_logic;
        -- Write Response Channel
        bready   : std_logic;
        -- Read Address channel
        araddr   : std_logic_vector(AXIL_ADDR_W - 1 downto 0);
        arprot   : std_logic_vector(AXIL_PROT_W - 1 downto 0);
        arvalid  : std_logic;
        -- Read Data channel
        rready   : std_logic;
    end record;
    
    type axil_slave_t is record
        -- Write Address Channel
        awready  : std_logic;
        -- Write Data Channel
        wready   : std_logic;
        -- Write Response Channel
        bresp    : std_logic_vector(AXIL_RESP_W - 1 downto 0);
        bvalid   : std_logic;
        -- Read Address Channel
        arready  : std_logic;
        -- Read Data Channel
        rdata    : std_logic_vector(AXIL_DATA_W - 1 downto 0);
        rresp    : std_logic_vector(AXIL_RESP_W - 1 downto 0);
        rvalid   : std_logic;
    end record;
end package;