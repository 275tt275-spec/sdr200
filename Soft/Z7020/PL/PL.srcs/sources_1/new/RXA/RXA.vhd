----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.05.2025 20:15:48
-- Design Name: 
-- Module Name: RXA - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity RXA is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc0_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc0_tvalid : in STD_LOGIC;
        s_axis_adc1_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc1_tvalid : in STD_LOGIC;
        m_axis_wb_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tlast : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        m_axis_nb0_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_nb0_tvalid : out STD_LOGIC;
        m_axis_nb0_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_nb1_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_nb1_tvalid : out STD_LOGIC;
        m_axis_nb1_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_demod_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_demod_tvalid : out STD_LOGIC;
		cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
		cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;
        out_clk : out STD_LOGIC
    );
end RXA;

architecture Behavioral of RXA is

   COMPONENT RXA_wide is
     Port ( 
        m_axis_wb_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
    END COMPONENT  RXA_wide;
    
    COMPONENT RXA_channel
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
	END COMPONENT RXA_channel;
	
	COMPONENT fos is
        Port ( 
           aclk : in  STD_LOGIC;     
           s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0);
           s_axis_tvalid : in STD_LOGIC;
           m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
           m_axis_tuser : out STD_LOGIC_VECTOR (0 downto 0);
           m_axis_tvalid : out STD_LOGIC;
           s_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
           s_cfg_tvalid : in STD_LOGIC 
    );
    END COMPONENT  fos;
    
    COMPONENT cordic_rssi IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
        );
    END COMPONENT cordic_rssi;
    
    COMPONENT agc IS
        PORT (
            aclk : in STD_LOGIC;
            s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
            s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0);
            s_axis_tvalid : in std_logic;
            m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
            m_axis_tuser : out STD_LOGIC_VECTOR (0 downto 0);
            m_axis_tvalid : out std_logic;
            cfg_addra : in STD_LOGIC_VECTOR (2 downto 0);
            cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
            cfg_wr : in STD_LOGIC
        );
    END COMPONENT agc;
    
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
    END COMPONENT RXA_demod;
    
    COMPONENT dc_removal_24 is
    port(
        -- The clock domain used for all interfaces.
        clk : in std_logic;
    
        -- synchronous reset
        rst : in std_logic;
    
        -- enable automatic removal
        enable : in std_logic;
    
        -- input bus interface
        in_tdata : in std_logic_vector(23 downto 0);
        in_tvalid : in std_logic;
        in_tready : out std_logic;
    
        -- output bus interface
        out_tdata : out std_logic_vector(23 downto 0);
        out_tvalid : out std_logic;
        out_tready : in std_logic
    );
    END COMPONENT dc_removal_24;
    
    COMPONENT audio_filter IS
    Port ( 
        aclk : in STD_LOGIC;
        s_axis_in_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_in_tvalid : in STD_LOGIC;
        m_axis_out_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_out_tvalid : out STD_LOGIC;
        cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC);
    END COMPONENT audio_filter;
    
    COMPONENT  clock_converter_4 IS
    Port (
        s_axis_aresetn : in STD_LOGIC;
        m_axis_aresetn : in STD_LOGIC;
        s_axis_aclken : in STD_LOGIC;
        m_axis_aclken : in STD_LOGIC;
        s_axis_aclk : in STD_LOGIC;
        s_axis_tvalid : in STD_LOGIC;
        s_axis_tready : out STD_LOGIC;
        s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0);
        m_axis_aclk : in STD_LOGIC;
        m_axis_tvalid : out STD_LOGIC;
        m_axis_tready : in STD_LOGIC;
        m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_tuser : out STD_LOGIC_VECTOR (0 downto 0));
    END COMPONENT clock_converter_4;

    signal wide_out_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal wide_out_tvalid : STD_LOGIC;
    signal dds_wf, dds_nr : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal dds_wf_valid, dds_nr_valid  : STD_LOGIC := '0';
    
    signal narrow_out0_tdata, narrow_out1_tdata : STD_LOGIC_VECTOR (31 downto 0);
	signal narrow_out0_tuser, narrow_out1_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal narrow_out0_tvalid, narrow_out1_tvalid : STD_LOGIC;
    signal fos_out_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal fos_out_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal fos_out_tvalid : STD_LOGIC;
    signal fos_cfg_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal fos_cfg_tdest : STD_LOGIC_VECTOR (0 downto 0);
    signal fos_cfg_tvalid : STD_LOGIC;
    signal low_out_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal low_out_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal low_out_tvalid : STD_LOGIC;
    signal modulation : STD_LOGIC_VECTOR (1 downto 0) := "00";
    signal j3e_lsb : STD_LOGIC := '0';
    signal dds_config_16_data : STD_LOGIC_VECTOR (15 downto 0);
    signal dds_config_16_valid : STD_LOGIC := '0';
    signal demod_in_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal demod_in_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal demod_in_tvalid : STD_LOGIC;
    signal demod_s24_out_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal demod_s24_out_tvalid : STD_LOGIC;
    signal rssi_s32_out_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal rssi_s32_out_tvalid : STD_LOGIC; 
    signal s_axis_cartesian_tvalid : STD_LOGIC;
    signal s_axis_cartesian_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal temp_i : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal m_axis_dout_tvalid : STD_LOGIC;
    signal m_axis_dout_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);  
    signal real_rssi_tdata : STD_LOGIC_VECTOR (31 downto 0); 
    signal agc_cfg_wr : STD_LOGIC := '0';
    signal audio_clk : STD_LOGIC;

