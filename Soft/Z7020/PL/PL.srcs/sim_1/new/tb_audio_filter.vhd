----------------------------------------------------------------------------------
-- Testbench for audio_filter with .COE file support
-- Поддержка формата Xilinx .COE файлов
-- Исправлено: устранены конфликты имен
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use STD.TEXTIO.ALL;

entity tb_audio_filter is
    generic (
        LP_COEFF_FILE : string := "E:\\Projects\\sdr200\\Soft\\Z7020\\PL\\PL.srcs\\sources_1\\new\\RXA\\lp_1400.coe";
        HP_COEFF_FILE : string := "E:\\Projects\\sdr200\\Soft\\Z7020\\PL\\PL.srcs\\sources_1\\new\\RXA\\hp_400.coe";
        COEFF_WIDTH   : integer := 18  -- Ширина коэффициентов из .COE файла
    );
end tb_audio_filter;

architecture Behavioral of tb_audio_filter is

    -- Сигналы для подключения к DUT
    signal aclk          : STD_LOGIC := '0';
    signal aresetn       : STD_LOGIC := '0';
    signal s_axis_in_tdata   : STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
    signal s_axis_in_tvalid  : STD_LOGIC := '0';
    signal m_axis_out_tdata  : STD_LOGIC_VECTOR(23 downto 0);
    signal m_axis_out_tvalid : STD_LOGIC;
    signal cfg_addra     : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal cfg_dina      : STD_LOGIC_VECTOR(31 downto 0) := (others => '0');
    signal cfg_wr        : STD_LOGIC := '0';

    -- Константы для тестирования
    constant CLK_PERIOD  : time := 8.138 ns;
    constant SAMPLE_RATE : integer := 16000;
    constant CLK_FREQ  : integer := 122880000;
    constant CLKS_PER_SAMPLE : integer := CLK_FREQ / SAMPLE_RATE;
    
    -- Тип для коэффициентов
    type coeff_array is array (integer range <>) of integer;
    
    -- Сигналы для коэффициентов
    signal lp_coeffs : coeff_array(0 to 127) := (others => 0);
    signal hp_coeffs : coeff_array(0 to 127) := (others => 0);
    signal lp_num_coeffs : integer := 0;
    signal hp_num_coeffs : integer := 0;
    
    -- Сигналы для генерации тестовых данных
    signal sample_counter : integer := 0;
    signal clk_counter : integer := 0;
    signal test_frequency : real := 1000.0;
    signal test_amplitude : real := 0.99;
    
    -- Сигналы для проверки
    signal error_count   : integer := 0;
    signal test_passed   : boolean := true;
    signal coeffs_loaded : boolean := false;
    signal test_done : boolean := false;

    -- ==============================================
    -- ПРОЦЕДУРЫ
    -- ==============================================
    
    -- Процедура записи в конфигурационный интерфейс
    procedure write_cfg(
        signal addr : out STD_LOGIC_VECTOR(7 downto 0);
        signal data : out STD_LOGIC_VECTOR(31 downto 0);
        signal wr : out STD_LOGIC;
        constant addr_val : in STD_LOGIC_VECTOR(7 downto 0);
        constant data_val : in STD_LOGIC_VECTOR(31 downto 0)
    ) is
    begin
        wait until rising_edge(aclk);
        addr <= addr_val;
        data <= data_val;
        wr <= '1';
        wait until rising_edge(aclk);
        wr <= '0';
        wait for 100 ns;
    end procedure write_cfg;
    
    -- Процедура загрузки коэффициентов из массива
    procedure load_coeffs(
        signal addr : out STD_LOGIC_VECTOR(7 downto 0);
        signal data : out STD_LOGIC_VECTOR(31 downto 0);
        signal wr : out STD_LOGIC;
        constant filter_type : in string;
        constant coeffs : in coeff_array;
        constant num_coeffs : in integer;
        constant coeff_bit_width : in integer := 18  -- Переименовано в coeff_bit_width
    ) is
        variable cmd_addr : STD_LOGIC_VECTOR(7 downto 0);
        variable data_word : STD_LOGIC_VECTOR(31 downto 0);
        variable coeff_value : integer;
    begin
        if filter_type = "LPF" then
            cmd_addr := x"0E";
            report "Loading " & integer'image(num_coeffs) & " LPF coefficients...";
        else
            cmd_addr := x"0F";
            report "Loading " & integer'image(num_coeffs) & " HPF coefficients...";
        end if;
        
        -- Загружаем коэффициенты
        for i in 0 to num_coeffs-1 loop
            -- Получаем значение коэффициента
            coeff_value := coeffs(i);
            
            -- Формируем 32-битное слово
            -- Для первого коэффициента устанавливаем MSB = '1' (флаг начала загрузки)
            if i = 0 then
                -- Старший бит = '1', остальные биты - значение коэффициента
                data_word := std_logic_vector(to_signed(coeff_value, 31)) & '1';
            else
                -- Старший бит = '0'
                data_word := std_logic_vector(to_signed(coeff_value, 32));
                data_word(31) := '0';
            end if;
            
            write_cfg(addr, data, wr, cmd_addr, data_word);
            wait for CLK_PERIOD * 2;
        end loop;
        
        wait for 1 us;
        report "Coefficients loaded successfully";
    end procedure load_coeffs;
    
    -- ==============================================
    -- ФУНКЦИЯ ПАРСИНГА ШЕСТНАДЦАТЕРИЧНОГО ЧИСЛА
    -- ==============================================
    function parse_hex(hex_str : string; width : integer) return integer is
        variable result : integer := 0;
        variable digit : integer;
    begin
        for i in 1 to hex_str'length loop
            result := result * 16;
            if hex_str(i) >= '0' and hex_str(i) <= '9' then
                digit := character'pos(hex_str(i)) - character'pos('0');
            elsif hex_str(i) >= 'A' and hex_str(i) <= 'F' then
                digit := character'pos(hex_str(i)) - character'pos('A') + 10;
            elsif hex_str(i) >= 'a' and hex_str(i) <= 'f' then
                digit := character'pos(hex_str(i)) - character'pos('a') + 10;
            else
                digit := 0;
            end if;
            result := result + digit;
        end loop;
        
        -- Обработка отрицательных чисел (дополнительный код)
        if hex_str'length > 0 and (hex_str(1) >= '8' and hex_str(1) <= 'F') then
            result := result - 2**width;
        end if;
        
        return result;
    end function parse_hex;

