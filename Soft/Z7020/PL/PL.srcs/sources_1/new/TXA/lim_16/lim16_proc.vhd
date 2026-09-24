----------------------------------------------------------------------------------
-- input data 24 bits 16KSamples
-- output data 24 bits 16KSamples
-- cfg
-- 0 lim_in_gain default "00" & x"3FFF"
-- 1 lim_limit default x"0400"
-- 2 lim_out_gain default "00" & x"1FFF",
-- 3 phase_step пїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ default x"1D9A"  -- 1850 Hz
-- 4 limit_overshoot default x"1000"
-- 5 пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ LP FIR
-- 6 CTRL bit 0 - enable
-- пїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅ lim_out_gain пїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅ - пїЅпїЅпїЅпїЅ lim_limit пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ пїЅ 2 пїЅпїЅпїЅпїЅ, пїЅпїЅпїЅпїЅ пїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅпїЅ lim_out_gain пїЅ 2 пїЅпїЅпїЅпїЅ
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim16_proc is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (6 downto 0);
        aclk : in STD_LOGIC
    );
end lim16_proc;

architecture Behavioral of lim16_proc is

    component lim16_eq_fir is
    port (
        aclk : in STD_LOGIC;
        s_axis_data_tvalid : in STD_LOGIC;
        s_axis_data_tready : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
        m_axis_data_tvalid : out STD_LOGIC;
        m_axis_data_tdata : out STD_LOGIC_VECTOR ( 23 downto 0 )
    );
    end component lim16_eq_fir;
    
    component gain16_24_lim is
    generic (
        G_DATA_IN_WIDTH  : integer := 24; -- Разрядность входного сигнала
        G_GAIN_WIDTH     : integer := 16; -- Разрядность коэффициента усиления
        G_DATA_OUT_WIDTH : integer := 16; -- Разрядность выходного сигнала
        G_SHIFT_BITS     : integer := 13  -- Сколько бит отбрасываем (дробная часть КУ)
    );
    port (
        aclk              : in  std_logic;
        multin_tdata      : in  std_logic_vector(G_DATA_IN_WIDTH-1 downto 0);
        multin_tvalid     : in  std_logic;
        gain             : in  std_logic_vector(G_GAIN_WIDTH-1 downto 0);
        multout_tdata     : out std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0);
        multout_tvalid    : out std_logic;
        over              : out std_logic_vector(0 downto 0)
    );
    end component gain16_24_lim;

    COMPONENT lim16_a2iq is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (15 downto 0);
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
    END COMPONENT lim16_a2iq;
	
	COMPONENT lim16_limiter is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (31 downto 0);
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
    END COMPONENT lim16_limiter;
    
    COMPONENT lim16_overshoot is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (31 downto 0);
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
    END COMPONENT lim16_overshoot;
    
    COMPONENT lim16_iq2a is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC; 
        dds_cfg_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_cfg_tvalid : in STD_LOGIC;
        over : out STD_LOGIC;
        aclk : in STD_LOGIC
    );
    END COMPONENT lim16_iq2a;
    
    signal divisor_dbg : std_logic_vector(15 downto 0); 
    signal denom_dbg : std_logic_vector(15 downto 0); 
	
	signal fir1_tdata : std_logic_vector(23 downto 0); 
    signal fir1_tvalid : std_logic;  
    signal lim_in_tdata : std_logic_vector(15 downto 0);
    signal lim_in_tvalid : std_logic := '0';
	signal limiter_tdata : std_logic_vector(31 downto 0);
    signal limiter_tvalid : std_logic;
    signal limiter_out_tdata : std_logic_vector(31 downto 0);
    signal limiter_out_tvalid : std_logic;
    signal overshoot_out_tdata : std_logic_vector(31 downto 0);
    signal overshoot_out_tvalid : std_logic;
    
    signal lim_in_gain : std_logic_vector(15 downto 0) := x"1FFF";
    signal lim_limit : STD_LOGIC_VECTOR (15 downto 0) := x"0400";
    signal limit_overshoot : STD_LOGIC_VECTOR (15 downto 0) := x"1000";
    signal lim_out_gain : std_logic_vector(15 downto 0) := x"1FFF"; -- mult 1.2

    signal dds_a2iq_cfg : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00001D9A"; -- 1850 Hz 
    signal dds_iq2a_cfg : STD_LOGIC_VECTOR(31 DOWNTO 0) := x"00001D9A"; -- 1850 Hz 
    signal dds_cfg_tvalid : STD_LOGIC := '0';
    
    signal fir_reload_tdata : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others => '0');
    signal fir_reload_tvalid : STD_LOGIC := '0';
    signal fir_reload_tlast : STD_LOGIC := '0';
    signal fir_config_tdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal fir_config_tvalid : STD_LOGIC := '0';
    signal fir_coeff : integer range 0 to 63 := 0;
    signal fir_delay : integer range 0 to 8191 := 0;
    
    signal audio_tdata_reg : STD_LOGIC_VECTOR (23 downto 0);
    signal audio_tvalid_reg : STD_LOGIC := '0';
	
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
             lim_in_gain <= s_axis_cfg_tdata(15 downto 0); 
          elsif s_axis_cfg_tdest = "001" then
             lim_limit <= s_axis_cfg_tdata(15 downto 0);
          elsif s_axis_cfg_tdest = "010" then
             lim_out_gain <= s_axis_cfg_tdata(15 downto 0);
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

u_fir_in: component lim16_eq_fir
    port map (
        aclk => aclk,
        m_axis_data_tdata => fir1_tdata,
        m_axis_data_tvalid => fir1_tvalid,
        s_axis_data_tdata => s_axis_audio_tdata,
        s_axis_data_tready => open,
        s_axis_data_tvalid => s_axis_audio_tvalid
    );
    
u_in_gain : gain16_24_lim
    generic map(
        G_DATA_IN_WIDTH  => 24,
        G_GAIN_WIDTH     => 16,
        G_DATA_OUT_WIDTH => 16,
        G_SHIFT_BITS     => 21
    )
    port map(
        aclk             => aclk,
        multin_tdata     => fir1_tdata,
        multin_tvalid    => fir1_tvalid,
        gain             => lim_in_gain,
        multout_tdata    => lim_in_tdata,
        multout_tvalid   => lim_in_tvalid,
        over             => lim_over(0 downto 0)
    );

u_a2iq : lim16_a2iq
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
	
u_clipper : lim16_limiter
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
  
u_overshoot : lim16_overshoot
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
       
u_iq2a : lim16_iq2a
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
    
u_out_gain : gain16_24_lim
    generic map(
        G_DATA_IN_WIDTH  => 24,
        G_GAIN_WIDTH     => 16,
        G_DATA_OUT_WIDTH => 16,
        G_SHIFT_BITS     => 18
    )
    port map(
        aclk             => aclk,
        multin_tdata     => audio_tdata_reg,
        multin_tvalid    => audio_tvalid_reg,
        gain             => lim_out_gain,
        multout_tdata    => m_axis_audio_tdata,
        multout_tvalid   => m_axis_audio_tvalid,
        over             => lim_over(1 downto 1)
    );

end Behavioral;
