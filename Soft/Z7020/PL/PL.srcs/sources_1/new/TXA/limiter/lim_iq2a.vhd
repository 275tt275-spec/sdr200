----------------------------------------------------------------------------------
-- Return IQ to Audio for AM and FM modulation
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim_iq2a is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC; 
        phase_accum : in STD_LOGIC_VECTOR (15 downto 0);
        aclk : in STD_LOGIC
    );
end lim_iq2a;

architecture Behavioral of lim_iq2a is

COMPONENT lim_rotate24_24_cordic
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_phase_tvalid : IN STD_LOGIC;
        s_axis_phase_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_cartesian_tvalid : IN STD_LOGIC;
        s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
END COMPONENT lim_rotate24_24_cordic;

component audio_base_fir is
    port (
        aclk : in STD_LOGIC;
        s_axis_data_tvalid : in STD_LOGIC;
        s_axis_data_tready : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR ( 23 downto 0 );
        m_axis_data_tvalid : out STD_LOGIC;
        m_axis_data_tdata : out STD_LOGIC_VECTOR ( 31 downto 0 )
    );
end component audio_base_fir;

    signal cordic_phase : std_logic_vector(23 downto 0);
    signal cordic_in_data : std_logic_vector(47 downto 0) := (others => '0');
	signal cordic_out_tdata : std_logic_vector(47 downto 0);
	signal summa_tdata : std_logic_vector(23 downto 0);
	signal fir_out_tdata : std_logic_vector(31 downto 0);
	signal cordic_out_tvalid : std_logic;

begin

    cordic_phase <= phase_accum(15) & phase_accum(15) & phase_accum(15 downto 0) & "000000";
    cordic_in_data <= s_axis_iq_tdata(23) & s_axis_iq_tdata(23 downto 1) & s_axis_iq_tdata(47) & s_axis_iq_tdata(47 downto 25);

cordic_0 : lim_rotate24_24_cordic
    PORT MAP (
        aclk => aclk,
        s_axis_phase_tvalid => '1',
        s_axis_phase_tdata => cordic_phase,
        s_axis_cartesian_tvalid => s_axis_iq_tvalid,
        s_axis_cartesian_tdata => cordic_in_data,
        m_axis_dout_tvalid => cordic_out_tvalid,
        m_axis_dout_tdata => cordic_out_tdata
    );
	
	summa_tdata <= cordic_out_tdata(47 downto 24) + cordic_out_tdata(23 downto 0);
	
fir_0 : audio_base_fir
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => cordic_out_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => summa_tdata,
        m_axis_data_tvalid => m_axis_audio_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );

    m_axis_audio_tdata <= fir_out_tdata(31) & fir_out_tdata(28 downto 6);

end Behavioral;
