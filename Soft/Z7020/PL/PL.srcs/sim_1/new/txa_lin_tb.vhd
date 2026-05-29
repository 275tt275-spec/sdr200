
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- Для функций sin/cos

entity tb_linear_dds_iq is
end tb_linear_dds_iq;

architecture sim of tb_linear_dds_iq is

    -- Параметры времени
    constant CLK_PERIOD : time := 8.138 ns; -- 122.88 MHz
    constant F_IF       : real := 1000000.0; -- ПЧ для теста 1 МГц

    -- Сигналы для подключения к UUT
    signal aclk         : std_logic := '0';
    signal s_axis_cfg_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tvalid : std_logic := '0';
    signal s_axis_cfg_tdest  : std_logic_vector(4 downto 0)  := (others => '0');
    
    signal s_axis_dds_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    
    signal din1_i       : std_logic_vector(23 downto 0) := (others => '0');
    signal din1_q       : std_logic_vector(23 downto 0) := (others => '0');
    signal din2         : std_logic_vector(15 downto 0) := (others => '0');
    signal dac         : std_logic_vector(15 downto 0) := (others => '0');
    
    signal dout_i       : std_logic_vector(23 downto 0);
    signal dout_q       : std_logic_vector(23 downto 0);
    
    -- Сама процедура (вставляется до ключевого слова begin)
    procedure write_cfg(
        constant dest : in integer;
        constant data : in integer;
        signal s_dest : out std_logic_vector(4 downto 0);
        signal s_data : out std_logic_vector(31 downto 0);
        signal s_valid : out std_logic
    ) is
    begin
        s_dest  <= std_logic_vector(to_unsigned(dest, 5));
        s_data  <= std_logic_vector(to_signed(data, 32));
        s_valid <= '1';
        wait for CLK_PERIOD;
        s_valid <= '0';
        wait for CLK_PERIOD; -- Пауза между командами
    end procedure;

begin

    aclk <= not aclk after CLK_PERIOD / 2; 

