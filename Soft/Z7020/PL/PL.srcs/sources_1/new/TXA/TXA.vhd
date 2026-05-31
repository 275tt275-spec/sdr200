----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04.07.2025 12:23:15
-- Design Name: 
-- Module Name: TXA - Behavioral
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

entity TXA is
    Port ( 
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        s_adc_data_rx0 : in std_logic_vector(15 downto 0);
        s_adc_data_rx1 : in std_logic_vector(15 downto 0);
        DAC_DCI_N : out STD_LOGIC;
        DAC_DCI_P : out STD_LOGIC;
        DAC_DCO_P : in STD_LOGIC;
        DAC_DCO_N : in STD_LOGIC;
        DAC_D_N : out STD_LOGIC_VECTOR ( 15 downto 0 );
        DAC_D_P : out STD_LOGIC_VECTOR ( 15 downto 0 );
		cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
		cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end TXA;

architecture Behavioral of TXA is

component TXA_channel is
    Port ( 
        m_daci_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_dacq_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        s_adc_data_rx0 : in std_logic_vector(15 downto 0);
        s_adc_data_rx1 : in std_logic_vector(15 downto 0);
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (7 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        cfg_data_out : out STD_LOGIC_VECTOR (31 downto 0);
        aresetn : in std_logic;
        aclk : in std_logic
    );
    end component TXA_channel;

component dac_out is
    Port (
       aclk : in STD_LOGIC;
       aresetn : in STD_LOGIC;
       s_daci_tdata : in STD_LOGIC_VECTOR (15 downto 0);
       s_dacq_tdata : in STD_LOGIC_VECTOR (15 downto 0);
       m_dout_p : out STD_LOGIC_VECTOR (15 downto 0);
       m_dout_n : out STD_LOGIC_VECTOR (15 downto 0);
       m_dci_p : out STD_LOGIC;
       m_dci_n : out STD_LOGIC;
       s_dco_p : in STD_LOGIC;
       s_dco_n : in STD_LOGIC
    );
    end component dac_out;
    
    signal daci_tdata, dacq_tdata : STD_LOGIC_VECTOR ( 15 downto 0 );

begin

TXA_channel_0 : TXA_channel
    port map ( 
        m_daci_tdata => daci_tdata,
        m_dacq_tdata => dacq_tdata,
        s_axis_audio_tdata => s_axis_audio_tdata,
        s_axis_audio_tvalid => s_axis_audio_tvalid,
        s_adc_data_rx0 => s_adc_data_rx0,
        s_adc_data_rx1 => s_adc_data_rx1,
        s_axis_cfg_tdata => cfg_dina,
        s_axis_cfg_tdest => cfg_addra,
        s_axis_cfg_tvalid => cfg_wr,
        cfg_data_out => cfg_douta,
        aresetn => aresetn,
        aclk => aclk
    );

dac_out_0 : dac_out
    port map (
       aclk => aclk,
       aresetn => aresetn,
       s_daci_tdata => daci_tdata,
       s_dacq_tdata => dacq_tdata,
       m_dout_p => DAC_D_P,
       m_dout_n => DAC_D_N,
       m_dci_p => DAC_DCI_P,
       m_dci_n => DAC_DCI_N,
       s_dco_p => DAC_DCO_P,
       s_dco_n => DAC_DCO_N
    );

end Behavioral;
