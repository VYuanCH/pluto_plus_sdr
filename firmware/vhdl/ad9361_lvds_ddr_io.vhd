
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library xpm;
use xpm.vcomponents.all;
use IEEE.NUMERIC_STD.ALL;

entity ad9361_lvds_ddr_io is
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

    rx_clk_o          : out std_logic; --buffered rx clock
    rx_data_pos_o     : out std_logic_vector(5 downto 0); -- rx_data on positive edge
    rx_data_neg_o     : out std_logic_vector(5 downto 0); -- rx_data on negative edge
    rx_frame_pos_o    : out std_logic; -- rx_frame on positive edge
    rx_frame_neg_o    : out std_logic; -- rx_frame on negative edge
    tx_clk_i          : in  std_logic;
    tx_data_pos_i     : in  std_logic_vector(5 downto 0); -- tx_data on positive edge
    tx_data_neg_i     : in  std_logic_vector(5 downto 0); -- tx_data on negative edge
    tx_frame_pos_i    : in  std_logic;
    tx_frame_neg_i    : in  std_logic

  );
end ad9361_lvds_ddr_io;


architecture Behavioral of ad9361_lvds_ddr_io is

signal rx_clk           : std_logic;
signal rx_clk_0         : std_logic;
signal rx_frame         : std_logic;
signal rx_data          : std_logic_vector(5 downto 0);
signal rx_frame_pos     : std_logic;
signal rx_frame_neg     : std_logic;
signal rx_data_pos      : std_logic_vector(5 downto 0);
signal rx_data_neg      : std_logic_vector(5 downto 0);

signal tx_clk           : std_logic;
signal tx_frame         : std_logic;
signal tx_data          : std_logic_vector(5 downto 0);
signal tx_frame_pos     : std_logic;
signal tx_frame_neg     : std_logic;
signal tx_data_pos      : std_logic_vector(5 downto 0);
signal tx_data_neg      : std_logic_vector(5 downto 0);

-- IDELAY is usually added, but after testing it seems not required 
begin

  rx_clk_o         <= rx_clk;
  rx_data_pos_o    <= rx_data_pos;   
  rx_data_neg_o    <= rx_data_neg;   
  rx_frame_pos_o   <= rx_frame_pos;     
  rx_frame_neg_o   <= rx_frame_neg;    

  tx_clk           <= tx_clk_i;
  tx_data_pos      <= tx_data_pos_i;
  tx_data_neg      <= tx_data_neg_i;
  tx_frame_pos     <= tx_frame_pos_i;
  tx_frame_neg     <= tx_frame_neg_i;

  gen_iBuf : for i in 0 to 5 generate
   i_rx_d_buf : IBUFDS
   generic map (
      DIFF_TERM => TRUE, -- Differential Termination 
      IBUF_LOW_PWR => FALSE, 
      IOSTANDARD => "LVDS_25")
   port map (
      O => rx_data(i),  
      I => rx_data_in_p(i),  
      IB => rx_data_in_n(i) 
   ); 

  IDDR_data : IDDR 
   generic map (
      DDR_CLK_EDGE => "OPPOSITE_EDGE",                        
      INIT_Q1 => '0', 
      INIT_Q2 => '0', 
      SRTYPE => "SYNC") 
   port map (
      Q1 => rx_data_pos(i), 
      Q2 => rx_data_neg(i), 
      C => rx_clk,   
      CE => '1', 
      D => rx_data(i),   
      R => '0',   
      S => '0'    
      );

  end generate gen_iBuf;

  i_rx_f_buf : IBUFDS
  generic map (
     DIFF_TERM => TRUE, 
     IBUF_LOW_PWR => FALSE, 
     IOSTANDARD => "LVDS_25")
  port map (
     O => rx_frame,  
     I => rx_frame_in_p,  
     IB =>rx_frame_in_n 
  ); 

  IDDR_frame : IDDR 
  generic map (
     DDR_CLK_EDGE => "OPPOSITE_EDGE", 
                                      
     INIT_Q1 => '0', 
     INIT_Q2 => '0', 
     SRTYPE => "SYNC") 
  port map (
     Q1 => rx_frame_pos, 
     Q2 => rx_frame_neg, 
     C => rx_clk,   
     CE => '1', 
     D => rx_frame,   
     R => '0',   
     S => '0'    
     );

  i_rx_c_buf : IBUFDS
  generic map (
     DIFF_TERM => TRUE, 
     IBUF_LOW_PWR => FALSE, 
     IOSTANDARD => "LVDS_25")
  port map (
     O => rx_clk_0,  
     I => rx_clk_in_p,  
     IB =>rx_clk_in_n 
  ); 

  i_rx_c_bufg : BUFG
   port map (
    O => rx_clk, 
    I => rx_clk_0  
  );


  i_tx_f_buf : OBUFDS
  port map (
    O => tx_frame_out_p,   
    OB => tx_frame_out_n, 
    I => tx_frame    
  );

  gen_oBuf : for i in 0 to 5 generate
    i_tx_d_buf : OBUFDS
    port map (
      O => tx_data_out_p(i),   
      OB => tx_data_out_n(i), 
      I => tx_data(i)    
    );

    i_data_oddr : ODDR
    generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE", 
      INIT => '0',   
      SRTYPE => "SYNC") 
    port map (
      Q => tx_data(i),   
      C => tx_clk,    
      CE => '1',  
      D1 => tx_data_pos(i),  
      D2 => tx_data_neg(i),  
      R => '0',    
      S => '0'     
    );

  end generate gen_oBuf;

  i_tx_c_buf : OBUFDS
  port map (
    O => tx_clk_out_p,   
    OB => tx_clk_out_n, 
    I => tx_clk    
  );

  i_frame_oddr : ODDR
  generic map(
    DDR_CLK_EDGE => "OPPOSITE_EDGE", 
    INIT => '0',   
    SRTYPE => "SYNC") 
  port map (
    Q => tx_frame,   
    C => tx_clk,    
    CE => '1',  
    D1 => tx_frame_pos,  
    D2 => tx_frame_neg,  
    R => '0',    
    S => '0'     
  );

  end Behavioral;