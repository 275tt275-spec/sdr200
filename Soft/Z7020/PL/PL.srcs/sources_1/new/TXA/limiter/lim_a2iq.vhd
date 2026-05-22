----------------------------------------------------------------------------------
-- Weaver SSB modulator
-- преобразование Уивера
-- на входе 24 бита 16 KSamples аудио
-- на выходе 47 бит IQ 16 KSamples
-- phase_accum текущее значение фазы чвтоты преобразования (default 1850 Hz)
-- По адресу 0x4 загрузка фильтра LPF (симметричный на 64 taps)
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

entity lim_a2iq is
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
        aclk : in STD_LOGIC );
end lim_a2iq;

architecture Behavioral of lim_a2iq is

COMPONENT cmpy_16_24
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
  );
END COMPONENT cmpy_16_24;

COMPONENT lim_lpf_fir IS
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
END COMPONENT  lim_lpf_fir;

    signal mult_in_data : std_logic_vector(47 downto 0);
    signal firin_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal firin_tvalid : std_logic;
    signal firout_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal firout_tvalid : STD_LOGIC;

begin

    mult_in_data <= s_axis_audio_tdata & s_axis_audio_tdata;

mult_0 : cmpy_16_24
  PORT MAP (
    aclk => aclk,
    s_axis_a_tvalid => s_axis_audio_tvalid,
    s_axis_a_tdata => mult_in_data,
    s_axis_b_tvalid => '1',
    s_axis_b_tdata => dds_data,
    m_axis_dout_tvalid => firin_tvalid,
    m_axis_dout_tdata => firin_tdata
  );

fir_0 : lim_lpf_fir
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => firin_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => firin_tdata,
        s_axis_config_tvalid => fir_config_tvalid,
        s_axis_config_tready => open,
        s_axis_config_tdata => fir_config_tdata,
        s_axis_reload_tvalid => fir_reload_tvalid,
        s_axis_reload_tready => open,
        s_axis_reload_tlast => fir_reload_tlast,
        s_axis_reload_tdata => fir_reload_tdata,
        m_axis_data_tvalid => firout_tvalid,
        m_axis_data_tdata => firout_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
    m_axis_iq_tdata  <= firout_tdata(63) & firout_tdata(54 downto 32) & firout_tdata(31) & firout_tdata(22 downto 0);
    m_axis_iq_tvalid <= firout_tvalid;

end Behavioral;
