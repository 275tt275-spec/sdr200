library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_hf_dpd is
-- У тестбенча нет портов
end tb_hf_dpd;

architecture Behavioral of tb_hf_dpd is

    -- Компонент тестируемого модуля (UUT)
    component hf_dpd is
        Port ( 
            s_axis_iq_tdata   : in  STD_LOGIC_VECTOR (47 downto 0);
            s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
            m_axis_iq_tdata   : out STD_LOGIC_VECTOR (31 downto 0);
            aclk              : in  STD_LOGIC;
            aresetn           : in  STD_LOGIC;
            s_axis_cfg_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdest  : in  STD_LOGIC_VECTOR (4 downto 0);
            s_axis_cfg_tvalid : in  STD_LOGIC;
            s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
            m_cfg_dout        : out STD_LOGIC_VECTOR (31 downto 0);
            m_ovf             : out STD_LOGIC_VECTOR (1 downto 0)
        );
    end component;

    -- Сигналы для подключения к UUT
    signal aclk              : std_logic := '0';
    signal aresetn           : std_logic := '1';
    signal s_axis_iq_tdata   : std_logic_vector(47 downto 0) := (others => '0');
    signal s_axis_adc_tdata  : std_logic_vector(15 downto 0) := (others => '0');
    signal m_axis_iq_tdata   : std_logic_vector(31 downto 0);
    signal s_axis_cfg_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid : std_logic := '0';
    signal s_axis_dds_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal m_cfg_dout        : std_logic_vector(31 downto 0);
    signal m_ovf             : std_logic_vector(1 downto 0);

    -- Константы тактовой частоты (122.88 МГц -> период ~8.138 нс)
    constant CLK_PERIOD : time := 8.138 ns;
    
    -- Сигналы внутренней генерации для симуляции
    signal sim_end       : boolean := false;
    signal tx_i_sim      : signed(23 downto 0) := (others => '0');
    signal tx_q_sim      : signed(23 downto 0) := (others => '0');
    
    -- Модель задержки и искажений усилителя мощности (PA Model)
    type delay_array is array (0 to 40) of signed(15 downto 0);
    signal pa_delay_line : delay_array := (others => (others => '0'));
    signal pa_output_distorted : signed(15 downto 0) := (others => '0');