begin

    cfg_douta <= real_rssi_tdata;
    out_clk <= audio_clk;
    
cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        fos_cfg_tvalid <= '0'; 
        dds_wf_valid <= '0'; 
        dds_nr_valid <= '0'; 
        dds_config_16_valid <= '0';
        agc_cfg_wr <= '0';
        if cfg_wr = '1' then   
            if cfg_addra = x"00" then
                dds_nr <= cfg_dina;
                dds_nr_valid <= '1';
            elsif cfg_addra = x"01" then
                modulation <= cfg_dina(1 downto 0);      
            elsif cfg_addra = x"02" then
                j3e_lsb <= cfg_dina(0);     
            elsif cfg_addra = x"03" then
                fos_cfg_tdest <= "1";
                fos_cfg_tvalid <= '1';  
            elsif cfg_addra = x"04" then
                fos_cfg_tdest <= "0";
                fos_cfg_tvalid <= '1';  
            elsif cfg_addra = x"05" then
                dds_config_16_data <= cfg_dina(15 downto 0); 
                dds_config_16_valid <= '1';
            elsif cfg_addra = x"06" then
                dds_wf <= cfg_dina;  
                dds_wf_valid <= '1';   
            elsif cfg_addra(7 downto 4) = x"2" then
                agc_cfg_wr <= '1';
            end if; 
        end if;
   end if;
end process cmd_process;
    
wide_0 : RXA_wide
    PORT MAP  (
        m_axis_wb_tdata => wide_out_tdata,
        m_axis_wb_tvalid => wide_out_tvalid,
        m_axis_wb_tready => m_axis_wb_tready,
        s_axis_signal_tdata => s_axis_adc0_tdata,
        dds_value => dds_wf,
        dds_valid => dds_wf_valid,
        aresetn => aresetn,
        aclk => aclk
);

    m_axis_wb_tdata <= wide_out_tdata;
    m_axis_wb_tvalid <= wide_out_tvalid;
    m_axis_wb_tlast <= '1';

-- input 122.88 MZz output 16 KSamples
narrow_0 : RXA_channel
    PORT MAP  (
        m_axis_data_tdata => narrow_out0_tdata,
        m_axis_data_tuser => narrow_out0_tuser,
        m_axis_data_tvalid => narrow_out0_tvalid,
        s_axis_signal_tdata => s_axis_adc0_tdata,
        dds_value => dds_nr,
        dds_valid => dds_nr_valid,
        aresetn => aresetn,
        aclk => aclk
    );
    
narrow_1 : RXA_channel
    PORT MAP  (
        m_axis_data_tdata => narrow_out1_tdata,
        m_axis_data_tuser => narrow_out1_tuser,
        m_axis_data_tvalid => narrow_out1_tvalid,
        s_axis_signal_tdata => s_axis_adc1_tdata,
        dds_value => dds_nr,
        dds_valid => dds_nr_valid,
        aresetn => aresetn,
        aclk => aclk
    );
    
-- output 16 KSamples
    
    m_axis_nb0_tdata <= narrow_out0_tdata;
    m_axis_nb0_tvalid <= narrow_out0_tvalid;
    m_axis_nb0_tuser <= narrow_out0_tuser;
    m_axis_nb1_tdata <= narrow_out1_tdata;
    m_axis_nb1_tvalid <= narrow_out1_tvalid;
    m_axis_nb1_tuser <= narrow_out1_tuser;
    fos_cfg_tdata <= cfg_dina;
    
