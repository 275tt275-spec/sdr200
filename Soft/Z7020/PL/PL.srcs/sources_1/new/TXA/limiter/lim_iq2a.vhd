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
        dds_cfg_data : in STD_LOGIC_VECTOR (31 downto 0);
        dds_cfg_tvalid : in STD_LOGIC;
        over : out STD_LOGIC;
        aclk : in STD_LOGIC
    );
end lim_iq2a;

architecture Behavioral of lim_iq2a is

COMPONENT dds_16_16_ph IS
  PORT (
    aclk : IN STD_LOGIC;
    aclken : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT dds_16_16_ph;

COMPONENT cmpy_16_24
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_ctrl_tvalid : IN STD_LOGIC;
    s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
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

    signal dds_tvalid : STD_LOGIC;
    signal dds_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal dds_config_tdata_reg : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal dds_config_tvalid_reg : STD_LOGIC := '0';
    signal dds_config_tvalid : STD_LOGIC := '0';
    signal multin_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal multout_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal multout_tvalid : std_logic;	
    signal summa_tdata : std_logic_vector(23 downto 0);
	signal fir_out_tdata : std_logic_vector(31 downto 0);
	signal fir_out_tvalid : std_logic;
--	signal multout40_tdata_0, multout40_tdata_1 : STD_LOGIC_VECTOR(39 DOWNTO 0);
    signal m_axis_audio_tvalid_reg : std_logic := '0';
    -- Константа сдвига для компенсации затухания.
    -- GAIN_SHIFT = 0 -> срез (31 downto 8) [базовый]
    -- GAIN_SHIFT = 1 -> срез (30 downto 7) [+6 дБ усиления]
    -- GAIN_SHIFT = 2 -> срез (29 downto 6) [+12 дБ усиления] -- Выбрано по умолчанию
    -- GAIN_SHIFT = 3 -> срез (28 downto 5) [+18 дБ усиления]
    constant GAIN_SHIFT : integer := 3;     
    signal ch_24 : std_logic_vector(23 downto 0) := (others => '0');
    signal ch_24_valid : std_logic;
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0) := (others => '0');

begin

    multin_tdata <= s_axis_iq_tdata(23 downto 0) & s_axis_iq_tdata(47 downto 24);
    
process(aclk)
begin
    if rising_edge(aclk) then
        if dds_cfg_tvalid = '1' then
           dds_config_tvalid_reg  <= '1'; 
           dds_config_tdata_reg <= dds_cfg_data;
        end if;
        if s_axis_iq_tvalid = '1' and dds_config_tvalid_reg = '1' then
            dds_config_tvalid_reg <= '0';
        end if;    
        -- Классический полином LFSR x^16 + x^14 + x^13 + x^11 + 1
        lfsr_reg <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);
    end if;
end process;

    ctrl_tdata(0) <= lfsr_reg(0); -- Подаем случайный бит в нулевой разряд
    ctrl_tdata(7 downto 1) <= (others => '0');
    dds_config_tvalid <= dds_config_tvalid_reg when s_axis_iq_tvalid = '1' else '0';
    
dds_0 : dds_16_16_ph
  PORT MAP (
    aclk => aclk,
    aclken => s_axis_iq_tvalid,
    s_axis_config_tvalid => dds_config_tvalid,
    s_axis_config_tdata => dds_config_tdata_reg,
    m_axis_data_tvalid => dds_tvalid,
    m_axis_data_tdata => dds_tdata
  );

mult_0 : cmpy_16_24
  PORT MAP (
    aclk => aclk,
    s_axis_a_tvalid => s_axis_iq_tvalid,
    s_axis_a_tdata => multin_tdata,
    s_axis_b_tvalid => dds_tvalid,
    s_axis_b_tdata => dds_tdata,
    s_axis_ctrl_tvalid => '1',
    s_axis_ctrl_tdata => ctrl_tdata,
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
        m_axis_data_tvalid => fir_out_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );
    
process(aclk)
    variable val : std_logic_vector(31 downto 0);
    variable sign : std_logic;
    variable overflow : boolean;
begin
    if rising_edge(aclk) then
        -- По умолчанию сбрасываем валидность шины Stream
        m_axis_audio_tvalid_reg <= '0';
        over <= '0';
        
        if fir_out_tvalid = '1' then
            ch_24_valid <= '1';
            val := fir_out_tdata;           
            sign := val(31);
            overflow := false;
            for i in 31 downto (31 - GAIN_SHIFT) loop
                if val(i) /= sign then
                    overflow := true;
                end if;
            end loop;
            if overflow then
                over <= '1';
                if sign = '0' then
                    ch_24 <= x"7FFFFF"; -- Максимум в плюс
                else
                    ch_24 <= x"800000"; -- Максимум в минус
                end if;
            else
                ch_24 <= val((31 - GAIN_SHIFT) downto (8 - GAIN_SHIFT));
            end if;
        else
           ch_24_valid <= '0';     
        end if;
        m_axis_audio_tdata <= ch_24;
        m_axis_audio_tvalid_reg <= ch_24_valid;
    end if;
end process;
    
    m_axis_audio_tvalid <= m_axis_audio_tvalid_reg;
 --   m_axis_audio_tdata <= fir_out_tdata(31) & fir_out_tdata(28 downto 6);

end Behavioral;
