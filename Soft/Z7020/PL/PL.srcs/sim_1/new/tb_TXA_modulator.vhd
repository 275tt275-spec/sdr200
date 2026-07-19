library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_TXA_modulator is
-- У тестбенча нет портов
end tb_TXA_modulator;

architecture Behavioral of tb_TXA_modulator is

    -- Константы тактования и частот
    constant CLK_PERIOD      : time := 8.138 ns; -- 122.88 MHz
    constant AUDIO_DIVIDER  : integer := 7680;   -- 122.88 MHz / 16 kHz

    -- Входные сигналы для UUT
    signal aclk                : std_logic := '0';
    signal tx_on               : std_logic := '0';
    signal s_axis_audio_tdata  : std_logic_vector(23 downto 0) := (others => '0');
    signal s_axis_audio_tvalid : std_logic := '0';
    signal s_axis_cfg_tdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest    : std_logic_vector(3 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid   : std_logic := '0';

    -- Выходные сигналы из UUT
    signal m_axis_iq_tdata     : std_logic_vector(47 downto 0);
    signal m_axis_iq_tvalid    : std_logic;
    signal audio_max_abs       : std_logic_vector(24 downto 0);

    -- Внутренний счетчик для генерации аудио семплрейта 16 кГц
    signal audio_clk_cnt       : integer range 0 to AUDIO_DIVIDER := 0;
    signal audio_strobe        : std_logic := '0';

begin

    -- Инстанцирование тестируемого модуля (UUT)
    uut: entity work.TXA_modulator
        port map (
            aclk                => aclk,
            tx_on               => tx_on,
            s_axis_audio_tdata  => s_axis_audio_tdata,
            s_axis_audio_tvalid => s_axis_audio_tvalid,
            s_axis_cfg_tdata    => s_axis_cfg_tdata,
            s_axis_cfg_tdest    => s_axis_cfg_tdest,
            s_axis_cfg_tvalid   => s_axis_cfg_tvalid,
            m_axis_iq_tdata     => m_axis_iq_tdata,
            m_axis_iq_tvalid    => m_axis_iq_tvalid,
            audio_max_abs       => audio_max_abs
        );

    -- Основной тактовый генератор (122.88 МГц)
    clk_gen_proc : process
    begin
        aclk <= '0'; wait for CLK_PERIOD / 2;
        aclk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Делитель частоты: формирует строб 16 кГц (1 раз в 7680 тактов)
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

   -- Основной процесс симуляции
    stim_proc : process
        -- Таблица синуса 1 кГц на 16 точек
        type sine_table_t is array (0 to 15) of std_logic_vector(23 downto 0);
        constant SINE_1KHZ : sine_table_t := (
            0  => x"000000", 1  => x"187DE2", 2  => x"2D413C", 3  => x"3B20D7",
            4  => x"3FFFFF", 5  => x"3B20D7", 6  => x"2D413C", 7  => x"187DE2",
            8  => x"000000", 9  => x"E7821E", 10 => x"D2BED4", 11 => x"C4DF29",
            12 => x"C00001", 13 => x"C4DF29", 14 => x"D2BED4", 15 => x"E7821E"
        );
    begin
        -- 1. Инициализация и настройка (A3E/AM + Gain)
        tx_on <= '0';
        s_axis_audio_tvalid <= '0';
        s_axis_cfg_tvalid <= '0';
        wait for 100 ns;

        -- Настройка режима A3E (AM) через шину конфигурации
        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= x"0"; s_axis_cfg_tdata  <= x"00000001";
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        
        -- Настройка усиления (Gain)
        wait until rising_edge(aclk);
        s_axis_cfg_tdest  <= x"2"; s_axis_cfg_tdata  <= x"00003FFF";
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';
        wait for 100 ns;

        -- 2. Включение передачи и генерация тона 1 кГц (Честные одиночные импульсы tvalid)
        tx_on <= '1';
        for i in 0 to 32 loop          -- Количество периодов синуса
            for j in 0 to 15 loop      -- 16 отсчетов внутри одного периода
                
                -- Ждем момента, когда внутренний делитель выдаст строб 16 кГц
                wait until rising_edge(aclk) and audio_strobe = '1';
                
                -- Выставляем данные и взводим VALID ровно на ОДИН такт aclk
                s_axis_audio_tdata  <= SINE_1KHZ(j);
                s_axis_audio_tvalid <= '1';
                
                wait until rising_edge(aclk);
                -- На следующем такте гарантированно гасим VALID
                s_axis_audio_tvalid <= '0';
                
            end loop;
        end loop;

        -- 3. Смена режима на J3E (SSB) "на лету" после завершения аудио-пачки
        wait until rising_edge(aclk);
        s_axis_cfg_tdest <= x"0"; s_axis_cfg_tdata <= x"00000000";
        s_axis_cfg_tvalid <= '1';
        wait until rising_edge(aclk);
        s_axis_cfg_tvalid <= '0';

        wait for 500 us;
        tx_on <= '0';
        wait;
    end process;


    
end Behavioral;