begin

    -- Инстанцирование тестируемого модуля
    UUT: hf_dpd
        port map (
            s_axis_iq_tdata   => s_axis_iq_tdata,
            s_axis_adc_tdata  => s_axis_adc_tdata,
            m_axis_iq_tdata   => m_axis_iq_tdata,
            aclk              => aclk,
            aresetn           => aresetn,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            m_cfg_dout        => m_cfg_dout,
            m_ovf             => m_ovf
        );

    -- Генератор тактовой частоты (122.88 MHz)
    clk_process : process
    begin
        while not sim_end loop
            aclk <= '0';
            wait for CLK_PERIOD / 2;
            aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    -- Генератор тестовых сигналов (Генерация полезного НЧ сигнала 5 кГц и ВЧ DDS)
    stimulus_process : process
        variable seed1, seed2 : positive;
        variable rand         : real;
        variable phase_bb     : real := 0.0;
        variable phase_rf     : real := 0.0;
        
        -- Частота полезного сигнала (например, 5 кГц)
        constant FREQ_BB      : real := 5000.0; 
        -- Промежуточная частота для DDC (например, 20 МГц)
        constant FREQ_RF      : real := 20000000.0; 
        constant SAMPLE_RATE  : real := 122880000.0;
    begin
        -- Сброс и начальное ожидание
        wait for 100 ns;
        
        wait until rising_edge(aclk);
        aresetn <= '0';
        wait until rising_edge(aclk);
        wait until rising_edge(aclk);
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait until rising_edge(aclk);
        
        ---------------------------------------------------------------------
        -- Тест 1: Включение адаптации через шину конфигурации s_axis_cfg
        ---------------------------------------------------------------------
        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= "01010"; -- Адрес регистра разрешения LMS адаптации
        s_axis_cfg_tdata  <= x"00000001"; -- Включить ('1')
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        s_axis_cfg_tdest  <= (others => '0');
        s_axis_cfg_tdata  <= (others => '0');
        
        wait for 200 ns;

        ---------------------------------------------------------------------
        -- Тест 2: Подача непрерывного гармонического сигнала (IQ 5 кГц + DDS)
        ---------------------------------------------------------------------
        -- Запустим симуляцию на 1000 тысяч тактов для демонстрации сходимости
        for i in 0 to 1000000 loop
            wait until rising_edge(aclk);
            
            -- Вычисление фазы для Baseband (5 кГц)
            phase_bb := phase_bb + (2.0 * MATH_PI * FREQ_BB / SAMPLE_RATE);
            if phase_bb >= 2.0 * MATH_PI then phase_bb := phase_bb - (2.0 * MATH_PI); end if;
            
            -- Вычисление фазы для DDS (20 МГц)
            phase_rf := phase_rf + (2.0 * MATH_PI * FREQ_RF / SAMPLE_RATE);
            if phase_rf >= 2.0 * MATH_PI then phase_rf := phase_rf - (2.0 * MATH_PI); end if;

            -- 1. Моделируем входной IQ-сигнал передатчика (Амплитуда 70% от максимума)
            tx_i_sim <= to_signed(integer(8388607.0 * cos(phase_bb)), 24);
            tx_q_sim <= to_signed(integer(8388607.0 * sin(phase_bb)), 24);
            s_axis_iq_tdata <= std_logic_vector(tx_q_sim) & std_logic_vector(tx_i_sim);

            -- 2. Имитируем опорный квадратурный сигнал DDS для DDC приемника
            s_axis_dds_tdata(15 downto 0)  <= std_logic_vector(to_signed(integer(32767.0 * cos(phase_rf)), 16)); -- Cos
            s_axis_dds_tdata(31 downto 16) <= std_logic_vector(to_signed(integer(32767.0 * sin(phase_rf)), 16)); -- Sin
        end loop;

        -- Завершение симуляции
        wait for 10 us;
        sim_end <= true;
        wait;
    end process;

    -------------------------------------------------------------------------
    -- СИМУЛЯЦИОННАЯ МОДЕЛЬ КВ-ТРАКТА ПЕРЕДАТЧИКА (Усилитель мощности + АЦП)
    -------------------------------------------------------------------------
    -- Этот процесс перехватывает выходной сигнал DPD (`m_axis_iq_tdata`), 
    -- переносит его на ВЧ-частоту (ЦАП), вносит нелинейность 3-й степени (компрессию PA) 
    -- и возвращает на вход АЦП с задержкой в 32 такта.
    -------------------------------------------------------------------------
    pa_model_process : process(aclk)
        variable phase_rf_pa : real := 0.0;
        constant FREQ_RF     : real := 20000000.0;
        constant SAMPLE_RATE : real := 122880000.0;
        
        variable tx_out_i    : signed(15 downto 0);
        variable tx_out_q    : signed(15 downto 0);
        
        variable rf_modulated: real;
        variable rf_distorted: real;
    begin
        if rising_edge(aclk) then
            -- Выделяем I/Q сигналы после обработки DPD
            tx_out_i := signed(m_axis_iq_tdata(15 downto 0));
            tx_out_q := signed(m_axis_iq_tdata(31 downto 16));

            -- Модель модулятора ЦАП (Перенос Baseband IQ -> RF 20 МГц)
            phase_rf_pa := phase_rf_pa + (2.0 * MATH_PI * FREQ_RF / SAMPLE_RATE);
            rf_modulated := (real(to_integer(tx_out_i)) / 32768.0) * cos(phase_rf_pa) - 
                            (real(to_integer(tx_out_q)) / 32768.0) * sin(phase_rf_pa);

            -- Модель нелинейности Усилителя Мощности (Кубическая компрессия AM-AM):
            -- Y = X - 0.15 * X^3 (Моделирует сжатие амплитуды при пиках мощности)
            rf_distorted := rf_modulated - (0.15 * (rf_modulated * rf_modulated * rf_modulated));

            -- Линия задержки аналогового тракта + АЦП (32 такта)
            pa_delay_line(0) <= to_signed(integer(rf_distorted * 32767.0), 16);
            for i in 1 to 40 loop
                pa_delay_line(i) <= pa_delay_line(i-1);
            end loop;

            -- Возврат сигнала на вход АЦП (с задержкой, имитирующей фидер обратной связи)
            s_axis_adc_tdata <= std_logic_vector(pa_delay_line(32));
        end if;
    end process;

end Behavioral;
