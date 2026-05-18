----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.05.2026 07:20:51
-- Design Name: 
-- Module Name: iq_set - Behavioral
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

entity iq_set is
  Port (
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC;   
        s_axis_iq_tready : out STD_LOGIC; 
        s_axis_iq_tlast : in STD_LOGIC; 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC; 
        m_axis_iq_tready : in STD_LOGIC;
		aclk : in std_logic 
	);
end iq_set;

architecture Behavioral of iq_set is

    signal i_tdata, q_data : STD_LOGIC_VECTOR (23 downto 0);
    signal data_valid, t_valid : STD_LOGIC := '0'; 

begin

    m_axis_iq_tvalid <= t_valid;

iq_process : process (aclk) is
begin 
   if rising_edge(aclk) then 
     t_valid <= '0';
     if s_axis_iq_tvalid = '1' then
        if s_axis_iq_tlast = '0' then
            i_tdata <= s_axis_iq_tdata;
        else
            m_axis_iq_tdata <= i_tdata & s_axis_iq_tdata;
            data_valid <= '1';
            s_axis_iq_tready <= '0';
        end if;    
     end if;
     if m_axis_iq_tready = '1' then
        if data_valid = '1' then
            t_valid <= '1';
            data_valid <= '0';
            s_axis_iq_tready <= '1';
        end if;
     end if;
   end if;
end process iq_process;

end Behavioral;
