library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all; -- Стандартная библиотека для тригонометрии

entity conv16x24_tb is
end entity conv16x24_tb;

architecture sim of conv16x24_tb is

    -- Константа периода тактовой частоты (1 / 122.88 МГц = ~8.138 нс)
    constant CLK_PERIOD : time := 8.138 ns;

    -- Сигналы для подключения к тестируемому модулю (UUT)
    signal aclk           : std_logic := '0';
    signal aresetn        : std_logic := '0';
    signal out_en         : std_logic := '0';
    signal mult_in_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal dds_cfg_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal dds_cfg_tvalid : std_logic := '0';
    signal dds_out_tdata  : std_logic_vector(47 downto 0);
    signal dac_tdata      : std_logic_vector(15 downto 0);

    -- Сигнал управления остановкой генератора тактов
    signal sim_finished   : boolean := false;
    
    constant SAMPLING_F : real := 122880000.0; -- Частота дискретизации 122.88 МГц
    constant FREQ_SIG   : real := 400000.0;   -- Входной сигнал 0,4 МГц
    constant FREQ_DDS   : real := 12000000.0;  -- Желаемая частота DDS 12 МГц

begin

    clk_process : process
    begin
        while not sim_finished loop
            aclk <= '0';
            wait for CLK_PERIOD / 2;
            aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait; -- Останавливает процесс навсегда после завершения теста
    end process;
    
    uut : entity work.conv16x24
    port map (
        aclk           => aclk,
        aresetn        => aresetn,
        out_en         => out_en,
        mult_in_tdata  => mult_in_tdata,
        dds_cfg_tdata  => dds_cfg_tdata,
        dds_cfg_tvalid => dds_cfg_tvalid,
        dds_out_tdata  => dds_out_tdata,
        dac_tdata      => dac_tdata
    );

        -- 3. Процесс генерации входных воздействий с автоматическим расчетом FTW
    stimulus_process : process

        -- Автоматический расчет управляющего слова частоты (FTW) для 32-битного DDS
        -- Формула: (FREQ_DDS / SAMPLING_F) * 2^32. Значение округляется до ближайшего целого.
        constant DDS_FTW_INT : integer := integer(round((FREQ_DDS / SAMPLING_F) * 4294967296.0));
        
        -- Переменные для расчета текущей фазы и амплитуды входного сигнала
        variable phase_sig  : real := 0.0;
        variable amp_sig    : real := 32767.0;

        -- Внутренние знаковые переменные для формирования входного IQ
        variable i_sig, q_sig : signed(15 downto 0);
    begin
        -- Шаг 1. Инициализация шин и сброс всей системы
        aresetn        <= '0';
        out_en         <= '0';
        dds_cfg_tdata  <= (others => '0');
        dds_cfg_tvalid <= '0';
        wait for CLK_PERIOD * 10;
        
        aresetn        <= '1';
        wait for CLK_PERIOD * 5;

        -- Шаг 2. Подача рассчитанной конфигурации частоты для DDS
        -- Явно преобразуем вычисленное целое число DDS_FTW_INT в 32-битный вектор
        dds_cfg_tdata  <= std_logic_vector(to_unsigned(DDS_FTW_INT, 32));
        dds_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        dds_cfg_tvalid <= '0';
        dds_cfg_tdata  <= (others => '0');
        wait for CLK_PERIOD * 5;

        -- Шаг 3. Активация выхода (включаем передачу)
        out_en <= '1';

        -----------------------------------------------------------------------
        -- ТЕСТ 1: Штатный линейный режим работы (Чистый синус без клиппинга)
        -----------------------------------------------------------------------
        for i in 0 to 1500 loop
            phase_sig := 2.0 * MATH_PI * FREQ_SIG * real(i) / SAMPLING_F;

            i_sig := to_signed(integer(amp_sig * cos(phase_sig)), 16);
            q_sig := to_signed(integer(amp_sig * sin(phase_sig)), 16);

            mult_in_tdata <= std_logic_vector(q_sig) & std_logic_vector(i_sig);

            wait until rising_edge(aclk);
        end loop;

        -----------------------------------------------------------------------
        -- ТЕСТ 2: Стресс-тест на переполнение (Проверка аппаратного насыщения)
        -----------------------------------------------------------------------
        amp_sig := 32767.0;
        
        for i in 0 to 500 loop
            phase_sig := 2.0 * MATH_PI * FREQ_SIG * real(i) / SAMPLING_F;

            i_sig := to_signed(integer(amp_sig * cos(phase_sig)), 16);
            q_sig := to_signed(integer(amp_sig * sin(phase_sig)), 16);

            mult_in_tdata <= std_logic_vector(q_sig) & std_logic_vector(i_sig);

            wait until rising_edge(aclk);
        end loop;

        -- Завершение и мягкий останов симуляции
        sim_finished <= true;
        wait;
    end process stimulus_process;

end architecture sim;
