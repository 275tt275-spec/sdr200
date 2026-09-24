library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- Используется для прецизионной генерации синуса и шума в модели

entity tb_linear_18 is
-- У тестбенча нет портов
end tb_linear_18;

architecture Behavioral of tb_linear_18 is

    -- Прецизионная временная константа для 122.88 МГц
    constant CLK_PERIOD : time := 8138 ps; 

    -- Входные сигналы для UUT
    signal din1_i           : std_logic_vector(17 downto 0) := (others => '0');
    signal din1_q           : std_logic_vector(17 downto 0) := (others => '0');
    signal din2             : std_logic_vector(15 downto 0) := (others => '0');
    signal aclk             : std_logic := '0';
    signal ce               : std_logic := '1';
    signal s_axis_cfg_tdata : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid: std_logic := '0';
    signal s_axis_dds_tdata : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Сигналы для реализации конвейера задержки в обратной связи (моделирование кабеля/тракта)
    type delay_array is array (0 to 3) of real;
    signal loopback_delay_line : delay_array := (others => 0.0);

    -- Выходные сигналы из UUT
    signal dout_i           : std_logic_vector(15 downto 0);
    signal dout_q           : std_logic_vector(15 downto 0);
    signal cfg_dout         : std_logic_vector(31 downto 0);
    signal m_ovf            : std_logic_vector(3 downto 0);

    -- Процедура для безопасной записи конфигурационных регистров
    procedure write_cfg (
        constant addr : in std_logic_vector(4 downto 0);
        constant data : in std_logic_vector(31 downto 0);
        signal clk    : in std_logic;
        signal c_dest : out std_logic_vector(4 downto 0);
        signal c_data : out std_logic_vector(31 downto 0);
        signal c_wr   : out std_logic
    ) is
    begin
        wait until falling_edge(clk);
        c_dest   <= addr;
        c_data   <= data;
        c_wr     <= '1';
        wait until falling_edge(clk);
        c_wr     <= '0';
        c_data   <= (others => '0');
        c_dest   <= (others => '0');
    end procedure;

