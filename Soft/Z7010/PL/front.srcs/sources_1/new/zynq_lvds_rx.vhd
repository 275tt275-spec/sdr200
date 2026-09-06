library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Библиотека Xilinx для работы с аппаратными буферами и SERDES
library UNISIM;
use UNISIM.VComponents.all;

entity zynq_lvds_rx is
    Port (
        -- 1. Физические дифференциальные интерфейсы (вход с пинов ПЛИС)
        lvds_clk_p   : in  std_logic;
        lvds_clk_n   : in  std_logic;
        lvds_data_p  : in  std_logic;
        lvds_data_n  : in  std_logic;

        -- 2. Системный интерфейс (ваша частота 122.88 МГц)
        aclk         : in  std_logic;
        aresetn      : in  std_logic; -- Активный '0'

        -- 3. Выходной интерфейс AXI-Stream (32 бита, работает на aclk)
        m_axis_tdata : out std_logic_vector(31 downto 0);
        m_axis_tvalid: out std_logic;
        m_axis_tlast : out std_logic;
        m_axis_tready: in std_logic;
        
        m_axis_config_tdata : out std_logic_vector(23 downto 0);
        m_axis_config_tvalid: out std_logic;
        m_axis_config_tlast : out std_logic;
        m_axis_config_tready: in  std_logic
    );
end zynq_lvds_rx;

architecture Behavioral of zynq_lvds_rx is

component ila_0 IS
PORT (
clk : IN STD_LOGIC;
probe0 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe2 : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    probe3 : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
    probe4 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe5 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
);
END component ila_0;

    ---------------------------------------------------------------------------
    -- Объявление компонента декодера (строго по портам из файла Ericsson)
    ---------------------------------------------------------------------------
    component decode
        port (
            datain   : in  std_logic_vector(9 downto 0);
            dispin   : in  std_logic;
            dataout  : out std_logic_vector(8 downto 0);
            dispout  : out std_logic;
            code_err : out std_logic;
            disp_err : out std_logic
        );
    end component;
    
    component fifo_serin
        port (
            rst         : IN  STD_LOGIC;
            wr_clk      : IN  STD_LOGIC;
            rd_clk      : IN  STD_LOGIC;
            din         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            wr_en       : IN  STD_LOGIC;
            rd_en       : IN  STD_LOGIC;
            dout        : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            full        : OUT STD_LOGIC;
            empty       : OUT STD_LOGIC;
            wr_rst_busy : OUT STD_LOGIC;
            rd_rst_busy : OUT STD_LOGIC
        );
    end component;

    -- Внутренние сигналы клока и сброса
    signal clk_line, clk_line_n      : std_logic;
    signal reset_line    : std_logic;
    signal rst_sync_reg1 : std_logic := '1';
    signal rst_sync_reg2 : std_logic := '1';

    -- Сигналы физического уровня (LVDS -> Однополярные)
    signal rx_data_bit, rx_data_bit_n   : std_logic;
    signal rx_data_10bit : std_logic_vector(9 downto 0) := (others => '0');
    signal shift_reg     : std_logic_vector(9 downto 0) := (others => '0');
    signal bit_count     : integer range 0 to 9 := 0;

    -- Сигналы для подключения декодера
    signal dec_out_9bit : std_logic_vector(8 downto 0);
    signal dec_data     : std_logic_vector(7 downto 0);
    signal dec_is_k     : std_logic;
    signal dec_err      : std_logic;
    signal dec_dispout  : std_logic;
    signal current_disp : std_logic := '0';

    -- Сигналы автомата сборки пакета (FSM)
    constant ST_WAIT_COMMA   : std_logic_vector(1 downto 0) := "01"; -- Состояние 1
    constant ST_RECEIVE_BYTES : std_logic_vector(1 downto 0) := "10"; -- Состояние 2    
    signal state : std_logic_vector(1 downto 0) := ST_WAIT_COMMA;
    
    signal byte_pos      : integer range 0 to 3 := 0; -- Позиция байта в 32-битном слове
    signal sample_count  : integer range 0 to 255 := 0; -- Счетчик сэмплов (всего 256)
    signal word_32bit    : std_logic_vector(31 downto 0) := (others => '0');
    
    -- Сигналы для записи в асинхронное FIFO
    signal fifo_wren     : std_logic := '0';
    signal fifo_din      : std_logic_vector(31 downto 0) := (others => '0'); -- 32 бита данных + 1 бит TLAST
    signal fifo_rden     : std_logic;
    signal fifo_dout     : std_logic_vector(31 downto 0);
    signal fifo_empty    : std_logic;
    signal rd_sample_counter : unsigned(7 downto 0) := (others => '0'); -- Счетчик от 0 до 255
    signal fifo_rden_reg     : std_logic := '0';
    
    signal config_done   : std_logic := '0';
    signal bitslip_timer : integer range 0 to 15 := 0; -- Таймер ожидания после сдвига

