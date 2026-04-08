----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.11.2025 17:32:09
-- Design Name: 
-- Module Name: demod_tb - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity demod_tb is
--  Port ( );
end demod_tb;

architecture Behavioral of demod_tb is

    COMPONENT RXA_demod is
        Port ( 
            aclk : in  STD_LOGIC;     
            s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
            s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0); 
            s_axis_tvalid : in STD_LOGIC;      
            m_axis_demod_tdata : out STD_LOGIC_VECTOR (23 downto 0); -- out in s24
            m_axis_demod_tvalid : out STD_LOGIC;
            m_axis_rssi_tdata : out STD_LOGIC_VECTOR (31 downto 0);  -- out in s32
            m_axis_rssi_tvalid : out STD_LOGIC;
            dds_config_16_data : in std_logic_vector(15 downto 0);
            dds_config_16_valid : in std_logic;
            modulation : in STD_LOGIC_VECTOR (1 downto 0);
            j3e_lsb : in STD_LOGIC
        );
    end  COMPONENT RXA_demod;
    
    COMPONENT dds_test IS
        PORT (
            aclk : IN STD_LOGIC;
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END COMPONENT dds_test;
    
    constant FPGA_CLK_period : time := 10 ns;
    
   signal aclk : STD_LOGIC := '0';  
   signal signal_iq_tdata : STD_LOGIC_VECTOR (31 downto 0);  
   signal signal_iq_tvalid : STD_LOGIC := '0';
   signal s_axis_tdata : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
   signal s_axis_tuser : STD_LOGIC_VECTOR (0 downto 0) := (others => '0'); 
   signal s_axis_tvalid : STD_LOGIC := '0';      
   signal dds_config_16_data : std_logic_vector(15 downto 0) := (others => '0');
   signal dds_config_16_valid : std_logic := '0';
   signal modulation : STD_LOGIC_VECTOR (1 downto 0) := (others => '0');
   signal j3e_lsb : STD_LOGIC := '0';


begin

uut: RXA_demod PORT MAP ( 
        aclk => aclk,     
        s_axis_tdata => s_axis_tdata,
        s_axis_tuser => s_axis_tuser, 
        s_axis_tvalid => s_axis_tvalid,     
        dds_config_16_data => dds_config_16_data,
        dds_config_16_valid => dds_config_16_valid,
        modulation => modulation,
        j3e_lsb => j3e_lsb
    );
    
dds: dds_test PORT MAP (
        aclk => signal_iq_tvalid,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => signal_iq_tdata
    );
    
process(aclk)
begin
	if rising_edge(aclk) then		
		s_axis_tvalid <= '0'; 			
        if signal_iq_tvalid = '1' then 		
            s_axis_tdata <= signal_iq_tdata(31 downto 16) & x"0000";      		   
            s_axis_tuser <= "0";
            s_axis_tvalid <= '1';
        elsif s_axis_tuser = "0" then
            s_axis_tdata <= signal_iq_tdata(15 downto 0) & x"0000";   
            s_axis_tuser <= "1";
            s_axis_tvalid <= '1';   
        end if; 		  	
	end if;
end process; 
    
process
begin
	aclk <= '1';
	wait for FPGA_CLK_period/2;
	aclk <= '0';
	wait for FPGA_CLK_period/2;
end process;

process
begin
    signal_iq_tvalid <= '0';
    wait for 6249 * FPGA_CLK_period;
	signal_iq_tvalid <= '1';
	wait for FPGA_CLK_period;		
end process;

    modulation <= "11";

end Behavioral;
