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
    
    COMPONENT dds_16 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_phase_tvalid : OUT STD_LOGIC;
        m_axis_phase_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    END COMPONENT dds_16;

    COMPONENT lim_a2iq is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        dds_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_tvalid : in STD_LOGIC;
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
        over : out STD_LOGIC;
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
        over :out STD_LOGIC;
        denom_dbg : out std_logic_vector(15 downto 0); 
        aclk : in STD_LOGIC
    );
    END COMPONENT lim_overshoot;
		
--	COMPONENT lim_dsp_24m18 is
--    Port (
--            CLK : in STD_LOGIC;
--            A : in STD_LOGIC_VECTOR ( 23 downto 0 );
--            B : in STD_LOGIC_VECTOR ( 17 downto 0 );
--            P : out STD_LOGIC_VECTOR ( 41 downto 0 )
--        );
--    END COMPONENT lim_dsp_24m18;
    
    COMPONENT lim_iq2a is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC; 
        dds_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_tvalid : in STD_LOGIC;
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
    signal mult2in_tdata : std_logic_vector(47 downto 0);
    signal mult2in_tvalid, mult2in_tvalid_r : std_logic := '0';
 --   signal audio_out_tdata : std_logic_vector(23 downto 0);
 --   signal audio_out_tvalid : std_logic;
 --   signal audio_out : std_logic_vector(41 downto 0);
    
    signal lim_in_gain : std_logic_vector(17 downto 0) := "00" & x"3FFF";
    signal lim_limit : STD_LOGIC_VECTOR (15 downto 0) := x"0400";
    signal limit_overshoot : STD_LOGIC_VECTOR (15 downto 0) := x"1000";
    signal lim_out_gain : STD_LOGIC_VECTOR (17 downto 0) := "00" & x"1FFF";
--    signal phase_accumulator : std_logic_vector(15 downto 0) := (others => '0');  
    signal phase_step : std_logic_vector(15 downto 0) := x"1D9A"; -- 1850 Hz
    signal phase_step_valid, phase_step_change  : STD_LOGIC := '0';   
    signal dds_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0); 
    signal dds_tvalid : STD_LOGIC;
    
    signal fir_reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others => '0');
    signal fir_reload_tvalid : STD_LOGIC := '0';
    signal fir_reload_tlast : STD_LOGIC := '0';
    signal fir_config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal fir_config_tvalid : STD_LOGIC := '0';
    signal fir_coeff : integer range 0 to 63 := 0;
    signal fir_delay : integer range 0 to 8191 := 0;
    
    signal iq_out_0, iq_out_1 : std_logic_vector(41 downto 0);
    signal iq_out_tdata : std_logic_vector(47 downto 0);
    signal iq_out_valid : STD_LOGIC := '0';
    signal lim_en : STD_LOGIC := '1';
	
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
	    
	    if fir_delay < 7680 and fir_delay /= 0 then -- �������� ����� �������� �� 1 �����
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
                    elsif fir_coeff = 30 then  -- ������ ������������, ������ 32 ������������
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
	   if s_axis_audio_tvalid = '1' then
	       phase_step_valid <= '0';
	       if phase_step_change = '1' then
	           phase_step_change <= '0';
	           phase_step_valid <= '1';
	       end if;
	   end if;
	   if s_axis_cfg_tvalid = '1' then 
          if s_axis_cfg_tdest = "000" then
             lim_in_gain <= s_axis_cfg_tdata(17 downto 0); 
          elsif s_axis_cfg_tdest = "001" then
             lim_limit <= s_axis_cfg_tdata(15 downto 0);
          elsif s_axis_cfg_tdest = "010" then
             lim_out_gain <= s_axis_cfg_tdata(17 downto 0);
          elsif s_axis_cfg_tdest = "011" then
             phase_step <= s_axis_cfg_tdata(15 downto 0);
             phase_step_change <= '1';
          elsif s_axis_cfg_tdest = "100" then
             limit_overshoot <= s_axis_cfg_tdata(15 downto 0);
          elsif s_axis_cfg_tdest = "110" then
             lim_en <= s_axis_cfg_tdata(0);
          end if;   
	   end if;    
	end if;
end process;

dds_0 : dds_16
    PORT MAP (
        aclk => s_axis_audio_tvalid,
        s_axis_config_tvalid => phase_step_valid,
        s_axis_config_tdata => phase_step,
        m_axis_data_tvalid => dds_tvalid,
        m_axis_data_tdata => dds_tdata,
        m_axis_phase_tvalid => open,
        m_axis_phase_tdata => open
    );

fir_in_0: component lim_eq_fir
    port map (
        aclk => aclk,
        m_axis_data_tdata => fir1_tdata,
        m_axis_data_tvalid => fir1_tvalid,
        s_axis_data_tdata => s_axis_audio_tdata,
        s_axis_data_tready => open,
        s_axis_data_tvalid => s_axis_audio_tvalid
    );
    
    multin_tdata <= s_axis_audio_tdata when lim_en = '0' else fir1_tdata;
    multout_tvalid <= s_axis_audio_tvalid when lim_en = '0' else fir1_tvalid;
 
    
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
        dds_data => dds_tdata,
        dds_tvalid => dds_tvalid,
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
        over => lim_over(2),
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
        over => lim_over(3),
        denom_dbg => denom_dbg,
        aclk => aclk
    );
    
    mult2in_tdata <= limiter_tdata when lim_en = '0' else overshoot_out_tdata;
    mult2in_tvalid <= limiter_tvalid when lim_en = '0' else overshoot_out_tvalid;
        
process(aclk)
begin
	if rising_edge(aclk) then   
	   mult2in_tvalid_r <= mult2in_tvalid;
	   iq_out_valid <= mult2in_tvalid_r;
	   iq_out_0 <= mult2in_tdata(47 downto 24) * lim_out_gain;
       iq_out_1 <= mult2in_tdata(23 downto 0) * lim_out_gain;
	   if iq_out_0(41 downto 35) = "1111111" or iq_out_0(41 downto 35) = "0000000" then
	       lim_over(1) <= '0'; 
	       iq_out_tdata(47 downto 24) <= iq_out_0(35 downto 12);
	   elsif  iq_out_0(41) = '0' then 
	       lim_over(1) <= '1'; 
	       iq_out_tdata(47 downto 24) <= x"7FFFFF";
	   else
	       lim_over(1) <= '1'; 
	       iq_out_tdata(47 downto 24) <= x"800000";
	   end if;   
       if iq_out_1(41 downto 35) = "1111111" or iq_out_1(41 downto 35) = "0000000" then
	       lim_over(1) <= '0'; 
	       iq_out_tdata(23 downto 0) <= iq_out_1(35 downto 12);
	   elsif  iq_out_1(41) = '0' then 
	       lim_over(1) <= '1'; 
	       iq_out_tdata(23 downto 0) <= x"7FFFFF";
	   else
	       lim_over(1) <= '1'; 
	       iq_out_tdata(23 downto 0) <= x"800000";
	   end if;  
	end if;
end process;

    m_axis_iq_tvalid <= iq_out_valid;
    m_axis_iq_tdata <= iq_out_tdata;
    
iq2a_0 : lim_iq2a
    port map (
        m_axis_audio_tdata => m_axis_audio_tdata,
        m_axis_audio_tvalid => m_axis_audio_tvalid,
        s_axis_iq_tdata => iq_out_tdata,
        s_axis_iq_tvalid => iq_out_valid,
        dds_data => dds_tdata,
        dds_tvalid => dds_tvalid,
        aclk => aclk
    );

    
end Behavioral;
