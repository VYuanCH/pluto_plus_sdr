
library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;


entity smoothing_power_estimator is
  generic (
    SMOOTHING_FACTOR_W  : natural := 8;  
    DATA_W              : natural := 16
    );
  port (
    clk_i               : in std_logic;
    reset_i             : in std_logic;
    smoothing_factor_i  : in unsigned(SMOOTHING_FACTOR_W - 1 downto 0);
    src_data_r_i        : in signed(DATA_W - 1 downto 0);
    src_data_i_i        : in signed(DATA_W - 1 downto 0);  
    src_valid_i         : in std_logic;
    dst_data_o          : out unsigned(DATA_W*2 - 1 downto 0);  --Power should always be positive
    dst_valid_o         : out std_logic
  );
end entity;

architecture Behavioral of smoothing_power_estimator is
constant SMOOTHING_SCALING_FACTOR : natural := 2**SMOOTHING_FACTOR_W;

signal one_minus_sf         : unsigned(SMOOTHING_FACTOR_W downto 0);
signal smoothing_factor     : unsigned(SMOOTHING_FACTOR_W - 1 downto 0);
signal data_r               : signed(DATA_W - 1 downto 0);
signal data_i               : signed(DATA_W - 1 downto 0);
signal data_conj_r          : signed(DATA_W - 1 downto 0);      
signal data_conj_i          : signed(DATA_W - 1 downto 0);      
signal data_valid           : std_logic;
signal pow_r                : signed(DATA_W*2 - 1 downto 0);
signal pow_i                : signed(DATA_W*2 - 1 downto 0);
signal pow_valid            : std_logic;
signal pow_hist             : unsigned(SMOOTHING_FACTOR_W + DATA_W*2 downto 0);
signal pow_update           : unsigned(SMOOTHING_FACTOR_W + DATA_W*2 - 1 downto 0);    
signal smoothed_power       : unsigned(DATA_W*2  - 1 downto 0);
signal pow_valid_z1         : std_logic;
signal pow_valid_z2         : std_logic;
attribute mark_debug : string;
attribute mark_debug of pow_r       : signal is "true";
attribute mark_debug of pow_i       : signal is "true";
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then 
      one_minus_sf     <= unsigned(to_unsigned(SMOOTHING_SCALING_FACTOR,SMOOTHING_FACTOR_W + 1) - smoothing_factor_i);
      smoothing_factor <= smoothing_factor_i;
      data_r <= src_data_r_i;
      data_i <= src_data_i_i;

      data_conj_r <= src_data_r_i;
      data_conj_i <= (not src_data_i_i) + 1;

      data_valid  <= src_valid_i;

    end if;
  end process;
  
  i_complex_multiplier : entity work.complex_multiplier
  port map (
    clk_i              => clk_i,
    reset_i            => reset_i,
    clk_en_i           => '1',
    src_a_r_tdata_i    => data_r,           
    src_a_i_tdata_i    => data_i,           
    src_b_r_tdata_i    => data_conj_r,           
    src_b_i_tdata_i    => data_conj_i,           
    src_tvalid_i       => data_valid,         
    src_tready_o       => open,
    dst_r_tdata_o      => pow_r,    
    dst_i_tdata_o      => pow_i, -- Should always 0, but assign a signal so we could check in debug.    
    dst_tvalid_o       => pow_valid,
    dst_tready_i       => '1'
  );

  process(clk_i)
    variable smoothed_power_unscaled    : unsigned(SMOOTHING_FACTOR_W + DATA_W * 2 downto 0);
  begin
    if rising_edge(clk_i) then 
      if pow_valid = '1' then 
        pow_hist   <= smoothed_power*one_minus_sf;
        pow_update <= unsigned(pow_r)*smoothing_factor;
      end if; 

      smoothed_power_unscaled := pow_hist + pow_update; 
      smoothed_power <= smoothed_power_unscaled(smoothed_power_unscaled'high - 1 downto SMOOTHING_FACTOR_W);
      dst_data_o <= smoothed_power;
      pow_valid_z1 <= pow_valid; 
      pow_valid_z2 <= pow_valid_z1;
      dst_valid_o  <= pow_valid_z2;

    end if;
  end process;

  


end Behavioral;
