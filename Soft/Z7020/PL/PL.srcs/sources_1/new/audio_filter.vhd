----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.11.2025 09:02:17
-- Design Name: 
-- Module Name: audio_filter - Behavioral
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

entity audio_filter is
    Port ( 
        aclk : in STD_LOGIC;
        s_axis_in_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_in_tvalid : in STD_LOGIC;
        m_axis_out_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_out_tvalid : out STD_LOGIC;
        cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC);
end audio_filter;

architecture Behavioral of audio_filter is

    
    COMPONENT fir_audio_lp IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tready : OUT STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_reload_tvalid : IN STD_LOGIC;
        s_axis_reload_tready : OUT STD_LOGIC;
        s_axis_reload_tlast : IN STD_LOGIC;
        s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        event_s_reload_tlast_missing : OUT STD_LOGIC;
        event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
    END COMPONENT fir_audio_lp;
    
    COMPONENT fir_audio_hp IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tready : OUT STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_reload_tvalid : IN STD_LOGIC;
        s_axis_reload_tready : OUT STD_LOGIC;
        s_axis_reload_tlast : IN STD_LOGIC;
        s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        event_s_reload_tlast_missing : OUT STD_LOGIC;
        event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
    END COMPONENT fir_audio_hp;
    
    signal config_lp_tvalid : STD_LOGIC := '0';
    signal config_hp_tvalid : STD_LOGIC := '0';
    signal config_lp_tready, config_hp_tready : STD_LOGIC;
    signal config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal reload_lp_tvalid : STD_LOGIC := '0';
    signal reload_hp_tvalid : STD_LOGIC := '0';
    signal reload_lp_tready, reload_hp_tready : STD_LOGIC;
    signal reload_tlast : STD_LOGIC := '0';
    signal reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0);
    signal fir_coeff : integer range 0 to 64 := 0;
    signal fir_lp_delay : integer range 0 to 8192 := 0;
    signal fir_hp_delay : integer range 0 to 8192 := 0;
    signal lp_out_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal lp_out_tvalid : STD_LOGIC;
    signal hp_in_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0);
    signal hp_out_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal correct_gain : STD_LOGIC_VECTOR(1 DOWNTO 0) := "10";

begin

process(aclk)
begin
	if rising_edge(aclk) then	
	    reload_tlast <= '0';
	    reload_tlast <= '0';
	    reload_hp_tvalid <= '0';
	    config_hp_tvalid <= '0';
        reload_lp_tvalid <= '0';
	    config_lp_tvalid <= '0';
	     
	    
	    if fir_lp_delay < 7680 and fir_lp_delay /= 0 then -- задержка после загрузки на 1 сэмпл
	       fir_lp_delay <= fir_lp_delay + 1;	        
	    elsif fir_lp_delay = 7680 then 
	       config_lp_tvalid <= '1'; 
	       fir_lp_delay <= 0;
	    end if;     
	    
        if fir_hp_delay < 7680 and fir_hp_delay /= 0 then -- задержка после загрузки на 1 сэмпл
	       fir_hp_delay <= fir_hp_delay + 1;	        
	    elsif fir_hp_delay = 7680 then 
	       config_hp_tvalid <= '1'; 
	       fir_hp_delay <= 0;
	    end if;  
		
		if cfg_wr = '1' then				   		
			if cfg_addra = x"0E" then                
			    reload_tdata <= cfg_dina(23 DOWNTO 0);
			    reload_lp_tvalid <= '1';
			    if cfg_dina(31) = '1' then
			       fir_coeff <= 0;
			    else
			        if fir_coeff < 30 then
                        fir_coeff <= fir_coeff + 1;
                    elsif fir_coeff = 30 then  -- фильтр симметричный, грузим 32 коэффициента
                        reload_tlast <= '1';
                        fir_lp_delay <= 1;
                    end if;		       
			    end if; 
			elsif cfg_addra = x"0F" then                
			    reload_tdata <= cfg_dina(23 DOWNTO 0);
			    reload_hp_tvalid <= '1';
			    if cfg_dina(31) = '1' then
			       fir_coeff <= 0;
			    else
			        if fir_coeff < 62 then
                        fir_coeff <= fir_coeff + 1;
                    elsif fir_coeff = 62 then
                        reload_tlast <= '1';
                        fir_hp_delay <= 1;
                    end if;		       
			    end if;
			elsif cfg_addra = x"10" then                
			    correct_gain <= cfg_dina(1 DOWNTO 0);
			end if;				     			           
		end if;  
	end if;
end process;

audio_lp :  fir_audio_lp
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => s_axis_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => s_axis_in_tdata,
        s_axis_config_tvalid => config_lp_tvalid,
        s_axis_config_tready => config_lp_tready,
        s_axis_config_tdata => config_tdata,
        s_axis_reload_tvalid => reload_lp_tvalid,
        s_axis_reload_tready => reload_lp_tready,
        s_axis_reload_tlast => reload_tlast,
        s_axis_reload_tdata => reload_tdata,
        m_axis_data_tvalid => lp_out_tvalid,
        m_axis_data_tdata => lp_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
    hp_in_tdata <= lp_out_tdata(25 downto 2) when correct_gain = "01" else 
                   lp_out_tdata(26 downto 3) when correct_gain = "00" else
                   lp_out_tdata(24 downto 1);
    
audio_hp :  fir_audio_hp
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => lp_out_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => hp_in_tdata,
        s_axis_config_tvalid => config_hp_tvalid,
        s_axis_config_tready => config_hp_tready,
        s_axis_config_tdata => config_tdata,
        s_axis_reload_tvalid => reload_hp_tvalid,
        s_axis_reload_tready => reload_hp_tready,
        s_axis_reload_tlast => reload_tlast,
        s_axis_reload_tdata => reload_tdata,
        m_axis_data_tvalid => m_axis_out_tvalid,
        m_axis_data_tdata => hp_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
    m_axis_out_tdata <= hp_out_tdata(23 downto 0) when correct_gain = "11" else
                        hp_out_tdata(24 downto 1);


end Behavioral;
