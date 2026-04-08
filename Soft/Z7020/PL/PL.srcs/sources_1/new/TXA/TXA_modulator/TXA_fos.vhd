----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.06.2024 12:09:42
-- Design Name: 
-- Module Name: TXA_fos - Behavioral
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

entity TXA_fos is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (47 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (47 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_cfg_tvalid : in STD_LOGIC 
    );
end TXA_fos;

architecture Behavioral of TXA_fos is

COMPONENT fir_fos_txa IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tready : OUT STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_reload_tvalid : IN STD_LOGIC;
        s_axis_reload_tready : OUT STD_LOGIC;
        s_axis_reload_tlast : IN STD_LOGIC;
        s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        event_s_reload_tlast_missing : OUT STD_LOGIC;
        event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
END COMPONENT  fir_fos_txa;

    signal config_tvalid : STD_LOGIC := '0';
    signal config_tready : STD_LOGIC;
    signal config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal reload_tvalid : STD_LOGIC := '0';
    signal reload_tready : STD_LOGIC;
    signal reload_tlast : STD_LOGIC := '0';
    signal reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others => '0');
    signal fir_coeff : integer range 0 to 128 := 0;
    signal fir_delay : integer range 0 to 8192 := 0;
    signal gain_correct : STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";
    signal firout_tdata : STD_LOGIC_VECTOR (63 downto 0);

begin

process(aclk)
begin
	if rising_edge(aclk) then	
	    reload_tlast <= '0';
	    reload_tvalid <= '0';
	    config_tvalid <= '0';
	    
	    if reload_tlast = '1' then
	       fir_delay <= 1;
	    end if;	    
	    
	    if fir_delay < 7680 and fir_delay /= 0 then -- �������� ����� �������� �� 1 �����
	       fir_delay <= fir_delay + 1;	        
	    elsif fir_delay = 7680 then 
	       config_tvalid <= '1'; 
	       fir_delay <= 0;
	    end if;      
		
		if s_axis_cfg_tvalid = '1' then				   		
			if s_axis_cfg_tdest = "0" then
			    reload_tdata <= s_axis_cfg_tdata(23 DOWNTO 0);
			    reload_tvalid <= '1';
			    if s_axis_cfg_tdata(31) = '1' then
			       fir_coeff <= 0;
			       fir_delay <= 0;
			    else
			        if fir_coeff < 62 then
                        fir_coeff <= fir_coeff + 1;
                    elsif fir_coeff = 62 then 
--                        fir_coeff <= fir_coeff + 1;
                        reload_tlast <= '1';
                    end if;		       
			    end if; 
			elsif s_axis_cfg_tdest = "1" then    
			    gain_correct <= s_axis_cfg_tdata(2 DOWNTO 0);    
			end if;				     			           
		end if;  
	end if;
end process;

    m_axis_tdata <= (firout_tdata(61 downto 38) & firout_tdata(29 downto 6)) when gain_correct = "001" else 
                    (firout_tdata(60 downto 37) & firout_tdata(28 downto 5)) when gain_correct = "010" else 
                    (firout_tdata(59 downto 36) & firout_tdata(27 downto 4)) when gain_correct = "011" else 
                    (firout_tdata(58 downto 35) & firout_tdata(26 downto 3)) when gain_correct = "100" else 
                    (firout_tdata(57 downto 34) & firout_tdata(25 downto 2)) when gain_correct = "101" else 
                    (firout_tdata(56 downto 33) & firout_tdata(24 downto 1)) when gain_correct = "110" else 
                    (firout_tdata(55 downto 32) & firout_tdata(23 downto 0)) when gain_correct = "111" else 
                    (firout_tdata(62 downto 39) & firout_tdata(30 downto 7)) when gain_correct = "000";
                    
fir_0 : fir_fos_txa
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => s_axis_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => s_axis_tdata,
        s_axis_config_tvalid => config_tvalid,
        s_axis_config_tready => config_tready,
        s_axis_config_tdata => config_tdata,
        s_axis_reload_tvalid => reload_tvalid,
        s_axis_reload_tready => reload_tready,
        s_axis_reload_tlast => reload_tlast,
        s_axis_reload_tdata => reload_tdata,
        m_axis_data_tvalid => m_axis_tvalid,
        m_axis_data_tdata => firout_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );

end Behavioral;
