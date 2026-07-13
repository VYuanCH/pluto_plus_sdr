library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library xpm;
use xpm.vcomponents.all;
--use work.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use work.array_types.all;

entity ad9361_2r2t_ddr_fdd_lvds is
  Port ( 
    rx_clk_in_n       : in STD_LOGIC;
    rx_clk_in_p       : in STD_LOGIC;
    rx_data_in_n      : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rx_data_in_p      : in STD_LOGIC_VECTOR ( 5 downto 0 );
    rx_frame_in_n     : in STD_LOGIC;
    rx_frame_in_p     : in STD_LOGIC;
    tx_clk_out_n      : out STD_LOGIC;
    tx_clk_out_p      : out STD_LOGIC;
    tx_data_out_n     : out STD_LOGIC_VECTOR ( 5 downto 0 );
    tx_data_out_p     : out STD_LOGIC_VECTOR ( 5 downto 0 );
    tx_frame_out_n    : out STD_LOGIC;
    tx_frame_out_p    : out STD_LOGIC;    

    adc_clk_o         : out STD_LOGIC;    
    data_valid_o      : out std_logic;
    adc_data_ch0_r_o  : out signed(15 downto 0);
    adc_data_ch0_i_o  : out signed(15 downto 0);
    adc_data_ch1_r_o  : out signed(15 downto 0);
    adc_data_ch1_i_o  : out signed(15 downto 0);
    
    data_valid_i      : in std_logic;
    dac_data_ch0_r_i  : in signed(15 downto 0);
    dac_data_ch0_i_i  : in signed(15 downto 0);
    dac_data_ch1_r_i  : in signed(15 downto 0);
    dac_data_ch1_i_i  : in signed(15 downto 0)
    
  );
end ad9361_2r2t_ddr_fdd_lvds;

architecture Behavioral of ad9361_2r2t_ddr_fdd_lvds is

type data_deserialise_t is (IDLE,RST,SYNC,S0,S1,S2,S3);
type data_serialise_t is (IDLE,RST,SYNC,S0,S1,S2,S3);
signal rx_clk           : std_logic;      
signal tx_frame_pos     : std_logic;
signal tx_frame_neg     : std_logic;
signal tx_data_pos      : std_logic_vector(5 downto 0);
signal tx_data_neg      : std_logic_vector(5 downto 0);
signal rx_frame_pos     : std_logic;
signal rx_frame_neg     : std_logic;
signal rx_data_pos      : std_logic_vector(5 downto 0);
signal rx_data_neg      : std_logic_vector(5 downto 0);
signal frame_reg        : std_logic_vector(7 downto 0);
signal rx_data_pos_reg  : std_logic_vector(5 downto 0);
signal rx_data_neg_reg  : std_logic_vector(5 downto 0);
signal data_valid       : std_logic;
signal data_valid_reg   : std_logic;
signal data_valid_reg0  : std_logic;
signal tx_data_valid    : std_logic;
signal T1_I             : std_logic_vector(11 downto 0);
signal T1_Q             : std_logic_vector(11 downto 0);
signal T2_I             : std_logic_vector(11 downto 0);
signal T2_Q             : std_logic_vector(11 downto 0);
signal R1_I             : std_logic_vector(11 downto 0);
signal R1_Q             : std_logic_vector(11 downto 0);
signal R2_I             : std_logic_vector(11 downto 0);
signal R2_Q             : std_logic_vector(11 downto 0);
signal adc_reg_ch0_i    : std_logic_vector(11 downto 0);
signal adc_reg_ch0_q    : std_logic_vector(11 downto 0);
signal adc_reg_ch1_i    : std_logic_vector(11 downto 0);
signal adc_reg_ch1_q    : std_logic_vector(11 downto 0);
signal adc_reg_ch0_i_0  : std_logic_vector(15 downto 0);
signal adc_reg_ch0_q_0  : std_logic_vector(15 downto 0);
signal adc_reg_ch1_i_0  : std_logic_vector(15 downto 0);
signal adc_reg_ch1_q_0  : std_logic_vector(15 downto 0);
signal data_deserial_sm : data_deserialise_t;
signal data_serial_sm   : data_serialise_t;

