library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Используем только официальный стандарт IEEE

entity lim16_div is
    generic (
        G_BIT_HIGH : integer := 17  -- Позиция старшего (знакового) бита выходного окна (задается снаружи)
    );
    Port ( 
        s_axis_divisor_tvalid  : IN  STD_LOGIC;
        s_axis_divisor_tdata   : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN  STD_LOGIC;
        s_axis_dividend_tdata  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid     : OUT STD_LOGIC;
        m_axis_dout_tdata      : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- Выходная шина на 16 бит
        out_over               : OUT STD_LOGIC;
        aclk                   : in  STD_LOGIC
    );
end lim16_div;

architecture Behavioral of lim16_div is

    component div_16 is
        port (
            aclk                   : IN  STD_LOGIC;
            s_axis_divisor_tvalid  : IN  STD_LOGIC;
            s_axis_divisor_tready  : OUT STD_LOGIC;
            s_axis_divisor_tdata   : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            s_axis_dividend_tvalid : IN  STD_LOGIC;
            s_axis_dividend_tready : OUT STD_LOGIC;
            s_axis_dividend_tdata  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_dout_tvalid     : OUT STD_LOGIC;
            m_axis_dout_tdata      : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component div_16;
    
    -- Автоматический пересчет битовой сетки на основе G_BIT_HIGH
    constant C_BIT_LOW       : integer := G_BIT_HIGH - 15; -- Младший сохраняемый бит окна
    constant C_ROUND_BIT     : integer := C_BIT_LOW - 1;   -- Бит округления (0.5 LSB)
    
    -- Формируем целочисленное значение константы округления (2**C_ROUND_BIT)
    constant C_ROUND_VAL     : integer := 2**C_ROUND_BIT;

    -- Сигналы данных и управления
    signal dividend_signed : signed(31 downto 0);
    signal dividend        : std_logic_vector(31 downto 0); 
    signal dout_tdata      : std_logic_vector(31 downto 0); 
    signal dout_tvalid     : std_logic;
    
    -----------------------------------------------------------------
    -- Конвейер Округления и Насыщения (2 такта после IP-ядра)
    -----------------------------------------------------------------
    -- Стадия 1: Симметричное округление
    signal div_round_reg   : signed(31 downto 0) := (others => '0');
    signal div_valid_pipe1 : std_logic := '0';
    
    -- Стадия 2: Выходные регистры после Сатурации
    signal dout_data_reg   : std_logic_vector(15 DOWNTO 0) := (others => '0');
    signal dout_valid_reg  : std_logic := '0';
    signal out_over_reg    : std_logic := '0';

begin

    -- КОРРЕКТНОЕ ЗНАКОВОЕ РАСШИРЕНИЕ И МАСШТАБИРОВАНИЕ:
    dividend_signed <= shift_left(resize(signed(s_axis_dividend_tdata), 32), 15);
    dividend        <= std_logic_vector(dividend_signed);

    -- IP-ядро деления знаковых чисел Xilinx / AMD
    div_0 : div_16
        PORT MAP (
            aclk                   => aclk,
            s_axis_divisor_tvalid  => s_axis_divisor_tvalid,
            s_axis_divisor_tready  => open,
            s_axis_divisor_tdata   => s_axis_divisor_tdata,
            s_axis_dividend_tvalid => s_axis_dividend_tvalid,
            s_axis_dividend_tready => open,
            s_axis_dividend_tdata  => dividend,
            m_axis_dout_tvalid     => dout_tvalid,
            m_axis_dout_tdata      => dout_tdata
        );
        
    process(aclk)
    begin
        if rising_edge(aclk) then   
            -----------------------------------------------------------------
            -- СТАДИЯ 1: Прецизионное симметричное округление (Sign-Magnitude)
            -- Константа C_ROUND_VAL автоматически принимает нужный вес (1, 2, 4 и т.д.)
            -- Это полностью ликвидирует накопление постоянной составляющей (DC-offset).
            -----------------------------------------------------------------
            if dout_tvalid = '1' then
                if dout_tdata(31) = '0' then
                    -- Положительное число: округляем вверх (+0.5 LSB)
                    div_round_reg <= signed(dout_tdata) + to_signed(C_ROUND_VAL, 32);
                else
                    -- Отрицательное число: округляем вниз (-0.5 LSB)
                    div_round_reg <= signed(dout_tdata) - to_signed(C_ROUND_VAL, 32);
                end if;    
            end if;
            div_valid_pipe1 <= dout_tvalid; -- Синхронный сдвиг строба valid
            
            -----------------------------------------------------------------
            -- СТАДИЯ 2: Сатурация (Насыщение) и контроль знакового расширения
            -----------------------------------------------------------------
            dout_valid_reg <= div_valid_pipe1;
            
            if div_valid_pipe1 = '1' then
                -- Честная проверка знаковой подушки: контролируем биты с 31 по G_BIT_HIGH.
                -- Если все биты расширения знака равны самому знаковому биту окна - переполнения нет.
                if div_round_reg(31 downto G_BIT_HIGH) = (31 downto G_BIT_HIGH => '1') or 
                   div_round_reg(31 downto G_BIT_HIGH) = (31 downto G_BIT_HIGH => '0') then
                   
                    out_over_reg  <= '0'; 
                    -- Переполнения нет, вырезаем ровно 16 бит из динамически рассчитанного диапазона
                    dout_data_reg <= std_logic_vector(div_round_reg(G_BIT_HIGH downto C_BIT_LOW));
                    
                -- Если биты разошлись и старший знаковый бит 31 равен '0' - это положительное переполнение
                elsif div_round_reg(31) = '0' then 
                    out_over_reg  <= '1'; 
                    dout_data_reg <= x"7FFF"; -- Насыщение к максимуму (+32767)
                    
                -- Иначе - это отрицательное переполнение
                else
                    out_over_reg  <= '1'; 
                    dout_data_reg <= x"8000"; -- Насыщение к miniмуму (-32768)
                end if;
            else
                out_over_reg <= '0'; -- Сбрасываем флаг, если на выходе нет валидных данных
            end if;   
        end if;
    end process;

    -- Назначение выходных портов модуля из стабильных регистров конвейера Стадии 2
    m_axis_dout_tvalid <= dout_valid_reg;
    m_axis_dout_tdata  <= dout_data_reg;
    out_over           <= out_over_reg;

end Behavioral;