UUT: entity work.linear_dds_iq
    port map (
        -- Тактирование и сброс
        aclk              => aclk,
        ce                => '1',  
        
        -- Интерфейс конфигурации (AXI-Stream)
        s_axis_cfg_tdata  => s_axis_cfg_tdata,
        s_axis_cfg_tvalid => s_axis_cfg_tvalid,
        s_axis_cfg_tdest  => s_axis_cfg_tdest,

        -- Входы данных (Baseband)
        din1_i            => din1_i,   -- Опорный сигнал I
        din1_q            => din1_q,   -- Опорный сигнал Q
        din2              => din2,     -- Сигнал обратной связи от АЦП
        
        s_axis_dds_tdata  => s_axis_dds_tdata,

        -- Входы от DDS (условные, если ты вывел их на верхний уровень)
 --       cos_in            => dds_cos,  -- Сигнал Cos из DDS IP
 --       sin_in            => dds_sin,  -- Сигнал Sin из DDS IP

        -- Выходы коррекции
        dout_i            => dout_i,
        dout_q            => dout_q
    );

    -- Основной процесс стимулов
    stim_proc: process
        variable phase_sig : real := 0.0;
        variable phase_dds : real := 0.0;
        variable mult : real;
        variable v_real_i, v_real_q : real;
         variable v_sum_iq          : real;
         variable v_fb_linear       : real;
         variable v_fb_nonlin       : real;
         constant k_nonlin          : real := 0.0000000008; -- Коэффициент искажений (подберите для эффекта)
         
        -- Параметры задержки
        constant FEEDBACK_DELAY_CLKS : integer := 10; -- Задержка 10 тактов
        type delay_buffer_t is array (0 to FEEDBACK_DELAY_CLKS) of integer;
        variable delay_buf : delay_buffer_t := (others => 0);        
        variable v_fb_raw : integer; -- Значение до задержки
    
    begin
        -- 1. Инициализация
        wait for 100 ns;
        
        write_cfg(2, 5, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- AGC_K
        write_cfg(11, 0, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- phi_sin
        write_cfg(12, 32767, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- phi_cos
        
        mult := 2048.0 / (2.0 * sin(MATH_PI * F_IF / 122880000.0));
        write_cfg(7, integer(mult), s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        mult := 2048.0 / (2.0 * cos(MATH_PI * F_IF / 122880000.0));
        write_cfg(8, integer(mult), s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        
        -- 2. Настройка линеаризатора через конфигурационный порт
        -- Запись K_PROP 
        write_cfg(6, 3000, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);        
        -- Запись K_STAB
        write_cfg(14, 1000, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        -- Запись K_DIFF
        write_cfg(13, 0, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        
        -- Сброс и Включение (адрес F, bit0=CLR, bit1=ON)
        write_cfg(15, 1, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);
        wait for 10 * CLK_PERIOD;
        write_cfg(15, 6, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);        
        wait for 10 * CLK_PERIOD;

        -- 3. Цикл симуляции сигналов
        -- Генерируем тестовый тон 500 кГц
        for i in 0 to 1000000 loop
        
            -- Имитация полезного сигнала (Baseband 10 кГц)
            phase_sig := 2.0 * MATH_PI * 10000.0 * real(i) / 122880000.0;
            din1_i <= std_logic_vector(to_signed(integer(4000000.0 * cos(phase_sig)), 24));
            din1_q <= std_logic_vector(to_signed(integer(4000000.0 * sin(phase_sig)), 24));
           
            -- Имитация DDS (Cos в 31..16, Sin в 15..0)
            phase_dds := 2.0 * MATH_PI * F_IF * real(i) / 122880000.0;
            s_axis_dds_tdata(31 downto 16) <= std_logic_vector(to_signed(integer(32000.0 * sin(phase_dds)), 16));
            s_axis_dds_tdata(15 downto 0)  <= std_logic_vector(to_signed(integer(32000.0 * cos(phase_dds)), 16));
            
             -- Считаем "реальный" I и Q на выходе ПЛИС (Сигнал + Коррекция)
  --          v_real_i := real(to_integer(signed(din1_i))) + real(to_integer(signed(dout_i)));
  --          v_real_q := real(to_integer(signed(din1_q))) + real(to_integer(signed(dout_q)));
            
            v_real_i := real(to_integer(signed(dout_i)));
            v_real_q := real(to_integer(signed(dout_q)));
            
            -- Переносим на ПЧ (моделируем работу DUC и передатчика)
            -- Добавляем "просадку" усиления
            v_fb_linear := (v_real_i * cos(phase_dds) - v_real_q * sin(phase_dds)) * 0.00390625;
            dac <= std_logic_vector(to_signed(integer(v_fb_linear), 16));
            
                -- 3. МОДЕЛЬ НЕЛИНЕЙНОСТИ (Compression Model)
            -- Формула: Out = G * (In - k * In^3)
            -- Где In^3 создает гармоники и интермодуляцию
            v_fb_nonlin := 1.2 * (v_fb_linear - (k_nonlin * (v_fb_linear**3)));
            
            v_fb_raw := integer(v_fb_nonlin);

            -- 2. РЕАЛИЗАЦИЯ ЗАДЕРЖКИ (Shift Register)
            -- Сдвигаем данные в массиве
            for j in FEEDBACK_DELAY_CLKS downto 1 loop
                delay_buf(j) := delay_buf(j-1);
            end loop;
            -- Записываем текущий результат в начало
            delay_buf(0) := v_fb_raw;
                
            -- Подаем на вход АЦП (с небольшим шумом и DC смещением)
           din2 <= std_logic_vector(to_signed(integer(v_fb_linear) + 500, 16));
  --         din2 <= std_logic_vector(to_signed(integer(v_fb_nonlin) + 500, 16));
 
             -- 3. Подача задержанного сигнала на АЦП
            -- Считываем "старое" значение из конца буфера
--          din2 <= std_logic_vector(to_signed(delay_buf(FEEDBACK_DELAY_CLKS) + 500, 16));
   
 --           -- Имитация АЦП (Сигнал + Смещение + Потеря усиления)
 --           -- Переносим Baseband на ПЧ (F_IF) для эмуляции того, что видит АЦП
 --           din2 <= std_logic_vector(to_signed(integer(12000.0 * cos(phase_sig + phase_dds)) + 800, 16));
            
            wait for CLK_PERIOD;
        end loop;

        -- Завершение симуляции
        report "Simulation Finished";
        wait;
    end process;

end sim;
