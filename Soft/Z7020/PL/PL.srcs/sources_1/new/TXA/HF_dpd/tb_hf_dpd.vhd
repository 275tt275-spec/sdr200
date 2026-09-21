library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_hf_dpd is
-- Тестбенч не имеет портов
end tb_hf_dpd;

architecture Behavioral of tb_hf_dpd is

    -- Component Under Test
    component hf_dpd
        Port ( 
            s_axis_iq_tdata   : in  STD_LOGIC_VECTOR (47 downto 0);
            s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
            m_axis_iq_tdata   : out STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdest  : in  STD_LOGIC_VECTOR (4 downto 0);
            s_axis_cfg_tvalid : in  STD_LOGIC;
            txa_on            : in  STD_LOGIC;
            s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
            m_cfg_dout        : out STD_LOGIC_VECTOR (31 downto 0);
            aclk              : in  STD_LOGIC;
            aresetn           : in  STD_LOGIC
        );
    end component;

    -- Сигналы связи
    signal s_axis_iq_tdata   : STD_LOGIC_VECTOR (47 downto 0) := (others => '0');
    signal s_axis_adc_tdata  : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal m_axis_iq_tdata   : STD_LOGIC_VECTOR (31 downto 0);
    signal s_axis_cfg_tdata  : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : STD_LOGIC_VECTOR (4 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid : STD_LOGIC := '0';
    signal txa_on            : STD_LOGIC := '0';
    signal s_axis_dds_tdata  : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal m_cfg_dout        : STD_LOGIC_VECTOR (31 downto 0);
    signal aclk              : STD_LOGIC := '0';
    signal aresetn           : STD_LOGIC := '0';

    -- Константы тактирования и частот
    constant CLK_PERIOD     : time := 8138 ps; -- 122.88 MHz
    constant CLK_FREQ       : real := 122880000.0;
    constant DDS_FREQ       : real := 5000000.0; -- 5 МГц несущая
    constant IQ_SIGNAL_FREQ : real := 5000.0;    -- 5 кГц полезный сигнал
    constant TONE1_FREQ : real := 4000.0; 
    constant TONE2_FREQ : real := 6000.0;

    -- Сигналы для реализации конвейера задержки в обратной связи (моделирование кабеля/тракта)
    type delay_array is array (0 to 3) of real;
    signal loopback_delay_line : delay_array := (others => 0.0);

begin

    -- Инициализация UUT
    uut: hf_dpd
        port map (
            s_axis_iq_tdata   => s_axis_iq_tdata,
            s_axis_adc_tdata  => s_axis_adc_tdata,
            m_axis_iq_tdata   => m_axis_iq_tdata,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            txa_on            => txa_on,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            m_cfg_dout        => m_cfg_dout,
            aclk              => aclk,
            aresetn           => aresetn
        );

    -- Генератор aclk (122.88 МГц)
    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD / 2;
        aclk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

        -- Процесс генерации сигналов и замкнутая петля обратной связи (Loopback) без переполнения
    signal_generation_process: process(aclk)
        variable sample_idx    : integer := 0;
        variable phase_dds     : real;
        variable phase_iq      : real;
        
        constant AMP_24BIT     : real := 4388000.0; 
        -- Фазы для двух тонов
        variable phase_tone1   : real;
        variable phase_tone2   : real;
        
        -- Переменные для генератора (вход)
        variable i_signal_val  : integer;
        variable q_signal_val  : integer;
        
        -- Переменные DDS
        variable dds_cos, dds_sin : real;
        variable dds_cos_int   : integer;
        variable dds_sin_int   : integer;
        
        -- Переменные для разбора выхода m_axis_iq_tdata
        variable m_iq_i        : signed(15 downto 0);
        variable m_iq_q        : signed(15 downto 0);
        
        -- Переменные нормализованной математики (диапазон от -1.0 до 1.0)
        variable i_norm        : real;
        variable q_norm        : real;
        variable tx_rf_norm    : real;
        variable fb_rf_norm    : real;
        
        -- Переменные для АЦП
        variable fb_rf_final   : real;
        variable seed1, seed2  : positive := 98765; -- Для генератора шума
        variable rand_norm     : real;
        variable noise         : real;
        
        -- Параметры радио-тракта (физически корректные)
        constant ATTENUATION   : real := 0.9;        -- Затухание в петле (тракт + аттенюатор)
        constant DISTORTION_K3 : real := 0.15;        -- 5% нелинейных искажений 3-го порядка (PA)
        constant NOISE_FLOOR   : real := 10.0;        -- Небольшой шум АЦП (в младших разрядах)

    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                sample_idx          := 0;
                s_axis_dds_tdata    <= (others => '0');
                s_axis_adc_tdata    <= (others => '0');
                s_axis_iq_tdata     <= (others => '0');
                loopback_delay_line <= (others => 0.0);
            else
                ----------------------------------------------------------------
                -- 1. ВХОДНОЙ ДВУТОНАЛЬНОЙ СИГНАЛ (Каждый тон берет половину амплитуды)
                ----------------------------------------------------------------
                phase_tone1  := 2.0 * MATH_PI * TONE1_FREQ * real(sample_idx) / CLK_FREQ;
                phase_tone2  := 2.0 * MATH_PI * TONE2_FREQ * real(sample_idx) / CLK_FREQ;
                
                -- Линейное сложение компонент I и Q для обоих тонов
                i_signal_val := integer((cos(phase_tone1) * (AMP_24BIT / 2.0)) + (cos(phase_tone2) * (AMP_24BIT / 2.0)));
                q_signal_val := integer((sin(phase_tone1) * (AMP_24BIT / 2.0)) + (sin(phase_tone2) * (AMP_24BIT / 2.0)));
                
                if sample_idx > 10000 and sample_idx < 11000 then
                    s_axis_iq_tdata(23 downto 0) <= std_logic_vector(to_signed(4194304, 24));
                    s_axis_iq_tdata(47 downto 24) <= std_logic_vector(to_signed(q_signal_val, 24));
                else
                    s_axis_iq_tdata(23 downto 0)  <= std_logic_vector(to_signed(i_signal_val, 24));
                    s_axis_iq_tdata(47 downto 24) <= std_logic_vector(to_signed(q_signal_val, 24));
                end if;


                ----------------------------------------------------------------
                -- 2. ОПОРНЫЙ ГЕНЕРАТОР DDS (5 МГц, 16 бит)
                ----------------------------------------------------------------
                phase_dds   := 2.0 * MATH_PI * DDS_FREQ * real(sample_idx) / CLK_FREQ;
                dds_cos     := cos(phase_dds);
                dds_sin     := sin(phase_dds);
                
                dds_cos_int := integer(dds_cos * 32767.0);
                dds_sin_int := integer(dds_sin * 32767.0);
                
                s_axis_dds_tdata(15 downto 0)  <= std_logic_vector(to_signed(dds_cos_int, 16));
                s_axis_dds_tdata(31 downto 16) <= std_logic_vector(to_signed(dds_sin_int, 16));
 --               s_axis_dds_tdata(31 downto 16) <= std_logic_vector(to_signed(-dds_sin_int, 16));

                ----------------------------------------------------------------
                -- 3. СТАБИЛЬНАЯ ПЕТЛЯ ОБРАТНОЙ СВЯЗИ (НОРМАЛИЗОВАННАЯ)
                ----------------------------------------------------------------
                -- Шаг А: Извлекаем 16-битный выход DPD
                m_iq_i := signed(m_axis_iq_tdata(15 downto 0));
                m_iq_q := signed(m_axis_iq_tdata(31 downto 16));
                
                -- Шаг Б: Переводим в нормализованный вид (-1.0 ... 1.0)
                i_norm := real(to_integer(m_iq_i)) / 32768.0;
                q_norm := real(to_integer(m_iq_q)) / 32768.0;
                
                -- Шаг В: Модуляция на несущую (ВЧ сигнал на выходе ЦАП, диапазон прибл. -1.0...+1.0)
               tx_rf_norm := (i_norm * dds_cos) - (q_norm * dds_sin);
                
                -- Шаг Г: Вносим искажения усилителя мощности (PA) в нормализованном виде.
                -- Теперь куб от числа меньше единицы не улетает в бесконечность, а уменьшается!
                tx_rf_norm := tx_rf_norm - (DISTORTION_K3 * (tx_rf_norm ** 3));

                -- Шаг Д: Линия задержки в кабеле/тракте (на 4 такта)
                loopback_delay_line(0) <= tx_rf_norm;
                for k in 1 to 3 loop
                    loopback_delay_line(k) <= loopback_delay_line(k-1);
                end loop;
               fb_rf_norm := loopback_delay_line(3); 
--                fb_rf_norm := tx_rf_norm;
                
                -- Шаг Е: Применяем затухание в канале
                fb_rf_norm := fb_rf_norm * ATTENUATION;
                
                -- Шаг Ж: Денормализация обратно в шкалу 16-битного АЦП (+ добавляем шум)
                UNIFORM(seed1, seed2, rand_norm);
                noise        := (rand_norm - 0.5) * NOISE_FLOOR;
                fb_rf_final  := (fb_rf_norm * 32767.0) + noise;
                
                -- Шаг З: Жесткое ограничение (Saturate) для безопасности
                if fb_rf_final > 32767.0 then
                    s_axis_adc_tdata <= std_logic_vector(to_signed(32767, 16));
                elsif fb_rf_final < -32768.0 then
                    s_axis_adc_tdata <= std_logic_vector(to_signed(-32768, 16));
                else
                    s_axis_adc_tdata <= std_logic_vector(to_signed(integer(fb_rf_final), 16));
                end if;
                
                sample_idx := sample_idx + 1;
            end if;
        end if;
    end process;


        -- Основной тестовый сценарий управления и конфигурации
    stimulus_process: process
        -- Переменные для расчета коэффициентов компенсации (аналог Си-функции)
        constant HW_ADC_SAMPLERATE : real := 122880000.0; -- 122.88 МГц
        constant MULT_K            : real := 1.0;
        
        -- Рассчитаем коэффициенты для частоты DDS несущей (5.0 МГц)
        variable freq              : real := DDS_FREQ; 
        variable i_corr_float      : real;
        variable q_corr_float      : real;
        
        variable i_corr_int        : integer;
        variable q_corr_int        : integer;
    begin
        ------------------------------------------------------------------------
        -- МАТЕМАТИЧЕСКИЙ РАСЧЕТ КОЭФФИЦИЕНТОВ (Аналог hw_SetLinerDDSIn)
        ------------------------------------------------------------------------
        -- Формула из Си: mult_k * 2048 / (2 * sinf(M_PI * freq / SAMPLERATE))
        i_corr_float := (MULT_K * 2048.0) / (2.0 * sin(MATH_PI * freq / HW_ADC_SAMPLERATE));
        q_corr_float := (MULT_K * 2048.0) / (2.0 * cos(MATH_PI * freq / HW_ADC_SAMPLERATE));
        
        -- Так как в VHDL регистры имеют разрядность 18 бит (i_corr_amp/q_corr_amp),
        -- а исходный сброс x"7fff" & "00" сдвигает 16-битное число на 2 бита влево, 
        -- переведем вещественное число в формат Fixed-Point (умножаем на 4, то есть сдвиг на 2 бита):
        i_corr_int := integer(i_corr_float);
        q_corr_int := integer(q_corr_float);
        
        ------------------------------------------------------------------------
        -- ИНИЦИАЛИЗАЦИЯ И СБРОС СХЕМЫ
        ------------------------------------------------------------------------
        aresetn           <= '0';
        txa_on            <= '0';
        s_axis_cfg_tvalid <= '0';
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdest  <= (others => '0');
        wait for 200 ns;
        
        -- Снятие сброса и включение передатчика
        aresetn <= '1';
        wait for 100 ns;
        txa_on <= '1';
                
        ------------------------------------------------------------------------
        -- ЗАПИСЬ КОЭФФИЦИЕНТОВ ЧЕРЕЗ КОНФИГУРАЦИОННУЮ ШИНУ AXI (ИСПРАВЛЕНО)
        ------------------------------------------------------------------------
        -- Ждем стабильного фронта тактов
        wait until rising_edge(aclk);        
        -- 1. Запись i_corr_amp (Адрес / tdest = 7)
        s_axis_cfg_tdest  <= std_logic_vector(to_unsigned(7, 5));
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdata(17 downto 0) <= std_logic_vector(to_signed(i_corr_int, 18));
        s_axis_cfg_tvalid <= '1'; -- Выставляем tvalid одновременно с данными!
        wait until rising_edge(aclk);    
        s_axis_cfg_tvalid <= '0';
        wait for 5 * CLK_PERIOD;  -- Пауза
        
        -- 2. Запись q_corr_amp (Адрес / tdest = 8)
        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= std_logic_vector(to_unsigned(8, 5));
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdata(17 downto 0) <= std_logic_vector(to_signed(q_corr_int, 18));
        s_axis_cfg_tvalid <= '1'; -- Выставляем одновременно с данными!
        wait until rising_edge(aclk);     
        s_axis_cfg_tvalid <= '0';
        wait for 5 * CLK_PERIOD;

        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= "00000";       -- Адрес 0: Управление
        s_axis_cfg_tdata  <= x"00000004";   -- train=1, hold=0, bypass=1
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        -- Работа в Bypass по умолчанию
 --       wait for 20000 * CLK_PERIOD; 
        
           wait until rising_edge(aclk);            
           s_axis_cfg_tdest  <= "00001";       
           s_axis_cfg_tdata  <= std_logic_vector(to_unsigned(18, 32));   
           s_axis_cfg_tvalid <= '1';            
           wait until rising_edge(aclk);            
           s_axis_cfg_tvalid <= '0';         
           wait until rising_edge(aclk);            
           s_axis_cfg_tdest  <= "00010";       
           s_axis_cfg_tdata  <= std_logic_vector(to_unsigned(32, 32));   
           s_axis_cfg_tvalid <= '1';            
           wait until rising_edge(aclk);            
           s_axis_cfg_tvalid <= '0';     
           wait for 20000 * CLK_PERIOD; 
        
  --     for i in 0 to 29 loop
  --          wait until rising_edge(aclk);            
  --          s_axis_cfg_tdest  <= "00001";       
  --          s_axis_cfg_tdata  <= std_logic_vector(to_unsigned(i, 32));   
  --          s_axis_cfg_tvalid <= '1';            
  --          wait until rising_edge(aclk);            
  --          s_axis_cfg_tvalid <= '0';            
  --          wait for 20000 * CLK_PERIOD; 
  --      end loop;
 
 --      wait for 20000 * CLK_PERIOD; 

        ------------------------------------------------------------------------
        -- АКТИВАЦИЯ РЕЖИМА DPD (Выключение Bypass)
        ------------------------------------------------------------------------
        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= "00000";       -- Адрес 0: Управление
        s_axis_cfg_tdata  <= x"00000001";   -- train=1, hold=0, bypass=0
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);wait for CLK_PERIOD;
        s_axis_cfg_tvalid <= '0';
        
        -- Длительная симуляция для наблюдения адаптации с новыми амплитудами
        wait for 1000000 * CLK_PERIOD;

        -- Завершение работы
        assert false report "Simulation Finished successfully with Calculated Amploc coefficients!" severity failure;
        wait;
    end process;


end Behavioral;
