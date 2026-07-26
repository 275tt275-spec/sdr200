library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

library STD;
use STD.TEXTIO.ALL;

entity audio_proc_tb is
-- Сущность тестбэнча всегда пустая
end audio_proc_tb;

architecture sim of audio_proc_tb is

    -- Константы тактовых частот и периодов
    constant CLK_FREQ   : real := 122880000.0;
    constant CLK_PERIOD : time := 8.138 ns; -- 1 / 122.88 MHz
    
    -- Константы сэмплрейта (16000 Гц)
    constant SAMPLE_RATE : real := 16000.0;
    -- Интервал между отсчетами: 122880000 / 16000 = 7680 тактов
    constant CLKS_PER_SAMPLE : integer := 100;

    -- Сигналы для подключения к компоненту
    signal tb_aclk               : std_logic := '0';
    signal tb_s_axis_audio_tdata  : std_logic_vector(23 downto 0) := (others => '0');
    signal tb_s_axis_audio_tvalid : std_logic := '0';
    
    signal tb_s_axis_cfg_tdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal tb_s_axis_cfg_tdest   : std_logic_vector(2 downto 0) := (others => '0');
    signal tb_s_axis_cfg_tvalid  : std_logic := '0';
    
    signal tb_m_axis_audio_tdata  : std_logic_vector(23 downto 0);
    signal tb_m_axis_audio_tvalid : std_logic;
    signal tb_lim_over           : std_logic_vector(6 downto 0);

    -- Сигнал завершения симуляции
    signal sim_done : boolean := false;
    
   -- Объявление тестируемого компонента
    component audio_proc is
    Port (
        m_axis_audio_tdata  : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata  : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        s_axis_cfg_tdata    : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest    : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid   : in STD_LOGIC;
        lim_over            : out STD_LOGIC_VECTOR (6 downto 0);
        aclk                : in STD_LOGIC
    );
    end component;

