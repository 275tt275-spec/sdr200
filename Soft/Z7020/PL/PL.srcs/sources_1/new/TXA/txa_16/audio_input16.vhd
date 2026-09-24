library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity audio_input16 is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (23 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (15 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_cfg_tvalid : in STD_LOGIC;
       overflow : out STD_LOGIC
    );
end audio_input16;

architecture Behavioral of audio_input16 is

component fir_audio_16 IS
    port (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--        s_axis_config_tvalid : IN STD_LOGIC;
--        s_axis_config_tready : OUT STD_LOGIC;
--        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0)
    );
    end component fir_audio_16;
    
    -- Внутренние сигналы
    signal gain_correct      : std_logic_vector(3 downto 0) := x"6";
    signal fir_in_tdata      : std_logic_vector(15 downto 0);
    signal fir_in_tvalid     : std_logic;
    signal fir_out_tdata     : std_logic_vector(39 downto 0);
    signal fir_out_tvalid    : std_logic;
    
    -- Выходные регистры конвейера
    signal out_rounded       : signed(15 downto 0) := (others => '0');
    signal m_axis_tvalid_reg : std_logic := '0';
    signal gain_overflow_reg : std_logic := '0';

begin

    -- Процесс корректного округления 24-битного входа до 16-битного знакового числа
    -- Предотвращает появление постоянной составляющей (DC offset) от грубого усечения бит
    proc_input : process(aclk)
        variable in_extended : signed(24 downto 0);
        variable in_rounded  : signed(24 downto 0);
    begin
        if rising_edge(aclk) then
            fir_in_tvalid <= s_axis_tvalid;
            
            -- Знаковое расширение до 25 бит для безопасного сложения
            in_extended := resize(signed(s_axis_tdata), 25);
            
            -- Округление: прибавляем половину веса отбрасываемых 8 бит (2^7 = 128)
            in_rounded  := in_extended + 128;
            
            -- Проверка на переполнение знака при округлении вверх в максимальной точке
            if (in_rounded(24) = '0' and in_rounded(23) = '1') then
                fir_in_tdata <= x"7FFF"; -- Насыщение в плюс
            elsif (in_rounded(24) = '1' and in_rounded(23) = '0') then
                fir_in_tdata <= x"8000"; -- Насыщение в минус
            else
                fir_in_tdata <= std_logic_vector(in_rounded(23 downto 8));
            end if;
        end if;
    end process proc_input;

    -- Процесс фиксации настроек усиления из AXIS Config
    proc_config : process(aclk)
    begin
        if rising_edge(aclk) then
            if s_axis_cfg_tvalid = '1' then
                if s_axis_cfg_tdest = "1" then
                    gain_correct <= s_axis_cfg_tdata(3 downto 0);
                end if;    
            end if;
        end if;
    end process proc_config;

audio_0 : fir_audio_16
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => fir_in_tdata,
--        s_axis_config_tvalid => config_tvalid,
--        s_axis_config_tready => open,
--        s_axis_config_tdata => config_tdata,
        m_axis_data_tvalid => fir_out_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );
    
 -- Процесс коррекции усиления, округления результата и защиты от насыщения
    proc_dsp : process(aclk)
        variable shift_val : integer range 0 to 15;
        -- Расширяем сетку до 56 бит (40 бит FIR + 15 бит макс. сдвига + 1 бит под знак)
        variable extended  : signed(55 downto 0); 
        variable shifted   : signed(55 downto 0);
        variable rounded   : signed(55 downto 0);
    begin
        if rising_edge(aclk) then
            m_axis_tvalid_reg <= fir_out_tvalid;

            case gain_correct is
                when "0001"   => shift_val := 1;
                when "0010"   => shift_val := 2;
                when "0011"   => shift_val := 3;
                when "0100"   => shift_val := 4;
                when "0101"   => shift_val := 5;
                when "0110"   => shift_val := 6;
                when "0111"   => shift_val := 7;
                when "1000"   => shift_val := 8;
                when "1001"   => shift_val := 9;
                when "1010"   => shift_val := 10;
                when "1011"   => shift_val := 11;
                when "1100"   => shift_val := 12;
                when "1101"   => shift_val := 13;
                when "1110"   => shift_val := 14;
                when "1111"   => shift_val := 15;
                when others   => shift_val := 0;
            end case;

            -- 1. Знаковое расширение 40-битного выхода FIR до 56 бит
            extended := resize(signed(fir_out_tdata), 56);
            
            -- 2. Арифметический сдвиг влево (усиление)
            shifted  := shift_left(extended, shift_val);
            
            -- 3. Округление выхода: отбрасываем младшие 24 бита, прибавляем половину (2^23 = 8388608)
            rounded  := shifted + 8388608;

            -- 4. Контроль насыщения и усечение до целевых 16 бит.
            -- Забираем биты с 39 по 24 (целевые 16 бит звука).
            -- Старшие биты с 55 по 39 проверяем на идентичность знаку.
            
            if (rounded(55) = '0' and rounded(54 downto 39) /= "0000000000000000") then
                -- Положительное переполнение
                out_rounded <= x"7FFF"; 
                gain_overflow_reg <= '1';
            elsif (rounded(55) = '1' and rounded(54 downto 39) /= "1111111111111111") then
                -- Отрицательное переполнение
                out_rounded <= x"8000"; 
                gain_overflow_reg <= '1';
            else
                -- Итоговый округленный результат без переполнения
                out_rounded <= rounded(39 downto 24);
                gain_overflow_reg <= '0';
            end if;
        end if;
    end process proc_dsp;

    -- Назначение выходных портов
    m_axis_tdata  <= std_logic_vector(out_rounded);
    m_axis_tvalid <= m_axis_tvalid_reg;
    overflow      <= gain_overflow_reg;
    
end Behavioral;
