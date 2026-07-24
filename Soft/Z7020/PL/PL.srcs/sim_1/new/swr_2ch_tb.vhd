library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- <--- Эта строка обязательна для sin/cos!

entity swr_2ch_tb is
end swr_2ch_tb;

architecture Behavioral of swr_2ch_tb is
    -- Компонент UUT
    component swr_2ch is
        Port (
            aclk, aresetn : in STD_LOGIC;
            s_axis_adc0_tdata, s_axis_adc1_tdata : in STD_LOGIC_VECTOR (15 downto 0);
            s_axis_dds_tdata, cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
            cfg_addra : in STD_LOGIC_VECTOR (1 downto 0);
            cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
            cfg_wr : in STD_LOGIC
        );
    end component;

    -- Сигналы
    signal tb_aclk, tb_aresetn : STD_LOGIC := '0';
    signal tb_s_axis_adc0_tdata, tb_s_axis_adc1_tdata : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal tb_s_axis_dds_tdata, tb_cfg_dina : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal tb_cfg_addra : STD_LOGIC_VECTOR (1 downto 0) := (others => '0');
    signal tb_cfg_douta : STD_LOGIC_VECTOR (31 downto 0);
    signal tb_cfg_wr : STD_LOGIC := '0';

    constant CLK_PERIOD : time := 8.192 ns;
begin

    -- Инстанцирование тестируемого модуля (UUT)
    uut: swr_2ch
        port map (
            aclk              => tb_aclk,
            aresetn           => tb_aresetn,
            s_axis_adc0_tdata => tb_s_axis_adc0_tdata,
            s_axis_adc1_tdata => tb_s_axis_adc1_tdata,
            s_axis_dds_tdata  => tb_s_axis_dds_tdata,
            cfg_addra         => tb_cfg_addra,
            cfg_dina          => tb_cfg_dina,
            cfg_douta         => tb_cfg_douta,
            cfg_wr            => tb_cfg_wr
        );

    -- Процесс генерации тактового сигнала (100 МГц)
    clk_process : process
    begin
        tb_aclk <= '0';
        wait for CLK_PERIOD / 2;
        tb_aclk <= '1';
        wait for CLK_PERIOD / 2;
    end process;
   
       -- Процесс генерации сигналов Напряжения (ADC0) и Тока (ADC1) в фидере
    data_gen_process : process(tb_aclk)
        constant PI          : real := 3.141592653589793;
        constant SIGNAL_FREQ : real := 10000000.0;   -- Частота ВЧ сигнала (10 МГц)
        constant DDS_FREQ   : real := 10003000.0;   -- Частота ВЧ сигнала (10 МГц)
        constant SAMPLING_FREQ: real := 122880000.0; -- Частота дискретизации (122.88 МГц)
        
        variable sample_idx  : integer := 0;
        variable phase       : real := 0.0;
        variable phase_dds    : real := 0.0;
        
        -- Физические параметры фидера и нагрузки для расчета сдвигов:
        -- Пусть амплитуда напряжения в линии составляет 15000 единиц АЦП
        variable amp_u       : real := 32767.0; 
        
        -- Моделируем рассогласованную нагрузку (ток отстает по фазе и изменен по амплитуде)
        -- Для комплексной нагрузки отношение амплитуд U/I и сдвиг фазы:
        variable amp_i       : real := 32767.0; -- Амплитуда тока (зависит от импеданса)
        variable phase_shift : real := -0.38;   -- Сдвиг фазы между U и I в радианах (~22 градуса)
        
        variable amp_dds     : real := 32767.0; -- Опорный сигнал DDS
        
        -- Промежуточные переменные для тригонометрии
        variable sin_u       : real := 0.0;
        variable sin_i       : real := 0.0;
        variable sin_dds     : real := 0.0;
        variable cos_dds     : real := 0.0;
    begin
        if rising_edge(tb_aclk) then
            if tb_aresetn = '0' then
                sample_idx := 0;
                tb_s_axis_adc0_tdata <= (others => '0');
                tb_s_axis_adc1_tdata <= (others => '0');
                tb_s_axis_dds_tdata  <= (others => '0');
            else
                -- 1. Вычисляем текущую фазу опорного сигнала
                phase := 2.0 * PI * SIGNAL_FREQ * real(sample_idx) / SAMPLING_FREQ;
                phase_dds := 2.0 * PI * DDS_FREQ * real(sample_idx) / SAMPLING_FREQ;
                
                -- 2. Математический расчет мгновенных значений
                sin_u   := IEEE.MATH_REAL.sin(phase);
                sin_i   := IEEE.MATH_REAL.sin(phase + phase_shift); -- Ток со сдвигом относительно напряжения
                sin_dds := IEEE.MATH_REAL.sin(phase_dds);
                cos_dds := IEEE.MATH_REAL.cos(phase_dds);
                
                -- 3. Вывод данных в 16-битные порты АЦП (Напряжение и Ток)
                tb_s_axis_adc0_tdata <= std_logic_vector(to_signed(integer(amp_u * sin_u), 16)); -- ADC0 = U
                tb_s_axis_adc1_tdata <= std_logic_vector(to_signed(integer(amp_i * sin_i), 16)); -- ADC1 = I
                
                -- 4. Вывод данных DDS (Квадратурный гетеродин для цифрового смесителя)
                -- Старшие 16 бит - Sine, Младшие 16 бит - Cosine
                tb_s_axis_dds_tdata(31 downto 16) <= std_logic_vector(to_signed(integer(amp_dds * sin_dds), 16));
                tb_s_axis_dds_tdata(15 downto 0)  <= std_logic_vector(to_signed(integer(amp_dds * cos_dds), 16));
                
                -- Инкремент индекса временной точки сбросом по достижении секунды
                if sample_idx >= 122880 then
                    sample_idx := 0;
                else
                    sample_idx := sample_idx + 1;
                end if;
            end if;
        end if;
    end process;



    -- Процесс тестирования управляющих команд и сценариев (Stimulus)
    stimulus_process : process
    begin
        -- Шаг 1: Аппаратный сброс системы
        tb_aresetn <= '0';
        tb_cfg_wr    <= '0';
        tb_cfg_addra <= "00";
        tb_cfg_dina  <= (others => '0');
        wait for 40 ns;
        tb_aresetn <= '1';
        wait for 20 ns;

        -- Шаг 2: Запись коэффициентов усиления CIC (адрес "00")
        -- Записываем: cic_gain_0 = "10" (биты 1-0), cic_gain_1 = "01" (биты 17-16)
        wait until falling_edge(tb_aclk);
        tb_cfg_addra <= "00";
        tb_cfg_dina  <= X"00030003"; 
        tb_cfg_wr    <= '1';
        wait for CLK_PERIOD;
        tb_cfg_wr    <= '0';
        wait for 40 ns;

        -- Шаг 3: Переключение на чтение регистра RSSI (адрес "01")
        wait until falling_edge(tb_aclk);
        tb_cfg_addra <= "01";
        wait for 40 ns;

        -- Шаг 4: Переключение на чтение регистра фазового угла (адрес "10")
        wait until falling_edge(tb_aclk);
        tb_cfg_addra <= "10";
        wait for 40 ns;

        -- Шаг 5: Переключение на чтение регистра SWR (адрес "11")
        wait until falling_edge(tb_aclk);
        tb_cfg_addra <= "11";
        
        -- Остановка симуляции
        wait;
    end process;

end Behavioral;