begin

    -- Подключение тестируемого модуля (UUT)
    uut: audio_proc
    Port Map (
        m_axis_audio_tdata  => tb_m_axis_audio_tdata,
        m_axis_audio_tvalid => tb_m_axis_audio_tvalid,
        s_axis_audio_tdata  => tb_s_axis_audio_tdata,
        s_axis_audio_tvalid => tb_s_axis_audio_tvalid,
        s_axis_cfg_tdata    => tb_s_axis_cfg_tdata,
        s_axis_cfg_tdest    => tb_s_axis_cfg_tdest,
        s_axis_cfg_tvalid   => tb_s_axis_cfg_tvalid,
        lim_over            => tb_lim_over,
        aclk                => tb_aclk
    );

    -- Процесс генерации тактовой частоты 122.88 МГц
    p_clk_gen : process
    begin
        while not sim_done loop
            tb_aclk <= '0';
            wait for CLK_PERIOD / 2;
            tb_aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process p_clk_gen;

    -- Процесс инициализации и конфигурации
    p_config : process
    begin
        -- Сброс конфигурационных линий
        tb_s_axis_cfg_tvalid <= '0';
        tb_s_axis_cfg_tdata  <= (others => '0');
        tb_s_axis_cfg_tdest  <= (others => '0');
        wait for CLK_PERIOD * 10;
        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tdest  <= "100";      -- limit_overshoot
        tb_s_axis_cfg_tdata  <= x"00002080";
        tb_s_axis_cfg_tvalid <= '1';        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tvalid <= '0';
        
         wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tdest  <= "001";      -- lim_limit
        tb_s_axis_cfg_tdata  <= x"00000C00";
        tb_s_axis_cfg_tvalid <= '1';        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tvalid <= '0';
        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tdest  <= "000";      -- lim_in_gain
        tb_s_axis_cfg_tdata  <= x"000037FF";
        tb_s_axis_cfg_tvalid <= '1';        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tvalid <= '0';
        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tdest  <= "010";      -- lim_out_gain
        tb_s_axis_cfg_tdata  <= x"00002000";
        tb_s_axis_cfg_tvalid <= '1';        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tvalid <= '0';
        
        -- Подача команды включения лимитера (dest = "110", data = 1)
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tdest  <= "110";
        tb_s_axis_cfg_tdata  <= x"00000001";
        tb_s_axis_cfg_tvalid <= '1';        
        wait until rising_edge(tb_aclk);
        tb_s_axis_cfg_tvalid <= '0';            
        
        tb_s_axis_cfg_tdata  <= (others => '0');
        tb_s_axis_cfg_tdest  <= (others => '0');
        wait;
    end process p_config;
    
       -- ОПТИМИЗИРОВАННЫЙ ПРОЦЕСС ЧТЕНИЯ (3 байта на сэмпл - 24-bit Signed)
    p_file_reader : process
        type byte_file is file of character;
        file infile     : byte_file;
        variable char_b : character;
        variable s_word : std_logic_vector(23 downto 0);
    begin
        -- Укажите имя вашего нового 24-битного файла
        file_open(infile, "D:\\Projects\\sdr200\\Soft\\audio_proc.raw", READ_MODE);
        
        tb_s_axis_audio_tvalid <= '0';
        tb_s_axis_audio_tdata  <= (others => '0');
        
        -- Быстрый пропуск стартовой конфигурации (50 тактов клока)
        for i in 1 to 50 loop
            wait until rising_edge(tb_aclk);
        end loop;

        while not endfile(infile) loop
            -- Побайтовое чтение 24-битного слова (3 байта, Little Endian)
            for i in 0 to 2 loop
                if not endfile(infile) then
                    read(infile, char_b);
                    s_word((i*8)+7 downto (i*8)) := std_logic_vector(to_unsigned(character'pos(char_b), 8));
                end if;
            end loop;

            -- Выставляем данные напрямую в FIR-фильтры без конвертации
            wait until rising_edge(tb_aclk);
            tb_s_axis_audio_tdata  <= s_word;
            tb_s_axis_audio_tvalid <= '1';

            -- Снимаем valid на следующем такте
            wait until rising_edge(tb_aclk);
            tb_s_axis_audio_tvalid <= '0';
  --          tb_s_axis_audio_tdata  <= (others => '0');

            -- Жесткое сохранение интервала для корректной работы FIR (7680 тактов)
            for sample_cnt in 1 to (CLKS_PER_SAMPLE - 1) loop
                wait until rising_edge(tb_aclk);
            end loop;
        end loop;

        file_close(infile);
        wait for CLK_PERIOD * 100;
        sim_done <= true;
        wait;
    end process p_file_reader;


    -- ОПТИМИЗИРОВАННЫЙ ПРОЦЕСС ЗАПИСИ (Сохраняет строго в 24-bit Signed)
    p_file_writer : process
        type byte_file is file of character;
        file outfile    : byte_file;
        file out_lim_file : byte_file; -- Новый файловый дескриптор для флагов
        variable s_word : std_logic_vector(23 downto 0);
        variable lim_word : std_logic_vector(7 downto 0); -- 8-битная переменная 
        variable char_b : character;
    begin
        -- Выходной файл тоже будет весить ровно по 3 байта на сэмпл
        file_open(outfile, "D:\\Projects\\sdr200\\Soft\\output_audio24.raw", WRITE_MODE);
        file_open(out_lim_file, "D:\\Projects\\sdr200\\Soft\\output_lim_over_8bit.bin", WRITE_MODE);

        while not sim_done loop
            wait until rising_edge(tb_aclk);
            
            -- Ловим валидный отсчет от лимитера
            if tb_m_axis_audio_tvalid = '1' then
                s_word := tb_m_axis_audio_tdata;
                
                -- Побайтовая запись 24-битного слова (3 байта, Little Endian)
                for i in 0 to 2 loop
                    char_b := character'val(to_integer(unsigned(s_word((i*8)+7 downto (i*8)))));
                    write(outfile, char_b);
                end loop;
                
                -- 2. Запись флага лимитера tb_lim_over
                -- Дополняем 6-битный сигнал четырьмя старшими нулями до 1 байта (8 бит)
                lim_word := "0" & tb_lim_over;
                -- Преобразуем полученный байт в символ и пишем на диск (1 байт на сэмпл)
                char_b := character'val(to_integer(unsigned(lim_word)));
                write(out_lim_file, char_b);
                
            end if;
        end loop;

        file_close(outfile);
        wait;
    end process p_file_writer;


end sim;


