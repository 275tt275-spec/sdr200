----------------------------------------------------------------------------------
-- Return IQ to Audio for AM and FM modulation
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

entity lim_iq2a is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_iq_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_iq_tvalid : in STD_LOGIC; 
        dds_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_tvalid : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end lim_iq2a;

architecture Behavioral of lim_iq2a is

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

    signal multin_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal multout_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal multout_tvalid : std_logic;	
    signal summa_tdata : std_logic_vector(23 downto 0);
	signal fir_out_tdata : std_logic_vector(31 downto 0);
--	signal multout40_tdata_0, multout40_tdata_1 : STD_LOGIC_VECTOR(39 DOWNTO 0);

begin

    multin_tdata <= s_axis_iq_tdata(23 downto 0) & s_axis_iq_tdata(47 downto 24);

mult_0 : cmpy_16_24
  PORT MAP (
    aclk => aclk,
    s_axis_a_tvalid => s_axis_iq_tvalid,
    s_axis_a_tdata => multin_tdata,
    s_axis_b_tvalid => '1',
    s_axis_b_tdata => dds_data,
    m_axis_dout_tvalid => multout_tvalid,
    m_axis_dout_tdata => multout_tdata
  );

 --   multout40_tdata_0 <= s_axis_iq_tdata(47 downto 24) * dds_data(31 downto 16);
 --   multout40_tdata_1 <= s_axis_iq_tdata(23 downto 0) * dds_data(15 downto 0);
 --   summa_tdata <= multout40_tdata_0(39 downto 16) + multout40_tdata_1(39 downto 16);
 --   multout_tvalid <= s_axis_iq_tvalid;
 	
  summa_tdata <= multout_tdata(47 downto 24) + multout_tdata(23 downto 0);
	
fir_0 : audio_base_fir
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => multout_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => summa_tdata,
        m_axis_data_tvalid => m_axis_audio_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );

    m_axis_audio_tdata <= fir_out_tdata(31) & fir_out_tdata(28 downto 6);

end Behavioral;
