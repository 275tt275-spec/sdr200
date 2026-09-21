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
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim16_lpf_fir;
    
    component lim16_div is
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
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
    signal divout_0       : std_logic_vector(23 downto 0); 
    signal divout_1       : std_logic_vector(23 downto 0); 
    signal divout_valid_0 : std_logic;
    signal divout_valid_1 : std_logic;
    signal div_over_0     : std_logic;
    signal div_over_1     : std_logic;
    signal fir_in_tdata   : std_logic_vector(31 downto 0);
    signal fir_in_tvalid  : std_logic;
    signal fir_out_tdata  : std_logic_vector(79 downto 0);
    signal fir_out_tvalid : std_logic;
    signal inv_div0, inv_div1 : signed(23 downto 0);

    -----------------------------------------------------------------
    -- Сигналы для конвейера Округления и Насыщения (Rounding & Saturation)
    -----------------------------------------------------------------
    -- Выделенные из FIR 40-битные знаковые каналы А и Б
    signal fir_a_raw, fir_b_raw     : signed(39 downto 0);
    
    constant GAIN_SHIFT : integer := 13;     
    constant C_ROUND_VAL : signed(39 downto 0) := x"0000000400";
    signal fir_a_round, fir_b_round : signed(39 downto 0) := (others => '0');
    signal fir_valid_pipe1          : std_logic := '0';
    
    -- СТАДИЯ 2: Выходные регистры каналов после Сатурации
    signal ch_a_16_reg, ch_b_16_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal out_valid_reg            : std_logic := '0';
    signal out_over_reg             : std_logic := '0';

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
    fir_in_tdata <= std_logic_vector(inv_div0(23 downto 8)) & std_logic_vector(inv_div1(23 downto 8));
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

    -- Разделяем выход шины фильтра на индивидуальные каналы А и Б по 40 бит
    fir_a_raw <= signed(fir_out_tdata(79 downto 40));
    fir_b_raw <= signed(fir_out_tdata(39 downto 0));

    -- Двухстадийный процесс конвейерной обработки выходных сигналов IQ
    process(aclk)
        -- Переменные-флаги переполнения знакового расширения
        variable overflow_a : boolean;
        variable overflow_b : boolean;
    begin
        if rising_edge(aclk) then
            -----------------------------------------------------------------
            -- СТАДИЯ 1: Конвейерное округление (Rounding)
            -- Прибавляем единицу в вес 8-го бита (C_ROUND_VAL = x"1000" в терминах 40 бит)
            -----------------------------------------------------------------
            fir_a_round     <= fir_a_raw + C_ROUND_VAL;
            fir_b_round     <= fir_b_raw + C_ROUND_VAL;
            fir_valid_pipe1 <= fir_out_tvalid;

            -----------------------------------------------------------------
            -- СТАДИЯ 2: Сатурация (Saturation) и проверка знакового расширения
            -----------------------------------------------------------------
            out_valid_reg <= fir_valid_pipe1;

            if fir_valid_pipe1 = '1' then
                -- По умолчанию считаем, что переполнения нет
                overflow_a := false;
                overflow_b := false;
                out_over_reg <= '0';

                -- ИСПРАВЛЕННЫЙ ЦИКЛ КАНАЛА А: 
                -- При GAIN_SHIFT = 7 полезный срез равен (32 downto 17). Значит, 32-й бит - знаковый.
                -- Проверяем биты расширения строго ВЫШЕ старшего полезного бита (от 39 до 33)
                for i in 39 downto (39 - GAIN_SHIFT + 1) loop
                    if fir_a_round(i) /= fir_a_round(39) then
                        overflow_a := true;
                    end if;
                end loop;

                if overflow_a then
                    out_over_reg <= '1';
                    if fir_a_round(39) = '0' then
                        ch_a_16_reg <= x"7FFF"; -- Положительное насыщение
                    else
                        ch_a_16_reg <= x"8000"; -- Отрицательное насыщение
                    end if;
                else
                    -- Ошибки нет, забираем 16 бит округленной полезной части со сдвигом усиления
                    ch_a_16_reg <= std_logic_vector(fir_a_round((39 - GAIN_SHIFT) downto (24 - GAIN_SHIFT)));
                end if;

                -- ИСПРАВЛЕННЫЙ ЦИКЛ КАНАЛА Б:
                -- Проверяем биты знакового расширения строго выше полезного 32-го бита (от 39 до 33)
                for i in 39 downto (39 - GAIN_SHIFT + 1) loop
                    if fir_b_round(i) /= fir_b_round(39) then
                        overflow_b := true;
                    end if;
                end loop;

                if overflow_b then
                    out_over_reg <= '1';
                    if fir_b_round(39) = '0' then
                        ch_b_16_reg <= x"7FFF"; -- Положительное насыщение
                    else
                        ch_b_16_reg <= x"8000"; -- Отрицательное насыщение
                    end if;
                else
                    -- Ошибки нет, забираем 16 бит округленной полезной части со сдвигом усиления
                    ch_b_16_reg <= std_logic_vector(fir_b_round((39 - GAIN_SHIFT) downto (24 - GAIN_SHIFT)));
                end if;
            else
                out_over_reg <= '0'; -- Сбрасываем флаг, если данные невалидны
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Назначение выходных портов модуля из стабильных регистров
    -----------------------------------------------------------------
    -- Теперь переключение шины данных и валида строго синхронизировано на Stage 2
    m_axis_data_tdata  <= ch_a_16_reg & ch_b_16_reg;
    m_axis_data_tvalid <= out_valid_reg;
    over(1)            <= out_over_reg;

end Behavioral;

