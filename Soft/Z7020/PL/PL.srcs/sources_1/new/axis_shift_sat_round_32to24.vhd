library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_shift_sat_round_32to24 is
    port (
        -- Глобальные сигналы тактирования и сброса
        aclk            : in  std_logic;
        aresetn         : in  std_logic; -- Активный низкий уровень
        
        -- Конфигурация величины сдвига влево (ограничена диапазоном 0..8)
        shift           : in  natural range 0 to 8;  
        
        -- Интерфейс S_AXIS (Входной поток: 32 бита / 4 байта)
        s_axis_tdata    : in  std_logic_vector(31 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        
        -- Интерфейс M_AXIS (Выходной поток: 24 бита / 3 байта)
        m_axis_tdata    : out std_logic_vector(24 - 1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        
        -- Флаг переполнения (валиден только при m_axis_tvalid = '1')
        overflow        : out std_logic
    );
end entity axis_shift_sat_round_32to24;

architecture rtl of axis_shift_sat_round_32to24 is

    -- Индекс первого отбрасываемого снизу бита для округления (32 - 24 - 1 = 7)
    constant ROUND_BIT_IDX : integer := 7;

    -- Статические маски для проверки переполнения 24-битного знака (расширены до 25 бит)
    constant MAX_VAL : signed(24 downto 0) := "0" & X"7FFFFF"; -- Макс. полож: +8388607
    constant MIN_VAL : signed(24 downto 0) := "1" & X"800000"; -- Макс. отриц: -8388608

    -- Внутренние регистры конвейера данных
    signal m_data_signed   : signed(23 downto 0);
    signal m_valid_reg     : std_logic := '0';
    signal overflow_reg    : std_logic := '0';
    
    -- Сигнал разрешения работы конвейера (Flow Control)
    signal pipe_en         : std_logic;

begin

    -- Управление потоком AXI-Stream: готовы принять данные, если выходной регистр свободен
    -- или если последующий узел готов забрать данные прямо сейчас
    s_axis_tready <= m_axis_tready or not m_valid_reg;
    pipe_en       <= s_axis_tvalid and (m_axis_tready or not m_valid_reg);

   process(aclk)
        -- 32 бита (вход) + 8 бит (макс сдвиг) = 40 бит
        variable temp_ext_shifted : signed(39 downto 0);
        variable rounded_val      : signed(24 downto 0);
        
        -- Выделяем биты, которые потенциально могут выйти за знак при сдвиге
        variable bits_to_check    : std_logic_vector(7 downto 0);
        variable sign_bit         : std_logic;
        variable ovf_detected     : boolean;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_valid_reg   <= '0';
                m_data_signed <= (others => '0');
                overflow_reg  <= '0';
            else
                -- Управление валидностью потока AXI-Stream
                if pipe_en = '1' then
                    m_valid_reg <= '1';
                elsif m_axis_tready = '1' then
                    m_valid_reg <= '0';
                end if;

                if pipe_en = '1' then
                    -- Шаг 1: Расширение знака до 40 бит и арифметический сдвиг влево.
                    temp_ext_shifted := shift_left(resize(signed(s_axis_tdata), 40), shift);
                    
                    -- Шаг 2: Выделение целевого окна 31..8 с расширением на 1 бит знака для округления
                    rounded_val := resize(temp_ext_shifted(31 downto 8), 25);
                    
                    -- Шаг 3: Математическое округление к ближайшему целому (по 7-му биту)
                    if temp_ext_shifted(7) = '1' then
                        rounded_val := rounded_val + 1;
                    end if;
                    
                    -- Шаг 4: Высокоскоростной контроль переполнения старших бит
                    -- Берем реальный результирующий знак числа (после сдвига)
                    sign_bit := temp_ext_shifted(31); 
                    
                    -- Проверяем биты, которые «вылетели» выше 31-го разряда (с 39 по 32)
                    bits_to_check := std_logic_vector(temp_ext_shifted(39 downto 32));
                    
                    -- Логика переполнения:
                    -- Если знак '0' (положительное число), то все биты выше должны быть '0'. Если есть '1' -> OVF.
                    -- Если знак '1' (отрицательное число), то все биты выше должны быть '1'. Если есть '0' -> OVF.
                    ovf_detected := false;
                    if sign_bit = '0' then
                        if bits_to_check /= X"00" then
                            ovf_detected := true;
                        end if;
                    else
                        if bits_to_check /= X"FF" then
                            ovf_detected := true;
                        end if;
                    end if;

                    -- Дополнительная проверка на инверсию знака из-за округления (+1)
                    if rounded_val(24) /= rounded_val(23) then
                        ovf_detected := true;
                    end if;
                    
                    -- Шаг 5: Применение насыщения по результатам проверки
                    if ovf_detected then
                        -- Выбираем направление насыщения по знаку исходного сдвинутого вектора
                        if sign_bit = '0' then
                            m_data_signed <= X"7FFFFF"; -- Положительное насыщение
                        else
                            m_data_signed <= X"800000"; -- Отрицательное насыщение
                        end if;
                        overflow_reg <= '1';
                    else
                        m_data_signed <= rounded_val(23 downto 0); -- Данные в норме
                        overflow_reg  <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Назначение выходных портов
    m_axis_tvalid <= m_valid_reg;
    m_axis_tdata  <= std_logic_vector(m_data_signed);
    overflow      <= overflow_reg and m_valid_reg; -- Флаг активен только при валидных данных

end architecture rtl;
