----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 15.05.2025 11:03:25
-- Design Name: 
-- Module Name: lim_div - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim_div is
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
end lim_div;

architecture Behavioral of lim_div is

     component div_24_16 is
        port (
            aclk : IN STD_LOGIC;
            s_axis_divisor_tvalid : IN STD_LOGIC;
            s_axis_divisor_tready : OUT STD_LOGIC;
            s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            s_axis_dividend_tvalid : IN STD_LOGIC;
            s_axis_dividend_tready : OUT STD_LOGIC;
            s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(39 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0)
        );
    end component div_24_16;
    
    signal dividend : std_logic_vector(39 downto 0); 
    signal dout_tdata : std_logic_vector(39 downto 0); 
    signal dout_tdata_r : std_logic_vector(39 downto 0) := (others => '0');   
    signal dout_tvalid : std_logic;
    signal dout_tvalid_r : std_logic := '0';

begin

    dividend <= s_axis_dividend_tdata * x"8000";

div_0 : div_24_16
    PORT MAP (
        aclk => aclk,
        s_axis_divisor_tvalid => s_axis_divisor_tvalid,
        s_axis_divisor_tready => open,
        s_axis_divisor_tdata => s_axis_divisor_tdata,
        s_axis_dividend_tvalid => s_axis_dividend_tvalid,
        s_axis_dividend_tready => open,
        s_axis_dividend_tdata => dividend,
        m_axis_dout_tvalid => dout_tvalid,
        m_axis_dout_tdata => dout_tdata
    );
    
process(aclk)
begin
	if rising_edge(aclk) then   
	   dout_tvalid_r <= dout_tvalid;
       if dout_tvalid = '1' then  
            dout_tdata_r <= dout_tdata;
	   end if;  	
	
	   m_axis_dout_tvalid <= dout_tvalid_r;
	   if dout_tdata_r(39 downto 26) = "11111111111111" or dout_tdata_r(39 downto 26) = "00000000000000" then
	       out_over <= '0'; 
	       m_axis_dout_tdata <= dout_tdata_r(26 downto 3);
	   elsif  dout_tdata_r(39) = '0' then 
	       out_over <= '1'; 
	       m_axis_dout_tdata <= x"7FFFFF";
	   else
	       out_over <= '1'; 
	       m_axis_dout_tdata <= x"800000";
	   end if;    
	end if;
end process;

end Behavioral;
