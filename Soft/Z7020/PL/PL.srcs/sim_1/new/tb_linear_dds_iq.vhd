library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_linear_dds_iq is
end tb_linear_dds_iq;

architecture Behavioral of tb_linear_dds_iq is
    -- Сигналы входов (с инициализацией 0)
    signal din1_i, din1_q : STD_LOGIC_VECTOR (23 downto 0) := (others => '0');
    signal din2 : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal aclk : STD_LOGIC := '0';
    signal ce : STD_LOGIC := '1';
    signal s_axis_cfg_tdata  : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : STD_LOGIC_VECTOR (4 downto 0) := (others => '0');
    signal s_axis_cfg_tvalid : STD_LOGIC := '0';
    signal s_axis_dds_tdata : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');

    -- Сигналы выходов
    signal dout_i, dout_q : STD_LOGIC_VECTOR (15 downto 0);
    signal m_ovf : STD_LOGIC_VECTOR (3 downto 0);

    -- Период тактового сигнала (122.88 МГц)
    constant CLK_PERIOD : time := 8.138 ns;
    
begin

    -- Порт-маппинг тестируемого модуля (UUT)
    uut: entity work.linear_dds_iq
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
        cfg_dout          => open,
        m_ovf             => m_ovf
    );
    

 -- Генератор тактового сигнала 122.88 МГц (период 8.138 нс)
