library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use std.textio.all;

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
    signal ovr                 : STD_LOGIC_VECTOR (2 downto 0);

    -- Внутренний счетчик для генерации аудио семплрейта 16 кГц
    signal audio_clk_cnt       : integer range 0 to AUDIO_DIVIDER := 0;
    signal audio_strobe        : std_logic := '0';
    
procedure write_cfg (
    constant addr : in std_logic_vector(3 downto 0);
    constant data : in std_logic_vector(31 downto 0);
    signal clk    : in std_logic;
    signal c_addr : out std_logic_vector(3 downto 0);
    signal c_data : out std_logic_vector(31 downto 0);
    signal c_wr   : out std_logic
) is
begin
    wait until rising_edge(clk);
    c_addr <= addr;
    c_data <= data;
    c_wr   <= '1';
    wait until rising_edge(clk);
    c_wr   <= '0';
    wait for CLK_PERIOD; -- небольшая пауза между записями
end procedure;

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
            ovr                 => ovr
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
        file coe_file_ssb       : text open read_mode is "E:/Projects/sdr200/Soft/Z7020/PL/PL.srcs/sim_1/new/fos_ssb.coe";
        file coe_file_am       : text open read_mode is "E:/Projects/sdr200/Soft/Z7020/PL/PL.srcs/sim_1/new/fos_am.coe";
        file coe_file_dig       : text open read_mode is "E:/Projects/sdr200/Soft/Z7020/PL/PL.srcs/sim_1/new/fos_digital.coe";
        variable file_line  : line;
        variable char       : character;
        variable hex_val    : std_logic_vector(17 downto 0); 
        -- Промежуточный вектор под 5 hex-значений из файла (5 * 4 = 20 бит)
        variable raw_20bit  : std_logic_vector(19 downto 0); 
        variable success    : boolean;
        variable i          : integer := 0;
        variable cfg_data_word : std_logic_vector(31 downto 0);
        -- Таблица синуса 1 кГц на 16 точек
        type sine_table_t is array (0 to 15) of std_logic_vector(23 downto 0);
        constant SINE_1KHZ : sine_table_t := (
            0  => x"000000", -- sin(0) = 0
            1  => x"30FA24", -- sin(pi/8)
            2  => x"5A8279", -- sin(pi/4)
            3  => x"7641AF", -- sin(3pi/8)
            4  => x"7FFFFF", -- sin(pi/2)  -> Максимум (+FS)
            5  => x"7641AF", -- sin(5pi/8)
            6  => x"5A8279", -- sin(3pi/4)
            7  => x"30FA24", -- sin(7pi/8)
            8  => x"000000", -- sin(pi)
            9  => x"CF05DC", -- sin(9pi/8)
            10 => x"A57D87", -- sin(5pi/4)
            11 => x"89BE51", -- sin(11pi/8)
            12 => x"800000", -- sin(3pi/2) -> Минимум (-FS)
            13 => x"89BE51", -- sin(13pi/8)
            14 => x"A57D87", -- sin(7pi/4)
            15 => x"CF05DC"  -- sin(15pi/8)
        );
    begin
        -- 1. Инициализация и настройка (A3E/AM + Gain)
        tx_on <= '0';
        s_axis_audio_tvalid <= '0';
        s_axis_cfg_tvalid <= '0';
        wait for 100 ns;

        -- Настройка режима A3E (AM) через шину конфигурации
        write_cfg(x"0", x"00000000", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);        
        write_cfg(x"4", x"00001799", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- 1475 Hz  
        -- Настройка усиления (Gain)
        write_cfg(x"2", x"00007FFF", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- 32767
        write_cfg(x"9", x"00000007", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- FOS gain
          
        -- Пропускаем первые 6 строк заголовка .coe файла
        for k in 1 to 6 loop
            if not endfile(coe_file_ssb) then
                readline(coe_file_ssb, file_line);
            end if;
        end loop;
        
        -- Цикл чтения 128 коэффициентов фильтра из файла
        i := 0;
        while not endfile(coe_file_ssb) and i < 64 loop
            readline(coe_file_ssb, file_line);
            
            -- Читаем шестнадцатеричное значение из строки
            hread(file_line, raw_20bit, success);
            
            if success then
                hex_val := raw_20bit(17 downto 0);
                -- Формируем 32-битное слово для отправки
                -- Если это самый первый коэффициент (i = 0), выставляем 31-й бит в '1' для инициализации счетчика в фос
                if i = 0 then
                    cfg_data_word := x"80" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит (31-й) равен '1'
                else
                    cfg_data_word := x"00" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит равен '0'
                end if;
                
                -- Отправляем коэффициент на шину конфигурации fos
                write_cfg(x"8", cfg_data_word, aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);

                i := i + 1;
            end if;
        end loop;
        
        wait for 100 ns;

        -- 2. Включение передачи и генерация тона 1 кГц (Честные одиночные импульсы tvalid)
        tx_on <= '1';
        for i in 0 to 10 loop          -- Количество периодов синуса
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
        
        -- Настройка режима A3E (AM) через шину конфигурации
        write_cfg(x"0", x"00000000", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);     
        write_cfg(x"4", x"0000219A", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- 2100 Hz  
        -- Настройка усиления (Gain)
        write_cfg(x"2", x"00007FFF", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- 32767
        write_cfg(x"9", x"00000007", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- FOS gain
          
        -- Пропускаем первые 6 строк заголовка .coe файла
        for k in 1 to 10 loop
            if not endfile(coe_file_dig) then
                readline(coe_file_dig, file_line);
            end if;
        end loop;
        
        -- Цикл чтения 128 коэффициентов фильтра из файла
        i := 0;
        while not endfile(coe_file_dig) and i < 64 loop
            readline(coe_file_dig, file_line);
            
            -- Читаем шестнадцатеричное значение из строки
            hread(file_line, raw_20bit, success);
            
            if success then
                hex_val := raw_20bit(17 downto 0);
                -- Формируем 32-битное слово для отправки
                -- Если это самый первый коэффициент (i = 0), выставляем 31-й бит в '1' для инициализации счетчика в фос
                if i = 0 then
                    cfg_data_word := x"80" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит (31-й) равен '1'
                else
                    cfg_data_word := x"00" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит равен '0'
                end if;
                
                -- Отправляем коэффициент на шину конфигурации fos
                write_cfg(x"8", cfg_data_word, aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);

                i := i + 1;
            end if;
        end loop;
        
        wait for 100 ns;

        -- 2. Включение передачи и генерация тона 1 кГц (Честные одиночные импульсы tvalid)
        tx_on <= '1';
        for i in 0 to 10 loop          -- Количество периодов синуса
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

        -- 3. Смена режима на A3E (AM) "на лету" после завершения аудио-пачки
        write_cfg(x"0", x"00000001", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);        
        -- Настройка усиления (Gain)
        write_cfg(x"2", x"00003FFF", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- 16383
        write_cfg(x"9", x"00000007", aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid); -- FOS gain

        -- Пропускаем первые 6 строк заголовка .coe файла
        for k in 1 to 6 loop
            if not endfile(coe_file_am) then
                readline(coe_file_am, file_line);
            end if;
        end loop;
        
        -- Цикл чтения 128 коэффициентов фильтра из файла
        i := 0;
        while not endfile(coe_file_am) and i < 64 loop
            readline(coe_file_am, file_line);
            
            -- Читаем шестнадцатеричное значение из строки
            hread(file_line, raw_20bit, success);
            
            if success then
                hex_val := raw_20bit(17 downto 0);
                -- Формируем 32-битное слово для отправки
                -- Если это самый первый коэффициент (i = 0), выставляем 31-й бит в '1' для инициализации счетчика в фос
                if i = 0 then
                    cfg_data_word := x"80" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит (31-й) равен '1'
                else
                    cfg_data_word := x"00" & std_logic_vector(resize(unsigned(hex_val), 24)); -- Старший бит равен '0'
                end if;
                
                -- Отправляем коэффициент на шину конфигурации fos
                write_cfg(x"8", cfg_data_word, aclk, s_axis_cfg_tdest, s_axis_cfg_tdata, s_axis_cfg_tvalid);

                i := i + 1;
            end if;
        end loop;
        
        wait for 100 ns;
        
        for i in 0 to 12 loop          -- Количество периодов синуса
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

        wait for 2000 us;
        tx_on <= '0';
        wait;
    end process;


    
end Behavioral;