begin

  i_ad9361_lvds_ddr_io : entity work.ad9361_lvds_ddr_io
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
    rx_clk_o         => rx_clk, 
    rx_data_pos_o    => rx_data_pos,     
    rx_data_neg_o    => rx_data_neg,     
    rx_frame_pos_o   => rx_frame_pos,       
    rx_frame_neg_o   => rx_frame_neg,       
    tx_clk_i         => rx_clk,     -- Use Rx clock to drive Tx
    tx_data_pos_i    => tx_data_pos,     
    tx_data_neg_i    => tx_data_neg,     
    tx_frame_pos_i   => tx_frame_pos,       
    tx_frame_neg_i   => tx_frame_neg      
  );

  -- Rx serial to Parallel
  process(rx_clk)
  begin 
    if rising_edge(rx_clk) then 
      frame_reg(0) <= rx_frame_neg;
      frame_reg(1) <= rx_frame_pos;
      frame_reg(7 downto 2) <= frame_reg(5 downto 0);
      rx_data_pos_reg <= rx_data_pos;
      rx_data_neg_reg <= rx_data_neg;
      data_valid <= '0';

      case data_deserial_sm is 
        when IDLE =>
          data_deserial_sm <= SYNC;
        when RST =>
          data_deserial_sm <= IDLE;
        when SYNC =>
          if frame_reg = "11110000" then 
            data_deserial_sm <= S0;
          end if;
        when S0 =>
          R1_I(11 downto 6) <= rx_data_pos_reg;
          R1_Q(11 downto 6) <= rx_data_neg_reg;
          data_deserial_sm  <= S1;
        when S1 =>
          R1_I(5 downto 0) <= rx_data_pos_reg;
          R1_Q(5 downto 0) <= rx_data_neg_reg;
          data_deserial_sm  <= S2;
        when S2 =>
          R2_I(11 downto 6) <= rx_data_pos_reg;
          R2_Q(11 downto 6) <= rx_data_neg_reg;
          data_deserial_sm  <= S3;
        when S3 =>
          R2_I(5 downto 0) <= rx_data_pos_reg;
          R2_Q(5 downto 0) <= rx_data_neg_reg;
          if frame_reg = "11110000" then 
            data_deserial_sm  <= S0;
            data_valid <= '1';
          end if;
        when others => 
          data_deserial_sm <= IDLE;
      end case;
      if data_valid = '1' then 
        adc_reg_ch0_i <= R1_I;
        adc_reg_ch0_q <= R1_Q;
        adc_reg_ch1_i <= R2_I;
        adc_reg_ch1_q <= R2_Q;
      end if;
      data_valid_reg <= data_valid;
    end if;
  end process;
  -- Tx Parallel to Serial
  process(rx_clk)
  begin 
    if rising_edge(rx_clk) then 
      case data_serial_sm is 
        when IDLE =>
          data_serial_sm <= SYNC;
        when RST =>
          data_serial_sm <= IDLE;
        when SYNC =>
            if data_valid_i = '1' then 
              data_serial_sm <= S0;
            end if;
        when S0 =>
          tx_data_pos <= T1_I(11 downto 6);
          tx_data_neg <= T1_Q(11 downto 6);
          tx_frame_pos <= '0';
          tx_frame_neg <= '0';
          data_serial_sm  <= S1;
        when S1 =>
          tx_data_pos <= T1_I(5 downto 0);
          tx_data_neg <= T1_Q(5 downto 0);
          tx_frame_pos <= '0';
          tx_frame_neg <= '0';
          data_serial_sm  <= S2;
        when S2 =>
          tx_data_pos <= T2_I(11 downto 6);
          tx_data_neg <= T2_Q(11 downto 6);
          tx_frame_pos <= '1';
          tx_frame_neg <= '1';
          data_serial_sm  <= S3;
        when S3 =>
          tx_data_pos <= T2_I(5 downto 0);
          tx_data_neg <= T2_Q(5 downto 0);
          tx_frame_pos <= '1';
          tx_frame_neg <= '1';
          data_serial_sm  <= S0;
        when others => 
          data_serial_sm <= IDLE;
      end case;
    end if;
  end process;

  adc_clk_o <= rx_clk;
  --Register Input/Output
  process(rx_clk)
  begin 
    if rising_edge(rx_clk) then
      if data_valid_i = '1' then 
        T1_I  <= std_logic_vector(dac_data_ch0_r_i(11 downto 0));
        T1_Q  <= std_logic_vector(dac_data_ch0_i_i(11 downto 0));
        T2_I  <= std_logic_vector(dac_data_ch1_r_i(11 downto 0));
        T2_Q  <= std_logic_vector(dac_data_ch1_i_i(11 downto 0));
      end if;
      tx_data_valid <= data_valid_i;
      -- Sign Extend to 16 bits
      adc_reg_ch0_i_0 (11 downto 0)  <= adc_reg_ch0_i;
      adc_reg_ch0_i_0 (15 downto 12) <= (others => adc_reg_ch0_i(11));
      adc_reg_ch0_q_0 (11 downto 0)  <= adc_reg_ch0_q;
      adc_reg_ch0_q_0 (15 downto 12) <= (others => adc_reg_ch0_q(11));
      adc_reg_ch1_i_0 (11 downto 0)  <= adc_reg_ch1_i;
      adc_reg_ch1_i_0 (15 downto 12) <= (others => adc_reg_ch1_i(11));
      adc_reg_ch1_q_0 (11 downto 0)  <= adc_reg_ch1_q;
      adc_reg_ch1_q_0 (15 downto 12) <= (others => adc_reg_ch1_q(11));

      adc_data_ch0_r_o <= signed(adc_reg_ch0_i_0);
      adc_data_ch0_i_o <= signed(adc_reg_ch0_q_0);
      adc_data_ch1_r_o <= signed(adc_reg_ch1_i_0);
      adc_data_ch1_i_o <= signed(adc_reg_ch1_q_0); 

      data_valid_reg0 <= data_valid_reg;
      data_valid_o <= data_valid_reg0;


    end if;
  end process;


end Behavioral;