clk_process : process
    begin
        aclk <= '0';
        wait for 4.069 ns;
        aclk <= '1';
        wait for 4.069 ns;
    end process;
    
    -- Процесс симуляции: генерация идеального сигнала TX и искаженного АЦП (RX)
    stimulus_process : process
    
    -- Объявляем процедуру-функцию прямо внутри процесса
        procedure write_reg(
            constant addr : in string;
            constant data : in integer
        ) is
        begin
            wait until rising_edge(aclk);
            -- Мапим строковый или числовой адрес в 5-битную шину tdest
            if    addr = "agc_k_out"  then s_axis_cfg_tdest <= "00000"; -- 0x00
            elsif addr = "adc_shift"  then s_axis_cfg_tdest <= "00001"; -- 0x01
            elsif addr = "agc_k"      then s_axis_cfg_tdest <= "00010"; -- 0x02
            elsif addr = "gain_i"     then s_axis_cfg_tdest <= "00011"; -- 0x03
            elsif addr = "gain_q"     then s_axis_cfg_tdest <= "00100"; -- 0x04
            elsif addr = "prop"       then s_axis_cfg_tdest <= "00110"; -- 0x06
            elsif addr = "i_corr"     then s_axis_cfg_tdest <= "00111"; -- 0x07
            elsif addr = "q_corr"     then s_axis_cfg_tdest <= "01000"; -- 0x08
            elsif addr = "dc_i"       then s_axis_cfg_tdest <= "01001"; -- 0x09
            elsif addr = "dc_q"       then s_axis_cfg_tdest <= "01010"; -- 0x0A
            elsif addr = "phi_sin"    then s_axis_cfg_tdest <= "01011"; -- 0x0B
            elsif addr = "phi_cos"    then s_axis_cfg_tdest <= "01100"; -- 0x0C
            elsif addr = "diff"       then s_axis_cfg_tdest <= "01101"; -- 0x0D
            elsif addr = "stab"       then s_axis_cfg_tdest <= "01110"; -- 0x0E
            elsif addr = "ctrl"       then s_axis_cfg_tdest <= "01111"; -- 0x0F
            else                           s_axis_cfg_tdest <= "00000";
            end if;
            
            -- Конвертируем integer данные в 32-битный вектор AXI-Stream
            s_axis_cfg_tdata  <= conv_std_logic_vector(data, 32);
            s_axis_cfg_tvalid <= '1';            
            -- 2. Ждем ровно один следующий фронт aclk, чтобы приемник защелкнул данные
            wait until rising_edge(aclk);            
            -- 3. Гасим строб валидности и очищаем шину (Конец импульса записи)
            s_axis_cfg_tvalid <= '0';            
            wait for CLK_PERIOD; -- Удерживаем сигналы ровно 1 такт
        end procedure;
        
        -- Переменные для расчета математических искажений тракта
        variable rad_dds, rad_sig : real;
        variable i_ideal, q_ideal : real;
        variable i_out_real, q_out_real : real := 0.0;
        variable cos_adc_real, sin_adc_real : real := 0.0;
        variable rf_modulated : real := 0.0;
        variable rf_distorted : real := 0.0;
        variable amp_squared  : real := 0.0;
        
        -- Конвейер для эмуляции задержки прохождения тракта (например, 12 тактов aclk)
        type delay_pipe_type is array (0 to 11) of integer;
        variable delay_pipe : delay_pipe_type := (others => 0);
    begin
         -- Инициализация шины
        s_axis_cfg_tvalid <= '0';
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdest  <= (others => '0');
        wait for CLK_PERIOD * 10;

        ------------------------------------------------------------
        -- ВЫЗОВ ФУНКЦИЙ НАСТРОЙКИ (Аналог вашего Си-кода)
        ------------------------------------------------------------
        write_reg("ctrl",      3);     -- Включаем lin_clr=1 и lin_on=1
        write_reg("adc_shift", 0);     -- linear.adc_shift = 0;
        write_reg("agc_k",     5);     -- linear.agc_k = 5;
        write_reg("gain_i",    32767); -- linear.gain_i = 32767;
        write_reg("gain_q",    32767); -- linear.gain_q = 32767;
        write_reg("prop",      2000);  -- linear.prop = 2000;
        write_reg("i_corr",    8037);  -- Рассчитанное значение i_corr
        write_reg("q_corr",    1032);  -- Рассчитанное значение q_corr
        write_reg("dc_i",      0);     -- linear.dc_i = 0;
        write_reg("dc_q",      0);     -- linear.dc_q = 0;
        write_reg("phi_sin",   0);     -- linear.phi_sin = 0;
        write_reg("phi_cos",   32767); -- linear.phi_cos = 32767;
        write_reg("diff",      0);     -- linear.diff = 0;
        write_reg("stab",      200);   -- linear.stab = 200;
        write_reg("ctrl",      6);     -- Отпускаем сброс lin_clr=0, оставляем lin_on=1, agc on
        ------------------------------------------------------------

        -- Завершаем конфигурацию, очищаем шину
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdest  <= (others => '0');
        wait for CLK_PERIOD * 5;


        -- Основной цикл генерации тестовой гармоники (например, ПЧ = 5 МГц)
        for t in 0 to 1000000 loop
            -- 1. Генерируем идеальный цифровой сигнал I/Q для передатчика
            rad_dds := 2.0 * 3.14159265 * 5000000.0 * (real(t) / 122880000.0);
            rad_sig := 2.0 * 3.14159265 * 5000.0 * (real(t) / 122880000.0);
            i_ideal := cos(rad_sig) / 1.0;
            q_ideal := sin(rad_sig) / 1.0;

            -- Переводим в 24-битный формат со знаком (signed) для входа корректора
            din1_i <= conv_std_logic_vector(integer(i_ideal * 8388607.0), 24);
            din1_q <= conv_std_logic_vector(integer(q_ideal * 8388607.0), 24);

            -- Также эмулируем опорный DDS для АЦП (32-битный порт AXI-Stream)
            s_axis_dds_tdata(15 downto 0)  <= conv_std_logic_vector(integer(cos(rad_dds) * 32767.0), 16);
            s_axis_dds_tdata(31 downto 16) <= conv_std_logic_vector(integer(sin(rad_dds) * 32767.0), 16);

            -- 1. Преобразуем выходные 24-битные шины передатчика в вещественные числа (-1.0 ... +1.0)
            i_out_real := real(conv_integer(signed(dout_i))) / 32768.0;
            q_out_real := real(conv_integer(signed(dout_q))) / 32768.0;

            -- 2. Считываем текущую фазу опорного DDS приемника (-1.0 ... +1.0)
            cos_adc_real := real(conv_integer(signed(s_axis_dds_tdata(15 downto 0)))) / 32768.0;
            sin_adc_real := real(conv_integer(signed(s_axis_dds_tdata(31 downto 16)))) / 32768.0;

            -- 3. Моделируем ВЧ-смеситель (IQ-модуляция на промежуточную частоту)
            -- Формула: RF = I * cos(w*t) - Q * sin(w*t)
            rf_modulated := (i_out_real * cos_adc_real) - (q_out_real * sin_adc_real);

            -- 4. Моделируем нелинейность усилителя мощности (AM/AM компрессия 3-го порядка)
            -- Ограничивает пики сигнала, создавая интермодуляционные искажения (IMD3)
            amp_squared  := rf_modulated * rf_modulated;
            rf_distorted := rf_modulated * (1.0 - 0.18 * amp_squared); -- 0.18 - коэффициент компрессии

            -- 5. Моделируем конвейерную задержку аналогового фильтра и кабелей (сдвиг в массиве)
            for k in 11 downto 1 loop
                delay_pipe(k) := delay_pipe(k-1);
            end loop;
            
            -- Переводим искаженный ВЧ-сигнал обратно в 16-битный формат АЦП со знаком
            delay_pipe(0) := integer(rf_distorted * 32767.0);

            -- Ограничиваем аппаратно, если сигнал вылетел за пределы сетки АЦП
            if delay_pipe(11) > 32767 then
                din2 <= x"7FFF";
            elsif delay_pipe(11) < -32768 then
                din2 <= x"8000";
            else
                -- Подаем задержанный на 12 тактов сигнал на физический вход АЦП (din2)
                din2 <= conv_std_logic_vector(delay_pipe(11), 16);
            end if;

            wait for CLK_PERIOD;
        end loop;

        wait;
    end process;
    
    

end Behavioral;
