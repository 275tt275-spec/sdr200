----------------------------------------------------------------------------------
-- Baseband envelope clipper
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lim16_limiter is
    Port ( 
        m_axis_data_tdata  : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        s_axis_data_tvalid : in  STD_LOGIC; 
        limit              : in  STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata   : in  STD_LOGIC_VECTOR (23 DOWNTO 0);
        fir_reload_tvalid  : in  STD_LOGIC;
        fir_reload_tlast   : in  STD_LOGIC;
        fir_config_tdata   : in  STD_LOGIC_VECTOR (7 DOWNTO 0);
        fir_config_tvalid  : in  STD_LOGIC;
        over               : out STD_LOGIC_VECTOR (1 DOWNTO 0);
        divisor_dbg        : out STD_LOGIC_VECTOR (15 downto 0);  
        aclk               : in  STD_LOGIC
    );
end lim16_limiter;

architecture Behavioral of lim16_limiter is

    component lim16_translate_cordic
        port (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component lim16_translate_cordic;  
    
    COMPONENT lim16_lpf_fir IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_data_tvalid : IN STD_LOGIC;
            s_axis_data_tready : OUT STD_LOGIC;
            s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tready : OUT STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_reload_tvalid : IN STD_LOGIC;
            s_axis_reload_tready : OUT STD_LOGIC;
            s_axis_reload_tlast : IN STD_LOGIC;
            s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(95 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim16_lpf_fir;
    
    COMPONENT signed_round_sat is
    generic (
        IWID       : integer := 37; -- Исходная разрядность данных
        OWID       : integer := 24; -- Выходная разрядность после округления
        SHIFT_LEFT : integer := 0   -- Параметр сдвига данных вверх перед округлением (0, 1, 2 и т.д.)
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;
        i_data  : in  std_logic_vector(IWID-1 downto 0);
        i_valid : in  std_logic;
        o_data  : out std_logic_vector(OWID-1 downto 0);
        o_valid : out std_logic;
        ovf     : out std_logic -- Флаг фиксации переполнения (сатурации)
    );
    END COMPONENT  signed_round_sat;
    
    component lim16_div is
    generic (
        G_BIT_HIGH : integer := 17  -- Позиция старшего (знакового) бита выходного окна (задается снаружи)
    );
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component lim16_div;
     
    signal delay_addr_in: std_logic_vector(4 DOWNTO 0) := "10101"; 
    signal delay_addr_out: std_logic_vector(4 DOWNTO 0) := "00000";  
    signal delay_out_0, delay_out_1 : std_logic_vector(23 downto 0) := (others => '0');   
    
        -- Промежуточные сигналы для IP-ядер
    signal dividend_tdata : std_logic_vector(31 downto 0) := (others => '0');  
    signal cordic_in      : std_logic_vector(31 downto 0);
    signal cordic_out     : std_logic_vector(31 downto 0);
    signal cordic_tvalid  : std_logic;
    signal divin_tvalid   : std_logic := '0';  
    signal divisor        : std_logic_vector(15 downto 0) := x"0001";  
    signal divisor_reg    : std_logic_vector(15 downto 0) := x"0001";  
    signal divout_0       : std_logic_vector(15 downto 0); 
    signal divout_1       : std_logic_vector(15 downto 0); 
    signal divout_valid_0 : std_logic;
    signal divout_valid_1 : std_logic;
    signal div_over_0     : std_logic;
    signal div_over_1     : std_logic;
    signal fir_in_tdata   : std_logic_vector(31 downto 0);
    signal fir_in_tvalid  : std_logic;
    signal fir_out_tdata  : std_logic_vector(95 downto 0);
    signal fir_out_tvalid : std_logic;
    signal inv_div0, inv_div1 : signed(15 downto 0);
    
    constant GAIN_SHIFT : integer := 13;     
    signal ch_a_16_reg, ch_b_16_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal out_valid_reg            : std_logic := '0';
    signal out_over_a, out_over_b   : std_logic := '0';

begin

    divisor_dbg <= divisor;
    cordic_in <= s_axis_data_tdata(31) & s_axis_data_tdata(31 downto 17) & s_axis_data_tdata(15) & s_axis_data_tdata(15 downto 1);
    
    -- Амплитудный CORDIC-процессор (вычисление модуля комплексного сигнала)
    mag_cordic_0 : lim16_translate_cordic
    PORT MAP (
        aclk                    => aclk,
        s_axis_cartesian_tvalid => s_axis_data_tvalid,
        s_axis_cartesian_tdata  => cordic_in, 
        m_axis_dout_tvalid      => cordic_tvalid,
        m_axis_dout_tdata       => cordic_out
    );
    
process(aclk)
begin
    if rising_edge(aclk) then  
        divin_tvalid <= '0';
        -- Фиксация входных IQ данных по входному валиду
        if s_axis_data_tvalid = '1' then
            dividend_tdata <= s_axis_data_tdata;
        end if;
        -- Получение амплитуды из CORDIC и выставление строба для деления
        if cordic_tvalid = '1' then
            divisor_reg  <= std_logic_vector(abs(signed(cordic_out(15 downto 0))));
            divin_tvalid <= '1';
        end if;       
    end if;
end process;

    -- Компаратор ограничения уровня (минимальный делитель равен значению limit)
    divisor <= limit when (unsigned(divisor_reg) < unsigned(limit)) else divisor_reg;    
    
    -- Блок деления для канала А (выделяем верхние 16 бит - Q)
    div_0 : lim16_div
    generic map (
        G_BIT_HIGH => 17
    )
    PORT MAP (
        s_axis_divisor_tvalid  => divin_tvalid,
        s_axis_divisor_tdata   => divisor,
        s_axis_dividend_tvalid => divin_tvalid,
        s_axis_dividend_tdata  => dividend_tdata(31 downto 16),
        m_axis_dout_tvalid     => divout_valid_0,
        m_axis_dout_tdata      => divout_0,
        out_over               => div_over_0,
        aclk                   => aclk
    );
    
    -- Блок деления для канала Б (выделяем нижние 16 бит - I)
    div_1 : lim16_div
    generic map (
        G_BIT_HIGH => 17
    )
    PORT MAP (
        s_axis_divisor_tvalid  => divin_tvalid,
        s_axis_divisor_tdata   => divisor,
        s_axis_dividend_tvalid => divin_tvalid,
        s_axis_dividend_tdata  => dividend_tdata(15 downto 0),
        m_axis_dout_tvalid     => divout_valid_1,
        m_axis_dout_tdata      => divout_1,
        out_over               => div_over_1,
        aclk                   => aclk
    );

    -- ИСПРАВЛЕННЫЙ УНАРНЫЙ МИНУС: Приведение типов к signed исключает ошибку компиляции Vivado.
    -- Математическая инверсия знака выполняется корректно в рамках пакета numeric_std.
    inv_div0 <= -signed(divout_0);
    inv_div1 <= -signed(divout_1);
    -- Склеиваем по 16 старших бит из каждого инвертированного канала
    fir_in_tdata <= std_logic_vector(inv_div0) & std_logic_vector(inv_div1);
    fir_in_tvalid <= divout_valid_0;
    
    -- Фиксация первичного переполнения на входе фильтра
    over(0) <= div_over_0 or div_over_1;
     
    -- Входной фильтр нижних частот
    fir_0 : lim16_lpf_fir
    PORT MAP (
        aclk                            => aclk,
        s_axis_data_tvalid              => fir_in_tvalid,
        s_axis_data_tready              => open,
        s_axis_data_tdata               => fir_in_tdata,
        s_axis_config_tvalid            => fir_config_tvalid,
        s_axis_config_tready            => open,
        s_axis_config_tdata             => fir_config_tdata,
        s_axis_reload_tvalid            => fir_reload_tvalid,
        s_axis_reload_tready            => open,
        s_axis_reload_tlast             => fir_reload_tlast,
        s_axis_reload_tdata             => fir_reload_tdata,
        m_axis_data_tvalid              => fir_out_tvalid,
        m_axis_data_tdata               => fir_out_tdata,
        event_s_reload_tlast_missing    => open,
        event_s_reload_tlast_unexpected => open
    );
    
signed_round_sat_0 : signed_round_sat
    generic map(
        IWID       => 48,
        OWID       => 16,
        SHIFT_LEFT => GAIN_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir_out_tdata(95 downto 48),
        i_valid => fir_out_tvalid,
        o_data  => ch_a_16_reg,
        o_valid => out_valid_reg,
        ovf     => out_over_a
    );
    
    signed_round_sat_1 : signed_round_sat
    generic map(
        IWID       => 48,
        OWID       => 16,
        SHIFT_LEFT => GAIN_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir_out_tdata(47 downto 0),
        i_valid => fir_out_tvalid,
        o_data  => ch_b_16_reg,
        o_valid => open,
        ovf     => out_over_b
    );

    -----------------------------------------------------------------
    -- Назначение выходных портов модуля из стабильных регистров
    -----------------------------------------------------------------
    -- Теперь переключение шины данных и валида строго синхронизировано на Stage 2
    m_axis_data_tdata  <= ch_a_16_reg & ch_b_16_reg;
    m_axis_data_tvalid <= out_valid_reg;
    over(1)            <= out_over_a or out_over_b;

end Behavioral;