begin

    -- Инстанцирование тестируемого модуля (UUT)
    uut: entity work.linear_18
        port map (
            din1_i            => din1_i,
            din1_q            => din1_q,
            din2              => din2,
            aclk              => aclk,
            ce                => ce,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            dout_i            => dout_i,
            dout_q            => dout_q,
            cfg_dout          => cfg_dout,
            m_ovf             => m_ovf
        );

    -- Генератор системного тактового сигнала (122.88 МГц)
    clk_gen_proc : process
    begin
        aclk <= '0'; wait for CLK_PERIOD / 2;
        aclk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Основной процесс генерации воздействий
    stim_proc : process
        -- Переменные для генерации математически точного тона и шумов
        variable seed1, seed2   : positive := 777;
        variable rand_val       : real;
        variable noise_val      : integer;
        variable theta_sig1     : real := 0.0;
        variable theta_sig2     : real := 0.0;
        variable theta_lo       : real := 0.0;
        
        -- Частоты процессов симуляции
        constant F_SIG          : real := 5000.0;  -- Полезный сигнал 5 КГц
        constant F_SIG1         : real := 5000.0;  -- Полезный сигнал 5 КГц
        constant F_SIG2         : real := 7000.0;  -- Полезный сигнал 5 КГц
        constant F_LO           : real := 10000000.0;   -- Сигнал гетеродина 10 МГц
        constant F_S            : real := 122880000.0;-- Частота выборки АЦП/ЦАП
        
        -- Амплитуды режимов согласно спецификации задания
        constant AMP_FULL       : real := 131000.0; -- 100% Full Scale (18-бит знаковое)
        constant AMP_HALF       : real := 65535.0;  -- 50% Half Scale
        constant AMP_SMALL      : real := 73.0;     -- -65 дБ от Full Scale (131071 * 10^(-65/20))
        
        variable current_amp    : real := AMP_FULL;
        variable i_wave, q_wave : integer;
        variable lo_i, lo_q     : integer;
        variable adc_fb         : integer;
        constant HW_ADC_SAMPLERATE : real := 122880000.0; -- 122.88 МГц
        constant MULT_K            : real := 1.0;
        variable freq              : real := F_LO; 
        variable i_corr_float      : real;
        variable q_corr_float      : real;        
        variable i_corr_int        : integer;
        variable q_corr_int        : integer;
        
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
        variable seed11, seed12  : positive := 98765; -- Для генератора шума
        variable rand_norm     : real;
        variable noise         : real;
        variable dds_cos, dds_sin : real;
        variable att_am : real := 0.0;
                
        -- Параметры радио-тракта (физически корректные)
        constant ATTENUATION   : real := 1.0;        -- Затухание в петле (тракт + аттенюатор)
        constant DISTORTION_K3 : real := 0.3;        -- 5% нелинейных искажений 3-го порядка (PA)
        constant NOISE_FLOOR   : real := 10.0;        -- Небольшой шум АЦП (в младших разрядах)
        
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
        
        -- Шаг 1: Инициализация и сброс цифрового ядра
        ce               <= '1';
        din1_i           <= (others => '0');
        din1_q           <= (others => '0');
        din2             <= (others => '0');
        s_axis_cfg_tdata <= (others => '0');
        s_axis_cfg_tdest <= (others => '0');
        s_axis_cfg_tvalid<= '0';
        wait for 200 ns;

        -- Включаем линеаризатор и сопутствующие узлы через служебный регистр 0x0F
        -- Бит 0: lin_clr='0', Бит 1: lin_on='1', Бит 2: agc_on='1', Бит 3: phase_slow='1'
        write_cfg("01111", x"0000000e", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        write_cfg("00110", x"000007d0", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- prop
        write_cfg("01110", x"000001F4", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- stab
        -- Устанавливаем коэффициенты Gain по умолчанию (0x7FFF)
        write_cfg("00011", x"00007FFF", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- gain_I
        write_cfg("00100", x"00007FFF", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- gain_Q
        write_cfg(std_logic_vector(to_unsigned(7, 5)), std_logic_vector(to_signed(i_corr_int, 32)), aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        write_cfg(std_logic_vector(to_unsigned(8, 5)), std_logic_vector(to_signed(q_corr_int, 32)), aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        wait for 100 ns;

        -- Шаг 2: Цикл сквозного потокового моделирования по режимам
        for mode in 1 to 5 loop
            
            -- Выбор режима амплитуды din1
            case mode is
                when 1 => current_amp := AMP_HALF;  
                when 2 => current_amp := AMP_SMALL; 
                when 3 => current_amp := 0.0;       
                when 4 => current_amp := AMP_HALF;
                when others => current_amp := AMP_FULL;
            end case;

            -- Моделируем каждый режим на протяжении 100000 тактов
            for t in 0 to 100000 loop
                wait until falling_edge(aclk);
                
                -- Расчет фаз сигналов для текущего шага времени
                theta_sig1 := 2.0 * MATH_PI * F_SIG1 * real(t) / F_S;
                theta_sig2 := 2.0 * MATH_PI * F_SIG2 * real(t) / F_S;
                theta_lo   := 2.0 * MATH_PI * F_LO * real(t) / F_S;
                
                -- Генерация комплексного полезного сигнала din1
                if mode = 4 then
                    -- ДОБАВЛЕНО: Генерация двухтонального сигнала на половину шкалы
                    -- Каждый из двух тонов берет ровно половину от AMP_HALF
                    i_wave := integer((current_amp / 2.0) * cos(theta_sig1) + (current_amp / 2.0) * cos(theta_sig2));
                    q_wave := integer((current_amp / 2.0) * sin(theta_sig1) + (current_amp / 2.0) * sin(theta_sig2));
                elsif mode /= 3 then
                    -- Обычный однотональный режим
                    i_wave := integer(current_amp * cos(theta_sig1));
                    q_wave := integer(current_amp * sin(theta_sig1));
                else
                    -- Режим тишины (только шум)
                    i_wave := 0;
                    q_wave := 0;
                end if;
                
                -- Генерация аддитивного белого шума малого уровня (RMS ~ 4 LSB)
                UNIFORM(seed1, seed2, rand_val);
                noise_val := integer((rand_val - 0.5) * 16.0);
                
                -- Применяем данные к входным шинам din1 (с учетом шума)
                din1_i <= std_logic_vector(to_signed(i_wave + noise_val, 18));
                din1_q <= std_logic_vector(to_signed(q_wave + noise_val, 18));

                -- Генерация ортогональных квадратур гетеродина DDS (16 бит)
                lo_i := integer(32767.0 * cos(theta_lo));
                lo_q := integer(32767.0 * sin(theta_lo));
                s_axis_dds_tdata <= std_logic_vector(to_signed(lo_q, 16)) & std_logic_vector(to_signed(lo_i, 16));
                
                ----------------------------------------------------------------
                -- 3. СТАБИЛЬНАЯ ПЕТЛЯ ОБРАТНОЙ СВЯЗИ (НОРМАЛИЗОВАННАЯ)
                ----------------------------------------------------------------
                -- Шаг А: Извлекаем 16-битный выход DPD
                m_iq_i := signed(dout_i);
                m_iq_q := signed(dout_q);
                
                -- Шаг Б: Переводим в нормализованный вид (-1.0 ... 1.0)
                i_norm := real(to_integer(m_iq_i)) / 32768.0;
                q_norm := real(to_integer(m_iq_q)) / 32768.0;
                
                -- Шаг В: Модуляция на несущую (ВЧ сигнал на выходе ЦАП, диапазон прибл. -1.0...+1.0)
               tx_rf_norm := (i_norm * dds_cos) - (q_norm * dds_sin);
                
                -- Шаг Г: Вносим искажения усилителя мощности (PA) в нормализованном виде.
                -- Теперь куб от числа меньше единицы не улетает в бесконечность, а уменьшается!
                tx_rf_norm := tx_rf_norm - (DISTORTION_K3 * (tx_rf_norm ** 3));
                dds_cos     := cos(theta_lo);
                dds_sin     := sin(theta_lo);

                -- Шаг Д: Линия задержки в кабеле/тракте (на 4 такта)
                loopback_delay_line(0) <= tx_rf_norm;
                for k in 1 to 3 loop
                    loopback_delay_line(k) <= loopback_delay_line(k-1);
                end loop;
               fb_rf_norm := loopback_delay_line(3); 
--                fb_rf_norm := tx_rf_norm;
                
                -- Шаг Е: Применяем затухание в канале
                fb_rf_norm := fb_rf_norm * att_am;
                if(att_am < ATTENUATION) then
                    att_am := att_am + 0.00002;
                end if;    
                
                -- Шаг Ж: Денормализация обратно в шкалу 16-битного АЦП (+ добавляем шум)
                UNIFORM(seed11, seed12, rand_norm);
                noise        := (rand_norm - 0.5) * NOISE_FLOOR;
                fb_rf_final  := (fb_rf_norm * 32767.0) + noise;
                
                -- Шаг З: Жесткое ограничение (Saturate) для безопасности
                if fb_rf_final > 32767.0 then
                    din2 <= std_logic_vector(to_signed(32767, 16));
                elsif fb_rf_final < -32768.0 then
                    din2 <= std_logic_vector(to_signed(-32768, 16));
                else
                    din2 <= std_logic_vector(to_signed(integer(fb_rf_final), 16));
                end if;

            end loop;
        end loop;

        -- Завершение теста
        wait for 10 us;
        assert false report "All linear_18 test modes successfully completed!" severity failure;
        wait;
    end process;

end Behavioral;
