----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.05.2025 10:18:11
-- Design Name: 
-- Module Name: audio_proc - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

entity audio_proc is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (3 downto 0);
        aclk : in STD_LOGIC
    );
end audio_proc;

architecture Behavioral of audio_proc is

component lim_proc is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (3 downto 0);
        aclk : in STD_LOGIC
    );
    end component lim_proc;    
    
    signal lim_out_tdata : std_logic_vector(23 downto 0);
    signal lim_out_tvalid : std_logic;
    signal over : STD_LOGIC_VECTOR (3 downto 0);
    signal lim_en : STD_LOGIC := '1';

begin

process(aclk)
begin
	if rising_edge(aclk) then  
	   if s_axis_cfg_tvalid = '1' then 
            if s_axis_cfg_tdest = "110" then
                lim_en <= s_axis_cfg_tdata(0); 
            end if;    
	   end if;    
	end if;
end process;

    m_axis_audio_tvalid <= s_axis_audio_tvalid when lim_en = '0' else lim_out_tvalid;
    m_axis_audio_tdata <= s_axis_audio_tdata when lim_en = '0' else lim_out_tdata;
    lim_over <= "0000" when lim_en = '0' else over; 
    
limiter_0 : lim_proc
    PORT MAP (  
        m_axis_audio_tdata => lim_out_tdata,
        m_axis_audio_tvalid => lim_out_tvalid,
        m_axis_iq_tdata => open,
        m_axis_iq_tvalid => open,
        s_axis_audio_tdata => s_axis_audio_tdata,
        s_axis_audio_tvalid => s_axis_audio_tvalid,  -- 16 KSamples	
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest,
        s_axis_cfg_tvalid => s_axis_cfg_tvalid,
        lim_over => over,
        aclk => aclk
    );


end Behavioral;