begin

    -- ==============================================
    -- ГЕНЕРАЦИЯ ТАКТОВОГО СИГНАЛА
    -- ==============================================
    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
        if test_done then
            wait;
        end if;
    end process;

    -- ==============================================
    -- ИНСТАНЦИРОВАНИЕ ТЕСТИРУЕМОГО МОДУЛЯ
    -- ==============================================
    dut : entity work.audio_filter
    port map (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_in_tdata => s_axis_in_tdata,
        s_axis_in_tvalid => s_axis_in_tvalid,
        m_axis_out_tdata => m_axis_out_tdata,
        m_axis_out_tvalid => m_axis_out_tvalid,
        cfg_addra => cfg_addra,
        cfg_dina => cfg_dina,
        cfg_wr => cfg_wr
    );

     -- ==============================================
    -- ЗАГРУЗКА КОЭФФИЦИЕНТОВ ИЗ .COE ФАЙЛА
    -- ==============================================
    load_coefficients : process
        file coeff_file : text;
        variable file_line : line;
        variable line_str : string(1 to 512);
        variable line_len : integer;
        variable coeff_value : integer;
        variable index : integer := 0;
        variable in_coef_section : boolean := false;
        variable radix : integer := 16;
        variable coeff_width_local : integer := COEFF_WIDTH;
        variable temp_str : string(1 to 32);
        variable temp_len : integer;
        variable char_pos : integer;
        variable start_pos : integer;
        variable is_negative : boolean := false;
    begin
        report "=========================================";
        report "Loading coefficients from .COE files...";
        report "=========================================";
        
        -- ==========================================
        -- ПАРСИНГ .COE ФАЙЛА ДЛЯ LPF
        -- ==========================================
        report "Loading LPF coefficients from: " & LP_COEFF_FILE;
        
        file_open(coeff_file, LP_COEFF_FILE, READ_MODE);
        index := 0;
        in_coef_section := false;
        radix := 16;
        coeff_width_local := COEFF_WIDTH;
        
        while not endfile(coeff_file) and index < 128 loop
            readline(coeff_file, file_line);
            
            -- Пропускаем пустые строки
            if file_line'length = 0 then
                next;
            end if;
            
            -- Копируем строку в переменную для обработки
            line_str := (others => ' ');
            line_len := file_line'length;
            for i in 1 to line_len loop
                line_str(i) := file_line(i);
            end loop;
            
            -- Проверяем на комментарии (;)
            if line_len > 0 and line_str(1) = ';' then
                next;
            end if;
            
            -- Проверяем на Radix
            if line_len > 5 and line_str(1 to 5) = "Radix" then
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        if i < line_len - 1 then
                            -- Пропускаем пробелы
                            char_pos := i + 1;
                            while char_pos <= line_len and line_str(char_pos) = ' ' loop
                                char_pos := char_pos + 1;
                            end loop;
                            
                            if char_pos <= line_len then
                                if line_str(char_pos) = '1' and char_pos < line_len and line_str(char_pos+1) = '0' then
                                    radix := 10;
                                elsif line_str(char_pos) = '1' and char_pos < line_len and line_str(char_pos+1) = '6' then
                                    radix := 16;
                                end if;
                            end if;
                        end if;
                        exit;
                    end if;
                end loop;
                report "Radix = " & integer'image(radix);
                next;
            end if;
            
            -- Проверяем на Coefficient_Width
            if line_len > 17 and line_str(1 to 17) = "Coefficient_Width" then
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        temp_str := (others => ' ');
                        temp_len := 0;
                        char_pos := i + 1;
                        
                        -- Пропускаем пробелы
                        while char_pos <= line_len and line_str(char_pos) = ' ' loop
                            char_pos := char_pos + 1;
                        end loop;
                        
                        -- Читаем число
                        while char_pos <= line_len and line_str(char_pos) >= '0' and line_str(char_pos) <= '9' loop
                            temp_len := temp_len + 1;
                            temp_str(temp_len) := line_str(char_pos);
                            char_pos := char_pos + 1;
                        end loop;
                        
                        if temp_len > 0 then
                            coeff_width_local := 0;
                            for j in 1 to temp_len loop
                                coeff_width_local := coeff_width_local * 10 + 
                                                     character'pos(temp_str(j)) - character'pos('0');
                            end loop;
                            report "Coefficient_Width = " & integer'image(coeff_width_local);
                        end if;
                        exit;
                    end if;
                end loop;
                next;
            end if;
            
            -- Проверяем на CoefData
            if line_len > 8 and line_str(1 to 8) = "CoefData" then
                in_coef_section := true;
                
                -- Находим знак '=' и начинаем парсить данные
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        char_pos := i + 1;
                        
                        -- Пропускаем пробелы
                        while char_pos <= line_len and line_str(char_pos) = ' ' loop
                            char_pos := char_pos + 1;
                        end loop;
                        
                        -- Парсим все числа в строке
                        while char_pos <= line_len loop
                            -- Пропускаем пробелы и запятые
                            while char_pos <= line_len and (line_str(char_pos) = ' ' or line_str(char_pos) = ',') loop
                                char_pos := char_pos + 1;
                            end loop;
                            
                            if char_pos > line_len then
                                exit;
                            end if;
                            
                            -- Находим конец числа
                            start_pos := char_pos;
                            while char_pos <= line_len loop
                                if line_str(char_pos) = ',' or line_str(char_pos) = ';' or line_str(char_pos) = ' ' then
                                    exit;
                                end if;
                                char_pos := char_pos + 1;
                            end loop;
                            
                            -- Извлекаем число
                            temp_str := (others => ' ');
                            temp_len := char_pos - start_pos;
                            for j in 1 to temp_len loop
                                temp_str(j) := line_str(start_pos + j - 1);
                            end loop;
                            
                            -- Конвертируем в integer
                            if temp_len > 0 then
                                if radix = 16 then
                                    coeff_value := parse_hex(temp_str(1 to temp_len), coeff_width_local);
                                else
                                    -- Десятичная система
                                    coeff_value := 0;
                                    for j in 1 to temp_len loop
                                        if temp_str(j) >= '0' and temp_str(j) <= '9' then
                                            coeff_value := coeff_value * 10 + (character'pos(temp_str(j)) - character'pos('0'));
                                        end if;
                                    end loop;
                                end if;
                                
                                lp_coeffs(index) <= coeff_value;
                                -- report "Coeff " & integer'image(index) & ": " & integer'image(coeff_value) & " (0x" & to_hstring(to_signed(coeff_value, 32)) & ")";
                                index := index + 1;
                            end if;
                            
                            -- Пропускаем запятую или точку с запятой
                            while char_pos <= line_len and (line_str(char_pos) = ',' or line_str(char_pos) = ';') loop
                                char_pos := char_pos + 1;
                            end loop;
                        end loop;
                        
                        exit;
                    end if;
                end loop;
                
                next;
            end if;
            
            -- Если мы в секции данных, парсим значения (многострочный формат)
            if in_coef_section and line_len > 0 then
                char_pos := 1;
                while char_pos <= line_len loop
                    -- Пропускаем пробелы и запятые
                    while char_pos <= line_len and (line_str(char_pos) = ' ' or line_str(char_pos) = ',') loop
                        char_pos := char_pos + 1;
                    end loop;
                    
                    if char_pos > line_len then
                        exit;
                    end if;
                    
                    -- Находим конец числа
                    start_pos := char_pos;
                    while char_pos <= line_len loop
                        if line_str(char_pos) = ',' or line_str(char_pos) = ';' or line_str(char_pos) = ' ' then
                            exit;
                        end if;
                        char_pos := char_pos + 1;
                    end loop;
                    
                    -- Извлекаем число
                    temp_str := (others => ' ');
                    temp_len := char_pos - start_pos;
                    for j in 1 to temp_len loop
                        temp_str(j) := line_str(start_pos + j - 1);
                    end loop;
                    
                    -- Конвертируем в integer
                    if temp_len > 0 then
                        if radix = 16 then
                            coeff_value := parse_hex(temp_str(1 to temp_len), coeff_width_local);
                        else
                            coeff_value := 0;
                            for j in 1 to temp_len loop
                                if temp_str(j) >= '0' and temp_str(j) <= '9' then
                                    coeff_value := coeff_value * 10 + (character'pos(temp_str(j)) - character'pos('0'));
                                end if;
                            end loop;
                        end if;
                        
                        lp_coeffs(index) <= coeff_value;
                        -- report "Coeff " & integer'image(index) & ": " & integer'image(coeff_value);
                        index := index + 1;
                    end if;
                    
                    -- Пропускаем запятую или точку с запятой
                    while char_pos <= line_len and (line_str(char_pos) = ',' or line_str(char_pos) = ';') loop
                        char_pos := char_pos + 1;
                    end loop;
                end loop;
            end if;
        end loop;
        
        file_close(coeff_file);
        lp_num_coeffs <= index;
        report "Loaded " & integer'image(index) & " LPF coefficients";
        
        -- ==========================================
        -- ПАРСИНГ .COE ФАЙЛА ДЛЯ HPF (аналогично)
        -- ==========================================
        report "Loading HPF coefficients from: " & HP_COEFF_FILE;
        
        file_open(coeff_file, HP_COEFF_FILE, READ_MODE);
        index := 0;
        in_coef_section := false;
        radix := 16;
        coeff_width_local := COEFF_WIDTH;
        
        while not endfile(coeff_file) and index < 128 loop
            readline(coeff_file, file_line);
            
            if file_line'length = 0 then
                next;
            end if;
            
            line_str := (others => ' ');
            line_len := file_line'length;
            for i in 1 to line_len loop
                line_str(i) := file_line(i);
            end loop;
            
            if line_len > 0 and line_str(1) = ';' then
                next;
            end if;
            
            -- Проверяем Radix
            if line_len > 5 and line_str(1 to 5) = "Radix" then
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        if i < line_len - 1 then
                            char_pos := i + 1;
                            while char_pos <= line_len and line_str(char_pos) = ' ' loop
                                char_pos := char_pos + 1;
                            end loop;
                            
                            if char_pos <= line_len then
                                if line_str(char_pos) = '1' and char_pos < line_len and line_str(char_pos+1) = '0' then
                                    radix := 10;
                                elsif line_str(char_pos) = '1' and char_pos < line_len and line_str(char_pos+1) = '6' then
                                    radix := 16;
                                end if;
                            end if;
                        end if;
                        exit;
                    end if;
                end loop;
                next;
            end if;
            
            -- Проверяем Coefficient_Width
            if line_len > 17 and line_str(1 to 17) = "Coefficient_Width" then
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        temp_str := (others => ' ');
                        temp_len := 0;
                        char_pos := i + 1;
                        
                        while char_pos <= line_len and line_str(char_pos) = ' ' loop
                            char_pos := char_pos + 1;
                        end loop;
                        
                        while char_pos <= line_len and line_str(char_pos) >= '0' and line_str(char_pos) <= '9' loop
                            temp_len := temp_len + 1;
                            temp_str(temp_len) := line_str(char_pos);
                            char_pos := char_pos + 1;
                        end loop;
                        
                        if temp_len > 0 then
                            coeff_width_local := 0;
                            for j in 1 to temp_len loop
                                coeff_width_local := coeff_width_local * 10 + 
                                                     character'pos(temp_str(j)) - character'pos('0');
                            end loop;
                        end if;
                        exit;
                    end if;
                end loop;
                next;
            end if;
            
            -- Проверяем CoefData
            if line_len > 8 and line_str(1 to 8) = "CoefData" then
                in_coef_section := true;
                
                for i in 1 to line_len loop
                    if line_str(i) = '=' then
                        char_pos := i + 1;
                        
                        while char_pos <= line_len and line_str(char_pos) = ' ' loop
                            char_pos := char_pos + 1;
                        end loop;
                        
                        while char_pos <= line_len loop
                            while char_pos <= line_len and (line_str(char_pos) = ' ' or line_str(char_pos) = ',') loop
                                char_pos := char_pos + 1;
                            end loop;
                            
                            if char_pos > line_len then
                                exit;
                            end if;
                            
                            start_pos := char_pos;
                            while char_pos <= line_len loop
                                if line_str(char_pos) = ',' or line_str(char_pos) = ';' or line_str(char_pos) = ' ' then
                                    exit;
                                end if;
                                char_pos := char_pos + 1;
                            end loop;
                            
                            temp_str := (others => ' ');
                            temp_len := char_pos - start_pos;
                            for j in 1 to temp_len loop
                                temp_str(j) := line_str(start_pos + j - 1);
                            end loop;
                            
                            if temp_len > 0 then
                                if radix = 16 then
                                    coeff_value := parse_hex(temp_str(1 to temp_len), coeff_width_local);
                                else
                                    coeff_value := 0;
                                    for j in 1 to temp_len loop
                                        if temp_str(j) >= '0' and temp_str(j) <= '9' then
                                            coeff_value := coeff_value * 10 + (character'pos(temp_str(j)) - character'pos('0'));
                                        end if;
                                    end loop;
                                end if;
                                
                                hp_coeffs(index) <= coeff_value;
                                index := index + 1;
                            end if;
                            
                            while char_pos <= line_len and (line_str(char_pos) = ',' or line_str(char_pos) = ';') loop
                                char_pos := char_pos + 1;
                            end loop;
                        end loop;
                        
                        exit;
                    end if;
                end loop;
                
                next;
            end if;
            
            -- Парсим многострочные данные
            if in_coef_section and line_len > 0 then
                char_pos := 1;
                while char_pos <= line_len loop
                    while char_pos <= line_len and (line_str(char_pos) = ' ' or line_str(char_pos) = ',') loop
                        char_pos := char_pos + 1;
                    end loop;
                    
                    if char_pos > line_len then
                        exit;
                    end if;
                    
                    start_pos := char_pos;
                    while char_pos <= line_len loop
                        if line_str(char_pos) = ',' or line_str(char_pos) = ';' or line_str(char_pos) = ' ' then
                            exit;
                        end if;
                        char_pos := char_pos + 1;
                    end loop;
                    
                    temp_str := (others => ' ');
                    temp_len := char_pos - start_pos;
                    for j in 1 to temp_len loop
                        temp_str(j) := line_str(start_pos + j - 1);
                    end loop;
                    
                    if temp_len > 0 then
                        if radix = 16 then
                            coeff_value := parse_hex(temp_str(1 to temp_len), coeff_width_local);
                        else
                            coeff_value := 0;
                            for j in 1 to temp_len loop
                                if temp_str(j) >= '0' and temp_str(j) <= '9' then
                                    coeff_value := coeff_value * 10 + (character'pos(temp_str(j)) - character'pos('0'));
                                end if;
                            end loop;
                        end if;
                        
                        hp_coeffs(index) <= coeff_value;
                        index := index + 1;
                    end if;
                    
                    while char_pos <= line_len and (line_str(char_pos) = ',' or line_str(char_pos) = ';') loop
                        char_pos := char_pos + 1;
                    end loop;
                end loop;
            end if;
        end loop;
        
        file_close(coeff_file);
        hp_num_coeffs <= index;
        report "Loaded " & integer'image(index) & " HPF coefficients";
        report "=========================================";
        
        coeffs_loaded <= true;
        wait;
    end process;

    -- ==============================================
    -- ГЕНЕРАЦИЯ ТЕСТОВЫХ ДАННЫХ
    -- ==============================================
    data_generator : process
        variable sample_value : real;
        variable int_value : integer;
    begin
        wait until rising_edge(aclk);
        
