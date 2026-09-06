library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity audio_input is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (23 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (23 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_cfg_tvalid : in STD_LOGIC;
       overflow : out STD_LOGIC
    );
end audio_input;

architecture Behavioral of audio_input is

component fir_audio_0 IS
    port (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
--        s_axis_config_tvalid : IN STD_LOGIC;
--        s_axis_config_tready : OUT STD_LOGIC;
--        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    end component fir_audio_0;
    
    component filter_gain is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (63 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (47 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       gain_correct : in STD_LOGIC_VECTOR (2 downto 0);
       overflow : out STD_LOGIC
    );
    end component filter_gain;
    
    -- Внутренние сигналы
    signal gain_correct      : std_logic_vector(2 downto 0) := "001";
    signal fir_out_tdata     : std_logic_vector(31 downto 0);
    signal fir_out_tvalid    : std_logic;
    
    -- Выходные регистры конвейера
    signal out_rounded       : signed(23 downto 0) := (others => '0');
    signal m_axis_tvalid_reg : std_logic := '0';
    signal gain_overflow_reg : std_logic := '0';

begin

    -- Процесс фиксации настроек усиления из AXIS Config
    proc_config : process(aclk)
    begin
        if rising_edge(aclk) then
            if s_axis_cfg_tvalid = '1' then
                if s_axis_cfg_tdest = "1" then
                    gain_correct <= s_axis_cfg_tdata(2 downto 0);
                end if;    
            end if;
        end if;
    end process proc_config;

audio_0 : fir_audio_0
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => s_axis_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => s_axis_tdata,
--        s_axis_config_tvalid => config_tvalid,
--        s_axis_config_tready => open,
--        s_axis_config_tdata => config_tdata,
        m_axis_data_tvalid => fir_out_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );
    
 -- Процесс масштабирования, округления и защиты от насыщения
    proc_dsp : process(aclk)
        variable shift_val : integer range 0 to 7;
        variable extended  : signed(39 downto 0); -- Расширяем сетку до 40 бит для безопасного сдвига
        variable shifted   : signed(39 downto 0);
        variable rounded   : signed(39 downto 0);
    begin
        if rising_edge(aclk) then
            m_axis_tvalid_reg <= fir_out_tvalid;

            case gain_correct is
                when "001"   => shift_val := 1;
                when "010"   => shift_val := 2;
                when "011"   => shift_val := 3;
                when "100"   => shift_val := 4;
                when "101"   => shift_val := 5;
                when "110"   => shift_val := 6;
                when "111"   => shift_val := 7;
                when others  => shift_val := 0;
            end case;

            -- 1. Безопасно расширяем 32-битное число из FIR до 40 бит (знаковое расширение)
            extended := resize(signed(fir_out_tdata), 40);
            
            -- 2. Делаем арифметический сдвиг влево. Теперь старшие биты не теряются!
            shifted  := shift_left(extended, shift_val);
            
            -- 3. Округление (добавляем половину веса отбрасываемой части перед срезом младших 8 бит)
            rounded  := shifted + 128;

            -- 4. Контроль насыщения и усечение до 24 бит.
            -- Мы планируем взять биты с 31 по 8 (целевые 24 бита результата).
            -- Следовательно, все биты выше 31-го (то есть с 39 по 31) должны быть строго одинаковыми:
            -- Либо все '0' (для положительных чисел), либо все '1' (для отрицательных).
            -- Если это условие нарушено - произошло переполнение знакового диапазона.
            
            if (rounded(39) = '0' and rounded(38 downto 31) /= "000000000") then
                -- Положительное переполнение
                out_rounded <= x"7FFFFF"; 
                gain_overflow_reg <= '1';
            elsif (rounded(39) = '1' and rounded(38 downto 31) /= "111111111") then
                -- Отрицательное переполнение
                out_rounded <= x"800000"; 
                gain_overflow_reg <= '1';
            else
                -- Переполнения нет, берем наши отмасштабированные и округленные 24 бита звука
                out_rounded <= rounded(31 downto 8);
                gain_overflow_reg <= '0';
            end if;
        end if;
    end process proc_dsp;

    -- Назначение выходных портов
    m_axis_tdata  <= std_logic_vector(out_rounded);
    m_axis_tvalid <= m_axis_tvalid_reg;
    overflow      <= gain_overflow_reg;
    
end Behavioral;
