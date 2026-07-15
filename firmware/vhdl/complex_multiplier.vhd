
library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;


entity complex_multiplier is
  generic (
    A_WIDTH : natural := 16;
    B_WIDTH : natural := 16
  );
  port (
    clk_i           : in std_logic;
    reset_i         : in std_logic;
    clk_en_i        : in std_logic:= '1';
    src_a_r_tdata_i     : in signed(A_WIDTH - 1 downto 0);
    src_a_i_tdata_i     : in signed(A_WIDTH - 1 downto 0);
    src_b_r_tdata_i     : in signed(B_WIDTH - 1 downto 0);
    src_b_i_tdata_i     : in signed(B_WIDTH - 1 downto 0);
    src_tvalid_i        : in std_logic;
    src_tready_o        : out std_logic;
    dst_r_tdata_o       : out signed(A_WIDTH + B_WIDTH - 1 downto 0); 
    dst_i_tdata_o       : out signed(A_WIDTH + B_WIDTH - 1 downto 0);
    dst_tvalid_o        : out std_logic;
    dst_tready_i        : out std_logic
    
  );
end entity;


architecture Behavioral of complex_multiplier is

signal dst_tvalid     : std_logic;
signal data_valid     : std_logic;
signal src_tready     : std_logic;
signal mult_ar_br     : signed(A_WIDTH + B_WIDTH - 1 downto 0);
signal mult_ar_bi     : signed(A_WIDTH + B_WIDTH - 1 downto 0);
signal mult_ai_br     : signed(A_WIDTH + B_WIDTH - 1 downto 0);
signal mult_ai_bi     : signed(A_WIDTH + B_WIDTH - 1 downto 0);
signal dst_real_reg   : signed(A_WIDTH + B_WIDTH - 1 downto 0);
signal dst_imag_reg   : signed(A_WIDTH + B_WIDTH - 1 downto 0);

begin

  dst_r_tdata_o <= dst_real_reg;
  dst_i_tdata_o <= dst_imag_reg;
  src_tready    <= '0' when (dst_tvalid and (not dst_tready_i)) else '1';
  src_tready_o  <= src_tready;
  dst_tvalid_o  <= dst_tvalid;
  process(clk_i)
  begin
    if rising_edge(clk_i) then

      if dst_tready_i = '1' then
        dst_tvalid  <= '0';
      end if;

      if src_tready = '1' and src_tvalid_i = '1' then
        mult_ar_br     <= src_a_r_tdata_i * src_b_r_tdata_i;
        mult_ar_bi     <= src_a_r_tdata_i * src_b_i_tdata_i;
        mult_ai_br     <= src_a_i_tdata_i * src_b_r_tdata_i;
        mult_ai_bi     <= src_a_i_tdata_i * src_b_i_tdata_i;
      end if;

      if data_valid  = '1' then 
        if dst_tvalid = '0' or dst_tready_i = '1' then
          dst_real_reg <= mult_ar_br - mult_ai_bi;
          dst_imag_reg <= mult_ar_bi + mult_ai_br;
          data_valid <= '0';
        end if;
        dst_tvalid   <= '1';
      end if;

      if src_tready = '1' and src_tvalid_i = '1' then
        data_valid <= '1';
      end if;

    end if;
  end process;
end Behavioral;