begin

    ---------------------------------------------------------------------------
    -- 1. Буферы физического уровня (LVDS_25)
    ---------------------------------------------------------------------------
    -- Принимаем дифференциальный клок линии (при скорости 8 Мбит/с это ~10 МГц)
    IBUFDS_clk_inst : IBUFDS
        generic map (IOSTANDARD => "LVDS_25", DIFF_TERM => TRUE)
        port map (O => clk_line_n, I => lvds_clk_p, IB => lvds_clk_n);

    -- Принимаем дифференциальные данные линии
    IBUFDS_data_inst : IBUFDS
        generic map (IOSTANDARD => "LVDS_25", DIFF_TERM => TRUE)
        port map (O => rx_data_bit_n, I => lvds_data_p, IB => lvds_data_n);
        
    clk_line <= not clk_line_n;
    rx_data_bit <= rx_data_bit_n;

    -- Синхронизатор сброса для домена частоты линии (безопасный переход)
    process(clk_line)
    begin
        if rising_edge(clk_line) then
            rst_sync_reg1 <= not aresetn;
            rst_sync_reg2 <= rst_sync_reg1;
        end if;
    end process;
    reset_line <= rst_sync_reg2;

   ---------------------------------------------------------------------------
    -- ОБЪЕДИНЕННЫЙ БЛОК: Десериализатор и правильный автомат (на битовом такте)
    ---------------------------------------------------------------------------
    process(clk_line)
begin
    if rising_edge(clk_line) then
        if reset_line = '1' then
            shift_reg     <= (others => '0');
            bit_count     <= 0;
            rx_data_10bit <= (others => '0');
            bitslip_timer <= 0;
            
            -- Сброс автомата пакетов
            state        <= ST_WAIT_COMMA;
            byte_pos     <= 0;
            sample_count <= 0;
            word_32bit   <= (others => '0');
            fifo_wren    <= '0';
            fifo_din     <= (others => '0'); -- Теперь строго 32 бита
        else
            -- По умолчанию строб записи выключен
            fifo_wren <= '0';
            
            -- Шаг А: Постоянно сдвигаем приходящие биты в регистр
            shift_reg <= rx_data_bit & shift_reg(9 downto 1);
            
            -- Шаг Б: Ровно раз в 10 тактов собрался полный байт!
            if bit_count = 9 then
                bit_count <= 0;
                
                -- Фиксируем 10 бит для декодера
                rx_data_10bit <= rx_data_bit & shift_reg(9 downto 1);
                
                -- Логика Bitslip (побитовое выравнивание 10-битной сетки)
                if bitslip_timer > 0 then
                    bitslip_timer <= bitslip_timer - 1;
                elsif dec_err = '1' then
                    bit_count <= 1; 
                    bitslip_timer <= 15; 
                end if;

                -------------------------------------------------------------------
                -- Шаг В: АВТОМАТ КАДРИРОВАНИЯ И ВЫРАВНИВАНИЯ (Раз в 10 тактов)
                -------------------------------------------------------------------
                
                -- ГЛОБАЛЬНОЕ ВЫРАВНИВАНИЕ: Если пришла комма K28.5, 
                -- мы сбрасываем байтовую сетку и не пишем в FIFO.
                if (dec_is_k = '1' and dec_data = X"BC") then
                    byte_pos <= 0;
                    -- Если комма пришла посреди приема данных - это признак досрочного конца/сброса кадра
                    if state = ST_RECEIVE_BYTES then
                        state <= ST_WAIT_COMMA;
                    end if;
                else
                    -- Если это НЕ комма K28.5, обрабатываем согласно автомату
                    case state is
                        
                        -- Ждали окончания потока комм. Пришел первый байт данных!
                        when ST_WAIT_COMMA =>
                            if dec_is_k = '0' then 
                                state        <= ST_RECEIVE_BYTES;
                                sample_count <= 0;
                                word_32bit(7 downto 0) <= dec_data;
                                byte_pos     <= 1;
                            end if;

                        -- Принимаем данные пакета (256 слов по 4 байта)
                        when ST_RECEIVE_BYTES =>
                            -- Если пришел любой другой К-символ посреди данных - ошибка, сброс кадра
                            if dec_is_k = '1' then
                                state <= ST_WAIT_COMMA;
                            else
                                case byte_pos is
                                    when 0 => 
                                        word_32bit(7 downto 0) <= dec_data; 
                                        byte_pos <= 1;
                                        
                                    when 1 => 
                                        word_32bit(15 downto 8) <= dec_data; 
                                        byte_pos <= 2;
                                        
                                    when 2 => 
                                        word_32bit(23 downto 16) <= dec_data; 
                                        byte_pos <= 3;
                                        
                                    when 3 => 
                                        -- Собираем финальное слово напрямую в fifo_din
                                        fifo_din  <= dec_data & word_32bit(23 downto 0);
                                        fifo_wren <= '1'; -- Строб записи в 32-битное FIFO
                                        byte_pos  <= 0;
                                        
                                        -- Проверка счетчика слов пакета
                                        if sample_count = 255 then
                                            state <= ST_WAIT_COMMA; -- Пакет полностью принят
                                        else
                                            sample_count <= sample_count + 1;
                                        end if;
                                        
                                    when others =>
                                        state <= ST_WAIT_COMMA;
                                end case;
                            end if;

                        when others =>
                            state <= ST_WAIT_COMMA;
                    end case;
                end if; -- Конец проверки на комму
                
            else
                bit_count <= bit_count + 1;
            end if;
        end if;
    end if;
