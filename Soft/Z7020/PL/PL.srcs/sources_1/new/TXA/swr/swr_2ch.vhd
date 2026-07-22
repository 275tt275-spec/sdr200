----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.07.2026 11:41:48
-- Design Name: 
-- Module Name: swr_2ch - Behavioral
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

entity swr_2ch is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc0_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc1_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_addra : in STD_LOGIC_VECTOR (0 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC
    );
end swr_2ch;

architecture Behavioral of swr_2ch is

component swr_channel is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        m_rssi_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_angle_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_tvalid : out STD_LOGIC;
        cic_gain : in  STD_LOGIC_VECTOR (1 downto 0)
    );
end component swr_channel;

    signal cic_gain_0, cic_gain_1 : STD_LOGIC_VECTOR (1 downto 0) := "11";
    signal rssi_0, rssi_1 : STD_LOGIC_VECTOR (15 downto 0);
    signal angle_0, angle_1 : STD_LOGIC_VECTOR (15 downto 0);
    signal ch_valid_0, ch_valid_1 : STD_LOGIC;
    signal rssi_data, angle_data : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal iq_data_0, iq_data_1 : STD_LOGIC_VECTOR (31 downto 0);
    signal iq_valid_0, iq_valid_1 : STD_LOGIC;

begin

    cfg_douta <= rssi_data when cfg_addra = "0" else angle_data;

cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        if cfg_wr = '1' then 
            if cfg_addra = "0" then
                cic_gain_0 <= cfg_dina(1 downto 0); 
                cic_gain_1 <= cfg_dina(17 downto 16); 
            end if; 
        end if;
   end if;
end process cmd_process;

out_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        if ch_valid_0 = '1' then 
            angle_data(15 downto 0) <= angle_0;
            rssi_data(15 downto 0) <= rssi_0;
        end if;
        if ch_valid_1 = '1' then 
            angle_data(31 downto 16) <= angle_1;
            rssi_data(31 downto 16) <= rssi_1;
        end if;
   end if;
end process out_process;

ch_0 : swr_channel
    Port map ( 
        aclk => aclk,
        aresetn => aresetn,
        s_axis_adc_tdata => s_axis_adc0_tdata,
        s_axis_dds_tdata => s_axis_dds_tdata,    
        m_rssi_tdata => rssi_0,
        m_angle_tdata => angle_0,
        m_tvalid => ch_valid_0,
        cic_gain => cic_gain_0
    );
    
ch_1 : swr_channel
    Port map ( 
        aclk => aclk,
        aresetn => aresetn,
        s_axis_adc_tdata => s_axis_adc1_tdata,
        s_axis_dds_tdata => s_axis_dds_tdata,
        m_rssi_tdata => rssi_1,
        m_angle_tdata => angle_1,
        m_tvalid => ch_valid_1,
        cic_gain => cic_gain_1
    );

end Behavioral;
