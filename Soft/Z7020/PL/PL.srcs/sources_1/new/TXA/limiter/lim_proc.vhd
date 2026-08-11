----------------------------------------------------------------------------------
-- input data 24 bits 16KSamples
-- output data 24 bits 16KSamples
-- cfg
-- 0 lim_in_gain default "00" & x"3FFF"
-- 1 lim_limit default x"0400"
-- 2 lim_out_gain default "00" & x"1FFF",
-- 3 phase_step ������� ����������� ��������������� default x"1D9A"  -- 1850 Hz
-- 4 limit_overshoot default x"1000"
-- 5 ������������ LP FIR
-- 6 CTRL bit 0 - enable
-- ����� ������� lim_out_gain ���� ��������� ������ - ���� lim_limit ��������� � 2 ����, ���� ��������� lim_out_gain � 2 ����
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim_proc is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (6 downto 0);
        aclk : in STD_LOGIC
    );
end lim_proc;

architecture Behavioral of lim_proc is

    component lim_eq_fir is
    port (
        aclk : in STD_LOGIC;
        s_axis_data_tvalid : in STD_LOGIC;
        s_axis_data_tready : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR ( 23 downto 0 );
        m_axis_data_tvalid : out STD_LOGIC;
        m_axis_data_tdata : out STD_LOGIC_VECTOR ( 23 downto 0 )
    );
    end component lim_eq_fir;

    COMPONENT lim_a2iq is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        dds_cfg_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_cfg_tvalid : in STD_LOGIC;
        fir_reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : STD_LOGIC;
        fir_reload_tlast : STD_LOGIC;
        fir_config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : STD_LOGIC;
        aclk : in STD_LOGIC 
    );
    END COMPONENT lim_a2iq;
	
	COMPONENT lim_limiter is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_data_tvalid : in STD_LOGIC; 
        limit : in STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata : in STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : in STD_LOGIC;
        fir_reload_tlast : in STD_LOGIC;
        fir_config_tdata : in STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : in STD_LOGIC;
        over : out STD_LOGIC_VECTOR(1 DOWNTO 0);
        divisor_dbg : out std_logic_vector(15 downto 0); 
        aclk : in STD_LOGIC
    );
    END COMPONENT lim_limiter;
    
    COMPONENT lim_overshoot is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_data_tvalid : in STD_LOGIC; 
        limit : in STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata : in STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : in STD_LOGIC;
        fir_reload_tlast : in STD_LOGIC;
        fir_config_tdata : in STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : in STD_LOGIC;
        over : out STD_LOGIC_VECTOR(1 DOWNTO 0);
        denom_dbg : out std_logic_vector(15 downto 0); 
        aclk : in STD_LOGIC
    );
    END COMPONENT lim_overshoot;
    
    COMPONENT lim_iq2a is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC; 
        dds_cfg_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_cfg_tvalid : in STD_LOGIC;
        over : out STD_LOGIC;
        aclk : in STD_LOGIC
    );
    END COMPONENT  lim_iq2a;
    
    signal divisor_dbg : std_logic_vector(15 downto 0); 
    signal denom_dbg : std_logic_vector(15 downto 0); 
	
	signal fir1_tdata : std_logic_vector(23 downto 0); 
    signal fir1_tvalid : std_logic;
    signal multin_tdata : std_logic_vector(23 downto 0);
    signal multout_tdata : std_logic_vector(41 downto 0);    
    signal multout_tvalid, multout_tvalid_r : std_logic := '0'; 
    signal lim_in_tdata : std_logic_vector(23 downto 0);
    signal lim_in_tvalid : std_logic := '0';
	signal limiter_tdata : std_logic_vector(47 downto 0);
    signal limiter_tvalid : std_logic;
    signal limiter_out_tdata : std_logic_vector(47 downto 0);
    signal limiter_out_tvalid : std_logic;
    signal overshoot_out_tdata : std_logic_vector(47 downto 0);
    signal overshoot_out_tvalid : std_logic;
    signal mult2in_tdata : std_logic_vector(23 downto 0);
    signal mult2out_tdata : std_logic_vector(41 downto 0); 
    signal mult2out_tvalid, mult2out_tvalid_r : std_logic := '0';
 --   signal audio_out_tdata : std_logic_vector(23 downto 0);
 --   signal audio_out_tvalid : std_logic;
 --   signal audio_out : std_logic_vector(41 downto 0);
    
    signal lim_in_gain : std_logic_vector(17 downto 0) := "00" & x"3FFF";
    signal lim_limit : STD_LOGIC_VECTOR (15 downto 0) := x"0400";
    signal limit_overshoot : STD_LOGIC_VECTOR (15 downto 0) := x"1000";
    signal lim_out_gain : STD_LOGIC_VECTOR (17 downto 0) := "00" & x"4D00"; -- mult 1.2

    signal dds_a2iq_cfg : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00001D9A"; -- 1850 Hz 
    signal dds_iq2a_cfg : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00001D9A"; -- 1850 Hz 
    signal dds_cfg_tvalid : STD_LOGIC;
    
    signal fir_reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others => '0');
    signal fir_reload_tvalid : STD_LOGIC := '0';
    signal fir_reload_tlast : STD_LOGIC := '0';
    signal fir_config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal fir_config_tvalid : STD_LOGIC := '0';
    signal fir_coeff : integer range 0 to 63 := 0;
    signal fir_delay : integer range 0 to 8191 := 0;
    
    signal audio_tdata_reg : STD_LOGIC_VECTOR (23 downto 0);
    signal audio_tvalid_reg : STD_LOGIC;
    
    signal iq_out_0, iq_out_1 : std_logic_vector(41 downto 0) := (others => '0');
    signal iq_out_tdata : std_logic_vector(47 downto 0);
    signal iq_out_valid : STD_LOGIC := '0';
	
