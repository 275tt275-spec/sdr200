library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_audio_input16 is
-- У тестбенча нет портов
end tb_audio_input16;

architecture Behavioral of tb_audio_input16 is

    -- Прецизионные временные константы (122.88 MHz)
    constant CLK_PERIOD      : time := 8138 ps; 
    constant AUDIO_DIVIDER   : integer := 7680; -- 122.88 MHz / 16 kHz

    -- Входные сигналы для тестируемого модуля (UUT)
    signal aclk              : std_logic := '0';
    signal s_axis_tdata      : std_logic_vector(23 downto 0) := (others => '0');
    signal s_axis_tvalid     : std_logic := '0';
    signal s_axis_cfg_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : std_logic_vector(0 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid : std_logic := '0';

    -- Выходные сигналы из тестируемого модуля (UUT)
    signal m_axis_tdata      : std_logic_vector(15 downto 0);
    signal m_axis_tvalid     : std_logic;
    signal overflow          : std_logic;

    -- Внутренний таймер для строба аудио частоты
    signal audio_clk_cnt     : integer range 0 to AUDIO_DIVIDER := 0;
    signal audio_strobe      : std_logic := '0';

    -- Таблица 24-битного знакового синуса 1 кГц на 16 точек (для Fs = 16 кГц)
    type sine_table_t is array (0 to 15) of std_logic_vector(23 downto 0);
    constant SINE_24BIT : sine_table_t := (
        0  => x"000000", -- sin(0)
        1  => x"30FB24", -- sin(pi/8)
        2  => x"5A8279", -- sin(pi/4)
        3  => x"7641AF", -- sin(3pi/8)
        4  => x"7FFFFF", -- sin(pi/2) -> Пиковый положительный максимум (+FS)
        5  => x"7641AF",
        6  => x"5A8279",
        7  => x"30FB24",
        8  => x"000000",
        9  => x"CF04DC",
        10 => x"A57D87",
        11 => x"89BE51",
        12 => x"800000", -- sin(3pi/2) -> Пиковый отрицательный минимум (-FS)
        13 => x"89BE51",
        14 => x"A57D87",
        15 => x"CF04DC"
    );

begin

    -- Инстанцирование тестируемого модуля (Unit Under Test)
    uut: entity work.audio_input16
        port map (
            aclk              => aclk,
            s_axis_tdata      => s_axis_tdata,
            s_axis_tvalid     => s_axis_tvalid,
            m_axis_tdata      => m_axis_tdata,
            m_axis_tvalid     => m_axis_tvalid,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            overflow          => overflow
        );

    -- Генератор опорной тактовой частоты 122.88 МГц
    clk_gen_proc : process
    begin
        aclk <= '0'; wait for CLK_PERIOD / 2;
        aclk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Делитель частоты, формирующий строб 16 кГц ровно на 1 такт aclk
    audio_rate_proc : process(aclk)
    begin
        if rising_edge(aclk) then
            if audio_clk_cnt = AUDIO_DIVIDER - 1 then
                audio_clk_cnt <= 0;
                audio_strobe  <= '1';
            else
                audio_clk_cnt <= audio_clk_cnt + 1;
                audio_strobe  <= '0';
            end if;
        end if;
    end process;

    -- Основной процесс подачи воздействий (Stimulus Process)
    stim_proc : process
    begin
        -- Шаг 1: Начальная инициализация шин тракта
        s_axis_tdata      <= (others => '0');
        s_axis_tvalid     <= '0';
        s_axis_cfg_tdata  <= (others => '0');
        s_axis_cfg_tdest  <= (others => '0');
        s_axis_cfg_tvalid <= '0';
        wait for 200 ns;

        -- Записываем базовую конфигурацию: gain_correct := "0001" (сдвиг влево на 1)
        wait until falling_edge(aclk);
        s_axis_cfg_tdest  <= "1"; -- Конфигурационный адрес для gain
        s_axis_cfg_tdata  <= x"00000006"; 
        s_axis_cfg_tvalid <= '1';
        wait until falling_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        s_axis_cfg_tdata  <= (others => '0');
        wait for 100 ns;

        -- Шаг 2: Подача 20 периодов синуса в нормальном (линейном) режиме
        for period in 0 to 19 loop
            for sample in 0 to 15 loop
                
                -- Ждем момента, когда делитель сформирует строб 16 кГц
                wait until rising_edge(aclk) and audio_strobe = '1';
                
                -- Выставляем данные на спаде такта для предотвращения Race Condition
                s_axis_tdata  <= SINE_24BIT(sample);
                s_axis_tvalid <= '1';
                
                -- Гасим валид строго на следующем фронте такта (длительность строба = 1 такт aclk)
                wait until rising_edge(aclk);
                s_axis_tvalid <= '0';
                
            end loop;
        end loop;

        -- Шаг 3: Динамическое изменение усиления для проверки перегрузки (Стресс-тест)
        -- Изменяем конфигурацию «на лету» на максимальный сдвиг (gain_correct := "0100", сдвиг на 4 бита)
        wait for 10 us;
        wait until falling_edge(aclk);
        s_axis_cfg_tdest  <= "1";
        s_axis_cfg_tdata  <= x"00000007"; -- Вызовет жесткое насыщение звуковой волны в proc_dsp
        s_axis_cfg_tvalid <= '1';
        wait until falling_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        wait for 100 ns;

        -- Подаем еще 10 периодов синусоиды для наблюдения за ограничением амплитуды
        for period in 0 to 9 loop
            for sample in 0 to 15 loop
                wait until rising_edge(aclk) and audio_strobe = '1';
                s_axis_tdata  <= SINE_24BIT(sample);
                s_axis_tvalid <= '1';
                wait until rising_edge(aclk);
                s_axis_tvalid <= '0';
            end loop;
        end loop;

        -- Завершение симуляции
        wait for 50 us;
        assert false report "Simulation completed successfully!" severity failure;
        wait;
    end process;

end Behavioral;
