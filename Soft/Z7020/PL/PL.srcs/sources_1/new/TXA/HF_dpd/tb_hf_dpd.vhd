library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

-- Библиотеки для работы с файлами
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_hf_dpd is
end tb_hf_dpd;

architecture Behavioral of tb_hf_dpd is
    -- Тактирование и сброс
    signal aclk          : STD_LOGIC := '0';
    signal aresetn       : STD_LOGIC := '0';
    
    -- AXI Stream вход (I/Q данные)
    signal s_axis_iq_tdata  : STD_LOGIC_VECTOR(47 downto 0) := (others => '0');
    
    -- Вход с АЦП (обратная связь) - РЕАЛЬНЫЙ СИГНАЛ
    signal s_axis_adc_tdata  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    
    -- Выход I/Q после линеаризации
    signal m_axis_iq_tdata   : STD_LOGIC_VECTOR(31 downto 0);
    
    -- Управление через конфигурационный интерфейс
    signal s_axis_cfg_tdata  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');
    signal s_axis_cfg_tvalid : STD_LOGIC := '0';
    
    -- DDS для DDC (I/Q сигналы)
    signal s_axis_dds_tdata  : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    
    -- Выход конфигурации
    signal m_cfg_dout        : STD_LOGIC_VECTOR(31 downto 0);
    
    -- Статус переполнения
    signal m_ovf             : STD_LOGIC_VECTOR(1 downto 0);
    
    -- Сигналы для PA модели
    signal pa_input_i, pa_input_q : signed(15 downto 0) := (others => '0');
    signal pa_output_i, pa_output_q : signed(15 downto 0) := (others => '0');
    signal pa_output_real : signed(15 downto 0) := (others => '0');
    
    -- Сигналы для DDS генератора (I/Q)
    signal dds_phase_acc     : unsigned(31 downto 0) := (others => '0');
    signal dds_sin           : signed(15 downto 0) := (others => '0');
    signal dds_cos           : signed(15 downto 0) := (others => '0');
    
    -- Сигналы для тестового сигнала (вход DPD)
    signal test_i_24, test_q_24 : signed(23 downto 0) := (others => '0');
    signal test_phase_acc    : unsigned(31 downto 0) := (others => '0');
    
    -- Константы
    constant CLK_PERIOD      : time := 8.138 ns; -- 122.88 MHz
    constant DDS_FREQ        : real := 10.0e6;   -- 10 МГц для DDC
    constant TEST_FREQ       : real := 5000.0;   -- 5 кГц тестовый сигнал
    constant SAMPLE_RATE     : real := 122.88e6;
    constant DDS_PHASE_INC   : unsigned(31 downto 0) := to_unsigned(integer(round(DDS_FREQ / SAMPLE_RATE * 2.0**32)), 32);
    constant TEST_PHASE_INC  : unsigned(31 downto 0) := to_unsigned(integer(round(TEST_FREQ / SAMPLE_RATE * 2.0**32)), 32);
    
    -- Сигналы для логирования
    signal log_enable  : STD_LOGIC := '0';
    signal log_counter : integer := 0;
    
