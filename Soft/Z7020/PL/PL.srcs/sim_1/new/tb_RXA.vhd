library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use std.textio.all;

entity tb_RXA is
end tb_RXA;

architecture Behavioral of tb_RXA is
    constant CLK_PERIOD  : time := 8.138 ns;
    constant SIGNAL_FREQ : real := 10000000.0;
    constant SAMPLE_RATE : real := 122880000.0;
	
	signal aclk, aresetn      : STD_LOGIC := '0';
    signal s_axis_adc0_tdata  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal s_axis_adc0_tvalid : STD_LOGIC := '0';
    signal s_axis_adc1_tdata  : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal s_axis_adc1_tvalid : STD_LOGIC := '0';
    signal m_axis_wb_tdata    : STD_LOGIC_VECTOR(31 downto 0);
    signal m_axis_wb_tvalid   : STD_LOGIC;
    signal m_axis_wb_tlast    : STD_LOGIC;
    signal m_axis_wb_tready   : STD_LOGIC := '1';
	
	    -- Сигналы для широкополосных и узкополосных каналов, демодулятора и конфигурации
	signal m_axis_nb0_tdata    : STD_LOGIC_VECTOR(31 downto 0);
    signal m_axis_nb0_tvalid   : STD_LOGIC;
    signal m_axis_nb0_tuser    : STD_LOGIC_VECTOR(0 downto 0);
	signal m_axis_nb1_tdata    : STD_LOGIC_VECTOR(31 downto 0);
    signal m_axis_nb1_tvalid   : STD_LOGIC;
    signal m_axis_nb1_tuser    : STD_LOGIC_VECTOR(0 downto 0);
	signal m_axis_demod_tdata  : STD_LOGIC_VECTOR(23 downto 0);
    signal m_axis_demod_tvalid : STD_LOGIC;
    signal cfg_addra           : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal cfg_dina            : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal cfg_douta           : STD_LOGIC_VECTOR(31 downto 0);
    signal cfg_wr              : STD_LOGIC := '0';
    signal out_clk             : STD_LOGIC;
    
