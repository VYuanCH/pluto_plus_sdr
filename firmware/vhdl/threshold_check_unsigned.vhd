

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity threshold_check_unsigned is
  generic (
    DATA_W              : natural := 32

    );
  port (
    clk_i               : in std_logic;
    reset_i             : in std_logic;
    data_i              : in unsigned(DATA_W - 1 downto 0);
    valid_i             : in std_logic;
    threshold_i         : in unsigned(DATA_W - 1 downto 0);
    clear_i             : in std_logic;
    threshold_reached_o : out std_logic
  );
end entity;

architecture Behavioral of threshold_check_unsigned is
signal data               : unsigned(DATA_W - 1 downto 0);
signal valid              : std_logic;
signal threshold_reached  : std_logic;

begin 
  
  process(clk_i)
  begin
    
    data    <= data_i;
    valid   <= valid_i;

    if clear_i = '1' or reset_i = '1' then 
      threshold_reached <= '0';
    end if;
    
    if valid = '1' and data > threshold_i then 
      threshold_reached <= '1';
    end if;

  end process;

  threshold_reached_o <= threshold_reached;

end Behavioral;