begin

-- load filters
process(aclk)
begin
	if rising_edge(aclk) then	
	    fir_reload_tlast <= '0';
	    fir_reload_tvalid <= '0';
	    fir_config_tvalid <= '0';
	    
	    if fir_reload_tlast = '1' then
	       fir_delay <= 1;
	    end if;	    
	    
	    if fir_delay < 7680 and fir_delay /= 0 then 
	       fir_delay <= fir_delay + 1;	        
	    elsif fir_delay = 7680 then 
	       fir_config_tvalid <= '1'; 
	       fir_delay <= 0;
	    end if;      
		
		if s_axis_cfg_tvalid = '1' then				   		
			if s_axis_cfg_tdest = "101" then
			    fir_reload_tdata <= s_axis_cfg_tdata(23 DOWNTO 0);
			    fir_reload_tvalid <= '1';
			    if s_axis_cfg_tdata(31) = '1' then
			       fir_coeff <= 0;
			       fir_delay <= 0;
			    else
			        if fir_coeff < 30 then
                        fir_coeff <= fir_coeff + 1;
                    elsif fir_coeff = 30 then  
--                        fir_coeff <= fir_coeff + 1;
                        fir_reload_tlast <= '1';
                    end if;		       
			    end if; 
			end if;				     			           
		end if;  
	end if;
end process;

process(aclk)
begin
	if rising_edge(aclk) then  
	   dds_cfg_tvalid <= '0';
	   if s_axis_cfg_tvalid = '1' then 
          if s_axis_cfg_tdest = "000" then
             lim_in_gain <= s_axis_cfg_tdata(17 downto 0); 
          elsif s_axis_cfg_tdest = "001" then
             lim_limit <= s_axis_cfg_tdata(15 downto 0);
          elsif s_axis_cfg_tdest = "010" then
             lim_out_gain <= s_axis_cfg_tdata(17 downto 0);
          elsif s_axis_cfg_tdest = "011" then
             dds_a2iq_cfg <= x"0000" & s_axis_cfg_tdata(15 downto 0);  
             dds_iq2a_cfg <= s_axis_cfg_tdata;  
             dds_cfg_tvalid <= '1';
          elsif s_axis_cfg_tdest = "100" then
             limit_overshoot <= s_axis_cfg_tdata(15 downto 0);
          end if;   
	   end if;    
	end if;
end process;

fir_in_0: component lim_eq_fir
    port map (
        aclk => aclk,
        m_axis_data_tdata => fir1_tdata,
        m_axis_data_tvalid => fir1_tvalid,
        s_axis_data_tdata => s_axis_audio_tdata,
        s_axis_data_tready => open,
        s_axis_data_tvalid => s_axis_audio_tvalid
    );
    
    multin_tdata <= fir1_tdata;
    multout_tvalid <= fir1_tvalid;
     