narrow_fos_0 : fos
    PORT MAP  (
       aclk => aclk,        
       s_axis_tdata => narrow_out0_tdata,
       s_axis_tuser => narrow_out0_tuser,
       s_axis_tvalid => narrow_out0_tvalid,
       m_axis_tdata => fos_out_tdata,
       m_axis_tuser => fos_out_tuser,
       m_axis_tvalid => fos_out_tvalid,
       s_cfg_tdata => fos_cfg_tdata,
       s_cfg_tdest => fos_cfg_tdest,
       s_cfg_tvalid => fos_cfg_tvalid
   );
   
-- 16 KSamples

process(aclk)
begin
	if rising_edge(aclk) then	
	    s_axis_cartesian_tvalid <= '0';	
		if fos_out_tvalid = '1' then
		    if fos_out_tuser = "0" then				   		
			    --s_axis_cartesian_tdata(31 downto 0) <= fos_out_tdata(31) & fos_out_tdata(31 downto 1);  
			    -- Сохраняем I во временный регистр
                temp_i <= fos_out_tdata(31) & fos_out_tdata(31 downto 1); 
			else
			    --s_axis_cartesian_tdata(63 downto 32) <= fos_out_tdata(31) & fos_out_tdata(31 downto 1);
			    -- Собираем полный вектор I+Q и даем валид
			    s_axis_cartesian_tdata <= fos_out_tdata(31) & fos_out_tdata(31 downto 1) & temp_i;
			    s_axis_cartesian_tvalid <= '1';
			end if;    	           
		end if;  
		if m_axis_dout_tvalid = '1' then
		    real_rssi_tdata <= m_axis_dout_tdata(31 downto 0);
		end if;
	end if;
end process;    
                 
rssi_0 : cordic_rssi
    PORT MAP(
        aclk => aclk,
        s_axis_cartesian_tvalid => s_axis_cartesian_tvalid,
        s_axis_cartesian_tdata => s_axis_cartesian_tdata,
        m_axis_dout_tvalid => m_axis_dout_tvalid,
        m_axis_dout_tdata => m_axis_dout_tdata
    );
    
BUFG_audio : BUFG
port map (
   O => audio_clk,
   I => aclk
);

clock_0 : clock_converter_4
    PORT MAP (
        s_axis_aresetn => aresetn,
        m_axis_aresetn => '1',
        s_axis_aclken => '1',
        m_axis_aclken => '1',
        s_axis_aclk => aclk,
        s_axis_tvalid => fos_out_tvalid,
        s_axis_tready => open,
        s_axis_tdata => fos_out_tdata,
        s_axis_tuser => fos_out_tuser,
        m_axis_aclk => audio_clk,
        m_axis_tvalid => low_out_tvalid,
        m_axis_tready => '1',
        m_axis_tdata => low_out_tdata,
        m_axis_tuser => low_out_tuser
    );
    
agc_0 : agc
    PORT MAP (
        aclk => audio_clk,
        s_axis_tdata => low_out_tdata,
        s_axis_tuser => low_out_tuser,
        s_axis_tvalid => low_out_tvalid,
        m_axis_tdata => demod_in_tdata,
        m_axis_tuser => demod_in_tuser,
        m_axis_tvalid => demod_in_tvalid,
        cfg_addra => cfg_addra(2 downto 0),
        cfg_dina => cfg_dina,
        cfg_wr => agc_cfg_wr
    );

--    gain_data <= fos_out_tdata * agc_gain(17 downto 2);                 
                    
demodulator_0 : RXA_demod
    PORT MAP  (
        aclk => audio_clk,    
        s_axis_tdata => demod_in_tdata,
        s_axis_tuser => demod_in_tuser,
        s_axis_tvalid => demod_in_tvalid,    
        m_axis_demod_tdata => demod_s24_out_tdata,
        m_axis_demod_tvalid => demod_s24_out_tvalid,
        m_axis_rssi_tdata => rssi_s32_out_tdata,
        m_axis_rssi_tvalid => rssi_s32_out_tvalid,
        dds_config_16_data => dds_config_16_data,
        dds_config_16_valid => dds_config_16_valid,
        modulation => modulation,
        j3e_lsb => j3e_lsb
   );
    
audio_filter_0 : audio_filter
    PORT MAP ( 
        aclk => audio_clk,
        s_axis_in_tdata => demod_s24_out_tdata,
        s_axis_in_tvalid => demod_s24_out_tvalid,
        m_axis_out_tdata => m_axis_demod_tdata,
        m_axis_out_tvalid => m_axis_demod_tvalid,
        cfg_addra => cfg_addra,
        cfg_dina => cfg_dina,
        cfg_wr => cfg_wr
    );   

end Behavioral;
