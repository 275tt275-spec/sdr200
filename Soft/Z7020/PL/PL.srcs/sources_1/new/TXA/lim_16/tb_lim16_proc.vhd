library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_lim16_proc is
-- У тестбэнча нет внешних портов
end tb_lim16_proc;

architecture behavioral of tb_lim16_proc is

    -- Компонент тестируемого модуля (UUT)
    component lim16_proc
        Port ( 
            m_axis_audio_tdata  : out STD_LOGIC_VECTOR (15 downto 0);
            m_axis_audio_tvalid : out STD_LOGIC;
            s_axis_audio_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
            s_axis_audio_tvalid : in  STD_LOGIC; 
            s_axis_cfg_tdata    : in  STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdest    : in  STD_LOGIC_VECTOR (2 downto 0);
            s_axis_cfg_tvalid   : in  STD_LOGIC;
            lim_over            : out STD_LOGIC_VECTOR (6 downto 0);
            aclk                : in  STD_LOGIC
        );
    end component;

    -- Сигналы для подключения к UUT
    signal aclk                : std_logic := '0';
    signal s_axis_audio_tdata  : std_logic_vector(15 downto 0) := (others => '0');
    signal s_axis_audio_tvalid : std_logic := '0';
    signal s_axis_cfg_tdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest    : std_logic_vector(2 downto 0) := (others => '0');
    signal s_axis_cfg_tvalid   : std_logic := '0';
    
    signal m_axis_audio_tdata  : std_logic_vector(15 downto 0);
    signal m_axis_audio_tvalid : std_logic;
    signal lim_over            : std_logic_vector(6 downto 0);

    -- Константы синхронизации (например, 122,88 МГц)
    constant CLK_PERIOD : time := 8.138 ns;
    
    -- Флаг для остановки симуляции
    signal sim_done : boolean := false;
    
    type inputFile_t is file of integer;
    file integer_file: inputFile_t;
    signal data : STD_LOGIC_VECTOR ( 31 downto 0 ) := (others => '0');
    --Inputs
    signal outdata: integer;

begin

    -- Подключение тестируемого модуля
    uut: lim16_proc
        port map (
            m_axis_audio_tdata  => m_axis_audio_tdata,
            m_axis_audio_tvalid => m_axis_audio_tvalid,
            s_axis_audio_tdata  => s_axis_audio_tdata,
            s_axis_audio_tvalid => s_axis_audio_tvalid,
            s_axis_cfg_tdata    => s_axis_cfg_tdata,
            s_axis_cfg_tdest    => s_axis_cfg_tdest,
            s_axis_cfg_tvalid   => s_axis_cfg_tvalid,
            lim_over            => lim_over,
            aclk                => aclk
        );

    -- Генерация тактового сигнала (aclk)
    clk_process : process
    begin
        while not sim_done loop
            aclk <= '0';
            wait for CLK_PERIOD / 2;
            aclk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;
    
    read_from_file: process
    variable indata: integer;
    file data_in: inputFile_t open read_mode is "E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\300.raw";
    file data_out: inputFile_t open write_mode is "E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\audio_out.raw";
    begin        
        s_axis_audio_tvalid <= '0';
        wait for CLK_PERIOD;
        read(data_in, indata);
        data <= std_logic_vector(to_signed(indata, 32));
        s_axis_audio_tdata <= data(31 downto 16);
  --     s_axis_audio_tdata <= x"000000";
        
        outdata <= to_integer(signed(m_axis_audio_tdata & x"0000"));
        write(data_out, outdata);
        
        s_axis_audio_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_audio_tvalid <= '0';
        
        wait for CLK_PERIOD * 123;
        if endfile(data_in) then
            report "end of file -- looping back to start of file";
            file_close(data_in);
 --           file_close(data_out);
            file_open(data_in,"E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\300.raw");
        end if;
    end process;

    -- Главный процесс стимуляции (Конфигурация и сигналы)
    stim_process: process
        -- Процедура для удобной отправки конфигурационных данных
        procedure send_cfg(
            constant dest : in std_logic_vector(2 downto 0);
            constant data : in std_logic_vector(31 downto 0)
        ) is
        begin
            s_axis_cfg_tdest  <= dest;
            s_axis_cfg_tdata  <= data;
            s_axis_cfg_tvalid <= '1';
            wait for CLK_PERIOD;
            s_axis_cfg_tvalid <= '0';
            s_axis_cfg_tdata  <= (others => '0');
            s_axis_cfg_tdest  <= (others => '0');
            wait for CLK_PERIOD * 2;
        end procedure;

    begin
        -- Инициализация и ожидание сброса внутренних фильтров
        wait for CLK_PERIOD * 10;
        
        ------------------------------------------------------------------------
        -- Конфигурация регистров (на основе комментариев в вашем коде)
        ------------------------------------------------------------------------
        -- 0: lim_in_gain (По умолчанию "00" & x"3FFF")
        send_cfg("000", x"00003FFF");
        
        -- 1: lim_limit (По умолчанию x"0800")
        send_cfg("001", x"00000400");
        
        -- 2: lim_out_gain (По умолчанию "00" & x"3FFF")
        send_cfg("010", x"00003FFF");
        
        -- 3: phase_step DDS (По умолчанию x"1D9A" -> 1850 Hz)
        send_cfg("011", x"00001D9A");
        
        -- 4: limit_overshoot (По умолчанию x"3000")
        send_cfg("100", x"00002800");
        
--        wait for CLK_PERIOD * 20;
--
--        ------------------------------------------------------------------------
--        -- Подача тестового аудиосигнала (Импульсы и Синусоида)
--        ------------------------------------------------------------------------
--        -- 1. Одиночный импульс (Step response)
--        s_axis_audio_tdata  <= x"2000"; -- Положительный отсчет
--        s_axis_audio_tvalid <= '1';
--        wait for CLK_PERIOD;
--        s_axis_audio_tvalid <= '0';
--        
--        wait for CLK_PERIOD * 10; -- Ждем реакции системы
--        
--        -- 2. Синусоидальный сигнал 1 кГц на частоте дискретизации (допустим) 48 кГц
--        -- Будем подавать новые отсчеты каждые несколько тактов, имитируя tvalid
--        for i in 0 to 100 loop
--            s_axis_audio_tdata  <= x"3FFF"; -- Постоянная полка для проверки лимитера
--            s_axis_audio_tvalid <= '1';
--            wait for CLK_PERIOD;
--            s_axis_audio_tvalid <= '0';
--            
--            -- Имитируем интервал между аудио-семплами (например, 20 тактов)
--            wait for CLK_PERIOD * 20; 
--        end loop;
--
--        -- 3. Динамическая синусоида высокой амплитуды, чтобы вызвать перегрузку (lim_over)
--        for i in 0 to 10000 loop
--            -- Математическая генерация синуса внутри симулятора
--            -- Амплитуда x"7FFF" (максимум для 16-бит signed)
--            s_axis_audio_tdata <= std_logic_vector(to_signed(
--                integer(32767.0 * sin(2.0 * MATH_PI * real(i) / 48.0)), 16
--            ));
--            s_axis_audio_tvalid <= '1';
--            wait for CLK_PERIOD;
--            s_axis_audio_tvalid <= '0';
--            
--            wait for CLK_PERIOD * 10;
--        end loop;
--
--        -- Завершение симуляции
--        wait for CLK_PERIOD * 200;
--        sim_done <= true;
        wait;
    end process;

end behavioral;
