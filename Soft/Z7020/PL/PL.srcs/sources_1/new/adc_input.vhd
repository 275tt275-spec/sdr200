library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity adc_input is
    Port (  
        clk_p : in STD_LOGIC;
        clk_n : in STD_LOGIC;
        din_p : in STD_LOGIC_VECTOR (15 downto 0);
        din_n : in STD_LOGIC_VECTOR (15 downto 0);
        m_axis_data_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        adc_rand_en : in STD_LOGIC; 
        adc_max_value : out STD_LOGIC_VECTOR (15 downto 0);
        adc_max_rst : in STD_LOGIC;
        adc_clk_out : out STD_LOGIC
    );
end adc_input;

architecture Behavioral of adc_input is

    signal adc_data : std_logic_vector(15 downto 0);
    signal adc_data_buf : std_logic_vector(15 downto 0);
    signal adc_out_data : std_logic_vector(15 downto 0);
    signal rxa_tdata_rand : STD_LOGIC_VECTOR (15 downto 0);
    signal adc_max : signed(15 downto 0) := x"0000"; 
    signal adc_abs : signed(15 downto 0) := x"0000"; 
    signal adc_clk, adc_clk0 : STD_LOGIC;
    
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER OF adc_max_rst: SIGNAL IS "XIL_INTERFACENAME adc_max_rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0";
    ATTRIBUTE X_INTERFACE_INFO OF adc_max_rst: SIGNAL IS "xilinx.com:signal:reset:1.0 adc_max_rst RST";

begin

clkbuf : IBUFDS
generic map (
	DIFF_TERM => TRUE, -- Differential Termination 
	IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
	IOSTANDARD => "DEFAULT")
   port map (
      O => adc_clk0, 
      I => clk_p,
      IB => clk_n
);

add_bufg : BUFG
   port map (
      O => adc_clk, -- 1-bit output: Clock output
      I => adc_clk0  -- 1-bit input: Clock input
   );
   
lbl : for k in 0 to 15 generate
    dbuf : IBUFDS
      generic map (
        DIFF_TERM => TRUE, -- Differential Termination 
        IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT")
       port map (
          O => adc_data(k), 
          I => din_p(k),
          IB => din_n(k)
       );
       
    IDDR_inst : IDDR
    generic map (
       DDR_CLK_EDGE => "SAME_EDGE_PIPELINED", -- "OPPOSITE_EDGE", "SAME_EDGE"
                                        -- or "SAME_EDGE_PIPELINED"
       INIT_Q1 => '0', -- Initial value of Q1: '0' or '1'
       INIT_Q2 => '0', -- Initial value of Q2: '0' or '1'
       SRTYPE => "SYNC") -- Set/Reset type: "SYNC" or "ASYNC"
    port map (
       Q1 => adc_data_buf(k), -- 1-bit output for positive edge of clock
       Q2 => open, -- 1-bit output for negative edge of clock
       C => adc_clk,   -- 1-bit clock input
       CE => '1', -- 1-bit clock enable input
       D => adc_data(k),   -- 1-bit DDR data input
       R => '0',   -- 1-bit reset
       S => '0'    -- 1-bit set
       );
end generate;

    adc_clk_out <= adc_clk;
    adc_out_data <= adc_data_buf when adc_rand_en = '0' else rxa_tdata_rand;                      

    rxa_tdata_rand(0) <= adc_data_buf(0); 
rxa : for k in 1 to 15 generate
    rxa_tdata_rand(k) <= adc_data_buf(k) xor adc_data_buf(0);
end generate;

    m_axis_data_tdata <= adc_out_data;    
    adc_max_value <= std_logic_vector(adc_max);

process(adc_clk)
begin
	if rising_edge(adc_clk) then
	   adc_abs <= abs(signed(adc_out_data));
	   if adc_max_rst = '1' then
	       adc_max <= x"0000";
	   elsif adc_abs > adc_max then
	       adc_max <= adc_abs;	
	   end if;        
	end if;
end process;

end Behavioral;