process(aclk)
begin
	if rising_edge(aclk) then  
	   multout_tvalid_r <= multout_tvalid;
	   multout_tdata <= multin_tdata * lim_in_gain;
	   lim_in_tvalid <= multout_tvalid_r;
	   if multout_tdata(41 downto 36) = "111111" or multout_tdata(41 downto 36) = "000000" then
	       lim_over(0) <= '0';
	       lim_in_tdata <= multout_tdata(36 downto 13);
	   elsif  multout_tdata(41) = '0' then 
	       lim_over(0) <= '1'; 
	       lim_in_tdata <= x"7FFFFF";
	   else
	       lim_over(0) <= '1'; 
	       lim_in_tdata <= x"800000";
	   end if;    
	end if;
end process;

a2iq_0 : lim_a2iq
    PORT MAP (
        m_axis_iq_tdata => limiter_tdata,
        m_axis_iq_tvalid => limiter_tvalid,
        s_axis_audio_tdata => lim_in_tdata,
        s_axis_audio_tvalid => lim_in_tvalid,
        dds_cfg_data => dds_a2iq_cfg,
        dds_cfg_tvalid => dds_cfg_tvalid,
        fir_reload_tdata => fir_reload_tdata,
        fir_reload_tvalid => fir_reload_tvalid,
        fir_reload_tlast => fir_reload_tlast,
        fir_config_tdata => fir_config_tdata,
        fir_config_tvalid => fir_config_tvalid,
        aclk => aclk 
    );
	
clipper_0 : lim_limiter
    PORT MAP (
        m_axis_data_tdata => limiter_out_tdata,
        m_axis_data_tvalid => limiter_out_tvalid,
        s_axis_data_tdata => limiter_tdata,
        s_axis_data_tvalid => limiter_tvalid,
        limit => lim_limit,
        fir_reload_tdata => fir_reload_tdata,
        fir_reload_tvalid => fir_reload_tvalid,
        fir_reload_tlast => fir_reload_tlast,
        fir_config_tdata => fir_config_tdata,
        fir_config_tvalid => fir_config_tvalid,
        over => lim_over(3 downto 2),
        divisor_dbg => divisor_dbg,
        aclk => aclk
    );
  
overshoot_0 : lim_overshoot
PORT MAP ( 
        m_axis_data_tdata => overshoot_out_tdata,
        m_axis_data_tvalid => overshoot_out_tvalid,
        s_axis_data_tdata => limiter_out_tdata,
        s_axis_data_tvalid => limiter_out_tvalid,
        limit => limit_overshoot,
        fir_reload_tdata => fir_reload_tdata,
        fir_reload_tvalid => fir_reload_tvalid,
        fir_reload_tlast => fir_reload_tlast,
        fir_config_tdata => fir_config_tdata,
        fir_config_tvalid => fir_config_tvalid,
        over => lim_over(5 downto 4),
        denom_dbg => denom_dbg,
        aclk => aclk
    );
       
iq2a_0 : lim_iq2a
    port map (
        m_axis_audio_tdata => audio_tdata_reg,
        m_axis_audio_tvalid => audio_tvalid_reg,
        s_axis_iq_tdata => overshoot_out_tdata,
        s_axis_iq_tvalid => overshoot_out_tvalid,
        dds_cfg_data => dds_iq2a_cfg,
        dds_cfg_tvalid => dds_cfg_tvalid,
        over => lim_over(6),
        aclk => aclk
    );
    
    mult2in_tdata <= audio_tdata_reg;
    mult2out_tvalid <= audio_tvalid_reg;
    
process(aclk)
begin
	if rising_edge(aclk) then  
	   mult2out_tvalid_r <= mult2out_tvalid;
	   mult2out_tdata <= mult2in_tdata * lim_out_gain;
	   m_axis_audio_tvalid <= mult2out_tvalid_r;
	   if mult2out_tdata(41 downto 36) = "111111" or mult2out_tdata(41 downto 36) = "000000" then
	       lim_over(1) <= '0';
	       m_axis_audio_tdata <= mult2out_tdata(36 downto 13);
	   elsif mult2out_tdata(41) = '0' then 
	       lim_over(1) <= '1'; 
	       m_axis_audio_tdata <= x"7FFFFF";
	   else
	       lim_over(1) <= '1'; 
	       m_axis_audio_tdata <= x"800000";
	   end if;    
	end if;
end process;
    
end Behavioral;