procedure write_cfg (
    constant addr : in std_logic_vector(7 downto 0);
    constant data : in std_logic_vector(31 downto 0);
    signal clk    : in std_logic;
    signal c_addr : out std_logic_vector(7 downto 0);
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

-- Подключение экземпляра RXA
    UUT: entity work.RXA
        port map (
            aclk                => aclk,
            aresetn             => aresetn,
            s_axis_adc0_tdata   => s_axis_adc0_tdata,
            s_axis_adc0_tvalid  => s_axis_adc0_tvalid,
            s_axis_adc1_tdata   => s_axis_adc1_tdata,
            s_axis_adc1_tvalid  => s_axis_adc1_tvalid,
            m_axis_wb_tdata     => m_axis_wb_tdata,
            m_axis_wb_tvalid    => m_axis_wb_tvalid,
            m_axis_wb_tlast     => m_axis_wb_tlast,
            m_axis_wb_tready    => m_axis_wb_tready,
			m_axis_nb0_tdata    => m_axis_nb0_tdata,
            m_axis_nb0_tvalid   => m_axis_nb0_tvalid,
            m_axis_nb0_tuser    => m_axis_nb0_tuser,
            m_axis_nb1_tdata    => m_axis_nb1_tdata,
            m_axis_nb1_tvalid   => m_axis_nb1_tvalid,
            m_axis_nb1_tuser    => m_axis_nb1_tuser,
            m_axis_demod_tdata  => m_axis_demod_tdata,
            m_axis_demod_tvalid => m_axis_demod_tvalid,
            cfg_addra           => cfg_addra,
            cfg_dina            => cfg_dina,
            cfg_douta           => cfg_douta,
            cfg_wr              => cfg_wr,
            out_clk             => out_clk
        );
		
		-- Генерация тактовой частоты 122.88 МГц
    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD / 2;
        aclk <= '1';
        wait for CLK_PERIOD / 2;
    end process clk_process;

    adc_signal_process : process(aclk)
        variable sample_idx : integer := 0;
        variable angle      : real;
        variable sin_real   : real;
        variable sin_int    : integer;
    begin
        if rising_edge(aclk) then
            -- Строго удерживаем нули во время сброса
            if aresetn = '0' then
                s_axis_adc0_tdata  <= (others => '0');
                s_axis_adc0_tvalid <= '0';
                s_axis_adc1_tdata  <= (others => '0');
                s_axis_adc1_tvalid <= '0';
                sample_idx         := 0;
            else
                -- Начинаем подавать данные только ПОСЛЕ того, как сброс полностью завершен
                s_axis_adc0_tvalid <= '1';
                s_axis_adc1_tvalid <= '1';
                
                angle    := 2.0 * MATH_PI * SIGNAL_FREQ * real(sample_idx) / SAMPLE_RATE;
                sin_real := sin(angle);
                sin_int  := integer(sin_real * 32767.0);
                
                s_axis_adc0_tdata <= std_logic_vector(to_signed(sin_int, 16));
                s_axis_adc1_tdata <= (others => '0');
                
                sample_idx := sample_idx + 1;
            end if;
        end if;
    end process adc_signal_process;

    
    -- Процесс чтения .coe файла и конфигурации
    stimulus_file_process : process
        file coe_file       : text open read_mode is "E:/Projects/sdr200/Soft/Z7020/PL/PL.srcs/sim_1/new/fos_ssb.coe";
        variable file_line  : line;
        variable char       : character;
        variable hex_val    : std_logic_vector(17 downto 0); 
            -- Промежуточный вектор под 5 hex-значений из файла (5 * 4 = 20 бит)
        variable raw_20bit  : std_logic_vector(19 downto 0); 
        variable success    : boolean;
        variable i          : integer := 0;
        variable cfg_data_word : std_logic_vector(31 downto 0);
    begin
        -- Первоначальный сброс системы
        aresetn   <= '0';
        cfg_wr    <= '0';
        cfg_addra <= (others => '0');
        cfg_dina  <= (others => '0');
        -- Ждем 10 тактов генератора в состоянии сброса
        for k in 1 to 10 loop
            wait until rising_edge(aclk);
        end loop;
        aresetn   <= '1';
        -- Даем внутренним IP-ядрам 10 тактов на инициализацию после сброса
        for k in 1 to 10 loop
            wait until rising_edge(aclk);
        end loop;
    
        -- Пропускаем первые 6 строк заголовка .coe файла
        for k in 1 to 6 loop
            if not endfile(coe_file) then
                readline(coe_file, file_line);
            end if;
        end loop;
        
        -- Цикл чтения 128 коэффициентов фильтра из файла
        while not endfile(coe_file) and i < 128 loop
            readline(coe_file, file_line);
            
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
                -- Адреса x"03" или x"04" используются в зависимости от логики dest [0x01.1]
                if i < 64 then
                    write_cfg(x"03", cfg_data_word, aclk, cfg_addra, cfg_dina, cfg_wr);
                else
                    write_cfg(x"04", cfg_data_word, aclk, cfg_addra, cfg_dina, cfg_wr);
                end if;
                i := i + 1;
            end if;
        end loop;

        -- Настройка режима модуляции после загрузки фильтра
        write_cfg(x"01", x"00000000", aclk, cfg_addra, cfg_dina, cfg_wr); -- FPGA_MOD_J3E
        
        -- Запись частоты настройки DDS (адрес x"00")
        write_cfg(x"00", x"14D5DDDD", aclk, cfg_addra, cfg_dina, cfg_wr);

        write_cfg(x"03", x"00000007", aclk, cfg_addra, cfg_dina, cfg_wr); -- FOS GAIN CORRECT
        write_cfg(x"10", x"00000002", aclk, cfg_addra, cfg_dina, cfg_wr); -- correct out audio filter (0, 1, 2, 3
        -- Симуляция работы на синусе после конфигурирования
        wait for 10000 us;
        
        -- Остановка симуляции
        assert false report "Simulation Finished: COE file loaded successfully!" severity failure;
        wait;
    end process stimulus_file_process;

end Behavioral;