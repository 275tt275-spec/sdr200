library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; -- Используем только официальный стандарт IEEE

entity lim16_div is
    Port ( 
        s_axis_divisor_tvalid  : IN  STD_LOGIC;
        s_axis_divisor_tdata   : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN  STD_LOGIC;
        s_axis_dividend_tdata  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid     : OUT STD_LOGIC;
        m_axis_dout_tdata      : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
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
    
    -- Сигналы данных и управления
    signal dividend_signed : signed(31 downto 0);
    signal dividend        : std_logic_vector(31 downto 0); 
    signal dout_tdata      : std_logic_vector(31 downto 0); 
    signal dout_tvalid     : std_logic;
    
    -----------------------------------------------------------------
    -- Конвейер Округления и Насыщения (2 такта после IP-ядра)
    -----------------------------------------------------------------
    -- Стадия 1: Округление
    signal div_round_reg   : signed(31 downto 0) := (others => '0');
    signal div_valid_pipe1 : std_logic := '0';
    
    -- Стадия 2: Выходные регистры после Сатурации
    signal dout_data_reg   : std_logic_vector(23 downto 0) := (others => '0');
    signal dout_valid_reg  : std_logic := '0';
    signal out_over_reg    : std_logic := '0';

begin

    -- КОРРЕКТНОЕ ЗНАКОВОЕ РАСШИРЕНИЕ И МАСШТАБИРОВАНИЕ:
    -- Сначала расширяем 16-битное signed число до 32 бит, сохраняя знак,
    -- а затем сдвигаем влево на 15 бит (умножаем на 2^15) для формирования дробной сетки.
    dividend_signed <= shift_left(resize(signed(s_axis_dividend_tdata), 32), 15);
    dividend        <= std_logic_vector(dividend_signed);

    -- IP-ядро деления знаковых чисел
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
            -- СТАДИЯ 1: Математическое округление (Rounding)
            -----------------------------------------------------------------
            if dout_tvalid = '1' then
                div_round_reg <= signed(dout_tdata) + to_signed(1, 32);
            end if;
            div_valid_pipe1 <= dout_tvalid; -- Строго синхронный сдвиг валида
            
            -----------------------------------------------------------------
            -- СТАДИЯ 2: Сатурация (Насыщение) и выравнивание маски переполнения
            -----------------------------------------------------------------
            dout_valid_reg <= div_valid_pipe1;
            
            if div_valid_pipe1 = '1' then
                -- Вырезаемое окно данных: (26 downto 3). Длина = 24 бита.
                -- Значит, все биты старше 26-го (с 31 по 26) должны дублировать знак.
                -- Проверяем маску знакового расширения:
                if div_round_reg(31 downto 24) = "11111111" or div_round_reg(31 downto 24) = "00000000" then
                    out_over_reg      <= '0'; 
                    dout_data_reg     <= std_logic_vector(div_round_reg(24 downto 1));
                -- Если переполнение в положительную сторону (знаковый бит 31 равен '0')
                elsif div_round_reg(31) = '0' then 
                    out_over_reg      <= '1'; 
                    dout_data_reg     <= x"7FFFFF"; -- Максимальное положительное 24-битное число
                -- Иначе переполнение в отрицательную сторону
                else
                    out_over_reg      <= '1'; 
                    dout_data_reg     <= x"800000"; -- Минимальное отрицательное 24-битное число
                end if;
            else
                out_over_reg <= '0'; -- Сбрасываем флаг, если на выходе нет валидных данных
            end if;   
        end if;
    end process;

    -- Назначение выходных портов модуля из стабильных регистров конвейера
    m_axis_dout_tvalid <= dout_valid_reg;
    m_axis_dout_tdata  <= dout_data_reg;
    out_over           <= out_over_reg;

end Behavioral;