end process;


    
    -- Выносим сигналы из 9-битного вектора декодера для удобства
    dec_data <= dec_out_9bit(7 downto 0); -- Младшие 8 бит - данные
    dec_is_k <= dec_out_9bit(8);          -- Старший 9-й бит - флаг К-символа

    ---------------------------------------------------------------------------
    -- Подключение экземпляра декодера
    ---------------------------------------------------------------------------
    u_decoder : decode
        port map (
            datain   => rx_data_10bit, -- 10 бит из вашего десериализатора
            dispin   => current_disp,
            dataout  => dec_out_9bit,
            dispout  => dec_dispout,
            code_err => dec_err,
            disp_err => open           -- Ошибку диспланса можно не использовать
        );

    -- Процесс сохранения полярности (Disparity) на регистре
    process(clk_line)
    begin
        if rising_edge(clk_line) then
            if reset_line = '1' then
                current_disp <= '0';
            else
                current_disp <= dec_dispout;
            end if;
        end if;
    end process;
    
debug_0 : ila_0
PORT MAP (
    clk  => aclk,
    probe0(0) => clk_line,
    probe1(0) => fifo_empty,
    probe2 => rx_data_10bit,
    probe3 => dec_out_9bit,
    probe4(0) => fifo_rden_reg,
    probe5 => fifo_din,
    probe6(0) => fifo_wren,
    probe7(0) => fifo_rden 
);
    
    ---------------------------------------------------------------------------
    -- 5. Подключение сгенерированного примитива FIFO
    ---------------------------------------------------------------------------
async_fifo_inst : fifo_serin
    port map (
        rst         => reset_line,         -- Сброс
        
        -- Входная сторона (Запись на медленной частоте линии)
        wr_clk => clk_line,      -- Клок из дифпары
        wr_en  => fifo_wren,     -- Строб записи из Автомата (Блок №4)
        din    => fifo_din, 
        
        -- Выходная сторона (Чтение на вашей системной частоте)
        rd_clk => aclk,          -- 122.88 МГц
        rd_en  => fifo_rden,     -- Сигнал чтения из логики AXI-S (Блок №6)
        dout   => fifo_dout, 
        empty  => fifo_empty,     -- Флаг пустоты для Блока №6
        wr_rst_busy => open,
        rd_rst_busy => open
    );

    ---------------------------------------------------------------------------
    -- НАДЕЖНОЕ 6. Формирование интерфейса AXI4-Stream (на частоте 122.88 МГц)
    ---------------------------------------------------------------------------
    -- Читаем из FIFO, если оно не пустое И приемник AXI-Stream готов принимать данные.
    -- (Возврат m_axis_tready в логику обязателен для предотвращения потери данных,
    -- если последующий IP-блок, например FFT, временно выставит tready = '0').
--    fifo_rden <= '1' when (fifo_empty = '0' and (m_axis_tready = '1' or fifo_rden_reg = '0')) else '0';
    fifo_rden <= '1' when fifo_empty = '0' and fifo_rden_reg = '0' else '0';

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                fifo_rden_reg     <= '0';
                m_axis_tvalid     <= '0';
                m_axis_tdata      <= (others => '0');
                m_axis_tlast      <= '0';
                rd_sample_counter <= (others => '0');
            else
                -- Запоминаем факт чтения (данныеdout появятся на следующем такте)
                fifo_rden_reg <= fifo_rden;

                if fifo_rden_reg = '1' then
                    
                    m_axis_tvalid <= '1';
                    m_axis_tdata  <= fifo_dout;
                    
                    if rd_sample_counter = 255 then
                        m_axis_tlast      <= '1';            -- Выставляем честный TLAST наружу
                        rd_sample_counter <= (others => '0'); -- Обнуляем счетчик для следующего пакета
                    else
                        m_axis_tlast      <= '0';
                        rd_sample_counter <= rd_sample_counter + 1; -- Инкрементируем счетчик сэмплов
                    end if;

                elsif m_axis_tready = '1' then
                    -- Если из FIFO ничего не прочитано, но приемник готов - снимаем флаги
                    m_axis_tvalid <= '0';
                    m_axis_tlast  <= '0';
                end if;
            end if;
        end if;
    end process;
     
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_axis_config_tvalid <= '0';
                m_axis_config_tdata  <= (others => '0');
            else
                -- Подаем конфигурацию (например, 0x01 для прямого FFT)
                if config_done = '0' then
                    m_axis_config_tvalid <= '1';
                    -- ТОЧНОЕ 24-битное слово: Прямое FFT + Размер 2048 (11 в степени)
                    m_axis_config_tdata  <= X"000017";   
                    -- Если ядро подтвердило прием (tready = '1')
                    if m_axis_config_tready = '1' then
                        m_axis_config_tvalid <= '0';
                        config_done          <= '1'; -- Флаг завершения настройки
                    end if;
                end if;
            end if;
        end if;
    end process;
     
 end Behavioral;