-- Счетчик тактов для формирования частоты дискретизации
        clk_counter <= clk_counter + 1;
        
        -- Генерируем валидный сигнал с частотой дискретизации
        if clk_counter >= CLKS_PER_SAMPLE - 1 then
            clk_counter <= 0;
            s_axis_in_tvalid <= '1';
            
            -- Генерируем новый семпл
            sample_value := test_amplitude * sin(2.0 * MATH_PI * test_frequency * real(sample_counter) / real(SAMPLE_RATE));
            int_value := integer(sample_value * 2.0**23);
            s_axis_in_tdata <= std_logic_vector(to_signed(int_value, 24));
            sample_counter <= sample_counter + 1;
        else
            s_axis_in_tvalid <= '0';
        end if;
    end process;

    -- ==============================================
    -- ОСНОВНОЙ ТЕСТОВЫЙ ПРОЦЕСС
    -- ==============================================
    test_process : process
    begin
        -- Ждем загрузки коэффициентов из файла
        wait for 1 us;
        
        if not coeffs_loaded then
            report "ERROR: Could not load coefficients from .COE files!" severity error;
            test_done <= true;
            wait;
        end if;
        
        wait for 1 us;
        
        -- ==========================================
        -- 1. НАЧАЛЬНАЯ ИНИЦИАЛИЗАЦИЯ
        -- ==========================================
        report "=========================================";
        report "Starting Testbench...";
        report "=========================================";
        
        aresetn <= '0';
        wait for 200 ns;
        aresetn <= '1';
        wait for 200 ns;
        
        report "Initialization complete";

        -- ==========================================
        -- 2. ЗАГРУЗКА КОЭФФИЦИЕНТОВ В ФИЛЬТР
        -- ==========================================
        report "=========================================";
        report "Loading coefficients into filter...";
        report "=========================================";
        
        -- Загружаем LPF коэффициенты
        load_coeffs(cfg_addra, cfg_dina, cfg_wr, "LPF", 
                    lp_coeffs(0 to lp_num_coeffs-1), lp_num_coeffs, COEFF_WIDTH);
        wait for 200 us;
        
        -- Загружаем HPF коэффициенты
        load_coeffs(cfg_addra, cfg_dina, cfg_wr, "HPF",
                    hp_coeffs(0 to hp_num_coeffs-1), hp_num_coeffs, COEFF_WIDTH);
        wait for 80 us;
        
        report "All coefficients loaded and ready";

        -- ==========================================
        -- 3. ТЕСТ ПРОХОЖДЕНИЯ СИГНАЛА
        -- ==========================================
        report "=========================================";
        report "Testing signal path...";
        report "=========================================";
        
        wait for 200 us;
        report "Signal path test complete";
        
        -- ==========================================
        -- 4. ТЕСТ ИЗМЕНЕНИЯ УСИЛЕНИЯ
        -- ==========================================
        report "=========================================";
        report "Testing gain correction...";
        report "=========================================";
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00050006");
        wait for 100 us;
        
        report "Gain correction test complete";

        -- ==========================================
        -- 5. ТЕСТ С РАЗНЫМИ ЧАСТОТАМИ
        -- ==========================================
        report "=========================================";
        report "Testing different frequencies...";
        report "=========================================";
        
        test_frequency <= 150.0;
        wait for 1500 us;
        
        test_frequency <= 1000.0;
        wait for 2000 us;
                
        test_frequency <= 3500.0;
        wait for 1500 us;
        
        report "Frequency test complete";
        
        -- ==========================================
        -- 4. ТЕСТ ИЗМЕНЕНИЯ УСИЛЕНИЯ
        -- ==========================================
        report "=========================================";
        report "Testing gain correction...";
        report "=========================================";
        
        test_frequency <= 1000.0;
        wait for 2000 us;
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00040004");
        wait for 1000 us;
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00050005");
        wait for 1000 us;        
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00060006");
        wait for 1000 us;
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00070007");
        wait for 1000 us;
        
        write_cfg(cfg_addra, cfg_dina, cfg_wr, x"10", x"00080008");
        wait for 2000 us;
      

        -- ==========================================
        -- 6. ЗАВЕРШЕНИЕ ТЕСТИРОВАНИЯ
        -- ==========================================
        report "=========================================";
        report "Testbench Complete!";
        report "=========================================";
        
        if test_passed then
            report "ALL TESTS PASSED!" severity note;
        else
            report "SOME TESTS FAILED! Error count: " & integer'image(error_count) severity error;
        end if;
        
        test_done <= true;
        wait;
    end process;

    -- ==============================================
    -- МОНИТОРИНГ ВЫХОДНЫХ ДАННЫХ
    -- ==============================================
    monitor_process : process
        variable sample_count : integer := 0;
        variable max_value : integer := 0;
        variable min_value : integer := 0;
        variable current_value : integer;
    begin
        wait until rising_edge(aclk);
        
        if m_axis_out_tvalid = '1' then
            sample_count := sample_count + 1;
            current_value := to_integer(signed(m_axis_out_tdata));
            
            if sample_count = 1 then
                max_value := current_value;
                min_value := current_value;
            else
                if current_value > max_value then
                    max_value := current_value;
                end if;
                if current_value < min_value then
                    min_value := current_value;
                end if;
            end if;
            
            if sample_count mod 1000 = 0 then
                report "Output stats - Samples: " & integer'image(sample_count) &
                       " Max: " & integer'image(max_value) &
                       " Min: " & integer'image(min_value);
                max_value := 0;
                min_value := 0;
            end if;
        end if;
    end process;

end Behavioral;