begin
    -- ========================================================================
    -- 1. Генерация тактового сигнала
    -- ========================================================================
    process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- ========================================================================
    -- 2. Тестируемый модуль
    -- ========================================================================
    DUT: entity work.hf_dpd
        Port map (
            aclk              => aclk,
            aresetn           => aresetn,
            s_axis_iq_tdata   => s_axis_iq_tdata,
            s_axis_adc_tdata  => s_axis_adc_tdata,
            m_axis_iq_tdata   => m_axis_iq_tdata,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            m_cfg_dout        => m_cfg_dout,
            m_ovf             => m_ovf
        );
    
    -- ========================================================================
    -- 3. ГЕНЕРАТОР DDS (ДЛЯ DDC)
    -- ========================================================================
    process(aclk)
        variable sin_val, cos_val : real;
        variable sin_int, cos_int : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                dds_phase_acc <= (others => '0');
                dds_sin <= (others => '0');
                dds_cos <= (others => '0');
            else
                dds_phase_acc <= dds_phase_acc + DDS_PHASE_INC;
                
                sin_val := sin(2.0 * MATH_PI * real(to_integer(dds_phase_acc)) / 2.0**32);
                cos_val := cos(2.0 * MATH_PI * real(to_integer(dds_phase_acc)) / 2.0**32);
                
                sin_int := integer(round(sin_val * 32767.0));
                cos_int := integer(round(cos_val * 32767.0));
                
                dds_sin <= to_signed(sin_int, 16);
                dds_cos <= to_signed(cos_int, 16);
            end if;
        end if;
    end process;
    
    -- Формат: {Q(15:0), I(15:0)}
    s_axis_dds_tdata <= std_logic_vector(dds_sin) & std_logic_vector(dds_cos);
    
    -- ========================================================================
    -- 4. ГЕНЕРАТОР ТЕСТОВОГО СИГНАЛА (ВХОД DPD)
    -- ========================================================================
    process(aclk)
        variable sin_val, cos_val : real;
        variable i_int, q_int : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                test_phase_acc <= (others => '0');
                test_i_24 <= (others => '0');
                test_q_24 <= (others => '0');
            else
                test_phase_acc <= test_phase_acc + TEST_PHASE_INC;
                
                sin_val := sin(2.0 * MATH_PI * real(to_integer(test_phase_acc)) / 2.0**32);
                cos_val := cos(2.0 * MATH_PI * real(to_integer(test_phase_acc)) / 2.0**32);
                
                i_int := integer(round(sin_val * 8388607.0));
                q_int := integer(round(cos_val * 8388607.0));
                
                test_i_24 <= to_signed(i_int, 24);
                test_q_24 <= to_signed(q_int, 24);
            end if;
        end if;
    end process;
    
    -- Формат: {Q(23:0), I(23:0)}
    s_axis_iq_tdata <= std_logic_vector(test_q_24) & std_logic_vector(test_i_24);
    
    -- ========================================================================
    -- 5. МОДЕЛЬ PA (КОМПЛЕКСНЫЙ УСИЛИТЕЛЬ)
    -- ========================================================================
    process(aclk)
        variable amp : real;
        variable phase_shift : real;
        variable i_f, q_f : real;
        variable i_pa, q_pa : real;
        variable i_out, q_out : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                pa_output_i <= (others => '0');
                pa_output_q <= (others => '0');
                pa_input_i <= (others => '0');
                pa_input_q <= (others => '0');
            else
                pa_input_i <= signed(m_axis_iq_tdata(15 downto 0));
                pa_input_q <= signed(m_axis_iq_tdata(31 downto 16));
                
                i_f := real(to_integer(pa_input_i)) / 32767.0;
                q_f := real(to_integer(pa_input_q)) / 32767.0;
                amp := sqrt(i_f*i_f + q_f*q_f);
                
                if amp < 0.01 then
                    i_pa := i_f;
                    q_pa := q_f;
                else
                    i_pa := i_f * (1.0 - 0.3*amp*amp + 0.1*amp*amp*amp*amp);
                    q_pa := q_f * (1.0 - 0.3*amp*amp + 0.1*amp*amp*amp*amp);
                    
                    phase_shift := 0.1 * amp * amp;
                    i_out := integer(round((i_pa*cos(phase_shift) - q_pa*sin(phase_shift)) * 32767.0));
                    q_out := integer(round((i_pa*sin(phase_shift) + q_pa*cos(phase_shift)) * 32767.0));
                    
                    if i_out > 32767 then i_out := 32767; end if;
                    if i_out < -32768 then i_out := -32768; end if;
                    if q_out > 32767 then q_out := 32767; end if;
                    if q_out < -32768 then q_out := -32768; end if;
                    
                    pa_output_i <= to_signed(i_out, 16);
                    pa_output_q <= to_signed(q_out, 16);
                end if;
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 6. ФОРМИРОВАНИЕ РЕАЛЬНОГО СИГНАЛА ДЛЯ АЦП
    -- ========================================================================
    process(aclk)
        variable i_mult, q_mult : integer;
        variable real_sample : integer;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                pa_output_real <= (others => '0');
            else
                i_mult := (to_integer(pa_output_i) * to_integer(dds_cos)) / 32767;
                q_mult := (to_integer(pa_output_q) * to_integer(dds_sin)) / 32767;
                real_sample := i_mult - q_mult;
                
                if real_sample > 32767 then real_sample := 32767; end if;
                if real_sample < -32768 then real_sample := -32768; end if;
                
                pa_output_real <= to_signed(real_sample, 16);
            end if;
        end if;
    end process;
    
    s_axis_adc_tdata <= std_logic_vector(pa_output_real);
    
    -- ========================================================================
    -- 7. КОНФИГУРАЦИЯ
    -- ========================================================================
    process
    begin
        -- Сброс
        aresetn <= '0';
        wait for 200 ns;
        aresetn <= '1';
        wait for 100 ns;
        
        -- Включаем логирование
        log_enable <= '1';
        
        -- Включение режима обучения
        s_axis_cfg_tdata <= x"00000005";
        s_axis_cfg_tdest <= "00000";
        s_axis_cfg_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_cfg_tvalid <= '0';
        wait for CLK_PERIOD;
        
        s_axis_cfg_tdata <= x"00000000";
        s_axis_cfg_tdest <= "00001";
        s_axis_cfg_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_cfg_tvalid <= '0';
        wait for CLK_PERIOD;
         
        -- Ждем завершения теста
        wait for 1 ms;
        
        -- Выключаем логирование
        log_enable <= '0';
        
        report "Simulation completed successfully" severity note;
        wait;
    end process;
    
    -- ========================================================================
    -- 8. ??? ЗАПИСЬ ДАННЫХ В CSV ФАЙЛ ???
    -- ========================================================================
    process(aclk)
        file log_file : text open write_mode is "simulation_data.csv";
        variable line_out : line;
        variable time_ns : integer;
        variable i_val, q_val : integer;
    begin
        if rising_edge(aclk) then
            if log_enable = '1' and aresetn = '1' then
                -- Счетчик для ограничения количества записей
                log_counter <= log_counter + 1;
                
                -- Записываем каждые 10 тактов (чтобы файл не был слишком большим)
                if log_counter mod 10 = 0 then
                    
                    -- Время в наносекундах (как integer)
                    time_ns := (now / 1 ns);
                    write(line_out, time_ns);
                    write(line_out, string'(";"));
                    
                    -- Входной сигнал DPD (I, Q) - 24 бита
                    i_val := to_integer(signed(s_axis_iq_tdata(23 downto 0)));
                    q_val := to_integer(signed(s_axis_iq_tdata(47 downto 24)));
                    write(line_out, i_val);
                    write(line_out, string'(";"));
                    write(line_out, q_val);
                    write(line_out, string'(";"));
                    
                    -- Выходной сигнал DPD (I, Q) - 16 бит
                    i_val := to_integer(signed(m_axis_iq_tdata(15 downto 0)));
                    q_val := to_integer(signed(m_axis_iq_tdata(31 downto 16)));
                    write(line_out, i_val);
                    write(line_out, string'(";"));
                    write(line_out, q_val);
                    write(line_out, string'(";"));
                    
                    -- Сигнал обратной связи с АЦП
                    i_val := to_integer(signed(s_axis_adc_tdata));
                    write(line_out, i_val);
                    write(line_out, string'(";"));
                    
                    -- Статус переполнения
                    write(line_out, m_ovf(0));
                    write(line_out, string'(";"));
                    write(line_out, m_ovf(1));
                    
                    -- Завершаем строку
                    writeline(log_file, line_out);
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;