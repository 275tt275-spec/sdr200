library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_RXA_wide is
end tb_RXA_wide;

architecture Behavioral of tb_RXA_wide is

    -- Параметры тактирования и моделирования
    constant CLK_PERIOD : time := 20 ns; -- 50 MHz
    
    -- Сигналы для подключения к тестируемому модулю (UUT)
    signal aclk                : std_logic := '0';
    signal aresetn             : std_logic := '0';
    signal s_axis_signal_tdata : std_logic_vector(15 downto 0) := (others => '0');
    signal dds_value           : std_logic_vector(31 downto 0) := (others => '0');
    signal dds_valid           : std_logic := '0';
    signal m_axis_wb_tready    : std_logic := '1';
    signal m_axis_wb_tdata     : std_logic_vector(31 downto 0);
    signal m_axis_wb_tvalid    : std_logic;

    -- Настройки генератора тестового АМ-сигнала
    constant FS            : real := 122880000.0;  -- Частота дискретизации (50 МГц)
    constant FC            : real := 15000000.0;  -- Частота несущей АМ (1.5 МГц)
    constant FM            : real := 5000.0;      -- Частота модуляции (5 кГц)
    constant MOD_INDEX     : real := 0.8;         -- Коэффициент АМ модуляции (80%)
    constant CARRIER_AMPL  : real := 15000.0;     -- Амплитуда несущей (в пределах 16-бит Signed)
    
    -- ТУМБЛЕР ДЛЯ ПРОВЕРКИ: 
    -- 0.0 - идеальный АЦП без постоянки. 
    -- 500.0 - симуляция аппаратного смещения АЦП на +500 отсчетов.
    constant ADC_DC_OFFSET : real := 500.0; 

    -- Флаг для остановки симуляции
    signal sim_done : boolean := false;

begin

    -- 1. Тактовый генератор (50 МГц)
    aclk_process : process
    begin
        while not sim_done loop
            aclk <= '0';
            wait for CLK_PERIOD / 2;
            aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait; -- Останавливает процесс навсегда после завершения симуляции
    end process;

-- 2. Генератор тестового АМ-сигнала и управление DDS
    stimulus_process : process
        variable sample_idx : integer := 0;
        variable t          : real;
        variable mod_sig    : real;
        variable am_signal  : real;
        variable total_adc  : integer;
    begin
        -- Сброс всей логики
        aresetn <= '0';
        dds_valid <= '0';
        wait for CLK_PERIOD * 10;
        aresetn <= '1';
        wait for CLK_PERIOD * 5;

        -- Настройка частоты DDS (Формула: FTW = (FC / FS) * 4294967296.0)
        dds_value <= std_logic_vector(to_unsigned(integer((FC / FS) * 4294967296.0), 32));
        dds_valid <= '1';
        wait for CLK_PERIOD;
        dds_valid <= '0';

        -- Основной цикл генерации потока данных АЦП
        while sample_idx < 10000 loop  -- Генерируем 10000 отсчетов
            t := real(sample_idx) / FS;
            
            -- Модулирующий звуковой сигнал (Синусоида 100 кГц)
            mod_sig := sin(2.0 * MATH_PI * FM * t);
            
            -- Математическая модель АМ модуляции
            am_signal := (1.0 + MOD_INDEX * mod_sig) * CARRIER_AMPL * cos(2.0 * MATH_PI * FC * t);
            
            -- Добавляем искусственное смещение по постоянному току (DC Offset)
            total_adc := integer(am_signal + ADC_DC_OFFSET);
            
            -- Загоняем данные в шину
            s_axis_signal_tdata <= std_logic_vector(to_signed(total_adc, 16));
            
            sample_idx := sample_idx + 1;
            wait for CLK_PERIOD;
        end loop;

        -- Завершение симуляции
        sim_done <= true;
        wait;
    end process;
    
        -- 3. Подключение тестируемого модуля (UUT)
    uut: entity work.RXA_wide
        port map (
            aclk                => aclk,
            aresetn             => aresetn,
            s_axis_signal_tdata => s_axis_signal_tdata,
            dds_value           => dds_value,
            dds_valid           => dds_valid,
            m_axis_wb_tready    => m_axis_wb_tready,
            m_axis_wb_tdata     => m_axis_wb_tdata,
            m_axis_wb_tvalid    => m_axis_wb_tvalid
        );

end Behavioral;

