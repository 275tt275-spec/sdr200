library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_RXA_wide is
-- Тестбенч не имеет внешних портов
end tb_RXA_wide;

architecture Behavioral of tb_RXA_wide is

    -- Настройка тактовой частоты (122.880 МГц -> период ~8.138 нс)
    constant CLK_PERIOD : time := 8.138 ns;

    -- Сигналы для подключения к тестируемому модулю (UUT)
    signal m_axis_wb_tdata     : STD_LOGIC_VECTOR(31 downto 0);
    signal m_axis_wb_tvalid    : STD_LOGIC;
    signal m_axis_wb_tready    : STD_LOGIC := '1'; -- Всегда готовы принимать данные
    signal s_axis_signal_tdata : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal dds_value           : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal dds_valid           : STD_LOGIC := '0';
    signal ovr                 : STD_LOGIC;
    signal aresetn             : STD_LOGIC := '0';
    signal aclk                : STD_LOGIC := '0';
    
    signal sig_i_out           : signed(15 downto 0) := (others => '0');
    signal sig_q_out           : signed(15 downto 0) := (others => '0');

begin

    -- Подключение тестируемого модуля (Unit Under Test)
    uut: entity work.RXA_wide
        port map (
            m_axis_wb_tdata     => m_axis_wb_tdata,
            m_axis_wb_tvalid    => m_axis_wb_tvalid,
            m_axis_wb_tready    => m_axis_wb_tready,
            s_axis_signal_tdata => s_axis_signal_tdata,
            dds_value           => dds_value,
            dds_valid           => dds_valid,
            ovr                 => ovr,
            aresetn             => aresetn,
            aclk                => aclk
        );

    -- Процесс генерации тактового сигнала (aclk = 122.880 МГц)
    p_clk_gen : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD / 2;
        aclk <= '1';
        wait for CLK_PERIOD / 2;
    end process p_clk_gen;

    -- Процесс управления сбросом (aresetn)
    p_reset_gen : process
    begin
        aresetn <= '0';
        wait for CLK_PERIOD * 10; -- Удерживаем сброс 10 тактов
        aresetn <= '1';
        wait; -- Останавливаем процесс сброса
    end process p_reset_gen;

    -------------------------------------------------------------------------
    -- Процесс генерации входных стимулов
    -------------------------------------------------------------------------
    p_stimuli : process
        -- Переменные для генерации тестовой синусоиды на входе АЦП
        variable v_angle_adc : real := 0.0;
        -- НАСТРОЙКА ЧАСТОТ (в Герцах)
        constant F_SAMPLING  : real := 122880000.0; -- Частота дискретизации f_clk
        constant F_SIGNAL    : real := 5050000.0;  -- Частота сигнала на входе АЦП (5.05 МГц)
        constant F_LO_DDS    : real := 5000000.0;  -- Частота настройки гетеродина DDS (5.00 МГц)
        
        -- Математические константы
        constant PI          : real := 3.141592653589793;
        constant AMP_ADC     : real := 32767.0;     -- Амплитуда для АЦП (16 бит signed)
    begin
        -- Исходное состояние шин управления до снятия сброса
        dds_valid <= '0';
        dds_value <= (others => '0');
        s_axis_signal_tdata <= (others => '0');
        
        -- Ждем окончания сброса системы
        wait until aresetn = '1';
        wait for CLK_PERIOD * 5;
        
        -- ФОРМИРОВАНИЕ ОДНОКРАТНОГО ИМПУЛЬСА ЗАПИСИ ЧАСТОТЫ (Настройка на 5.00 МГц)
        -- Код частоты: (5 000 000 / 122 880 000) * 2^32 = 174603016
        dds_value <= std_logic_vector(to_unsigned(174603016, 32));
        dds_valid <= '1';            -- Взводим валидность на один такт
        wait for CLK_PERIOD;
        
        dds_valid <= '0';            -- Сбрасываем валидность в '0' (Импульс завершен)
        dds_value <= (others => '0'); -- Очищаем шину данных (опционально, для чистоты диаграммы)


        -- Цикл непрерывного формирования выборок реального времени
        while true loop
            
            -- 1. Симуляция математики АЦП (Входной радиосигнал)
            s_axis_signal_tdata <= std_logic_vector(to_signed(integer(AMP_ADC * sin(v_angle_adc)), 16));
            
            -- 3. Инкремент фазовых углов для следующего такта дискретизации
            v_angle_adc := v_angle_adc + (2.0 * PI * F_SIGNAL / F_SAMPLING);
            
            -- Защита от переполнения диапазона вещественных чисел (real)
            if v_angle_adc >= (2.0 * PI) then
                v_angle_adc := v_angle_adc - (2.0 * PI);
            end if;
            
            wait for CLK_PERIOD;
        end loop;
    end process p_stimuli;

    -------------------------------------------------------------------------
    -- Процесс мониторинга выхода
    -------------------------------------------------------------------------
    p_monitor : process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                sig_i_out <= (others => '0');
                sig_q_out <= (others => '0');
            elsif m_axis_wb_tvalid = '1' and m_axis_wb_tready = '1' then
                -- Выделяем I и Q компоненты и записываем их в глобальные сигналы
                sig_i_out <= signed(m_axis_wb_tdata(31 downto 16));
                sig_q_out <= signed(m_axis_wb_tdata(15 downto 0));
            end if;
        end if;
    end process p_monitor;

end Behavioral;

