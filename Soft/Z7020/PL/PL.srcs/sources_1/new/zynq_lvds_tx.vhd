library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity zynq_lvds_tx is
    Port (
        -- 1. Системный интерфейс (122.88 МГц)
        aclk          : in  std_logic;
        aresetn       : in  std_logic; -- Активный '0'

        -- 2. Входной интерфейс AXI-Stream
        s_axis_tdata  : in  std_logic_vector(31 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- 3. Физический интерфейс линии (Выход на 2 дифпары ПЛИС)
        lvds_clk_p    : out std_logic;
        lvds_clk_n    : out std_logic;
        lvds_data_p   : out std_logic;
        lvds_data_n   : out std_logic
    );
end zynq_lvds_tx;

architecture Behavioral of zynq_lvds_tx is

    -- Компонент комбинаторного Verilog-кодера (Ericsson)
    component encode
        port (
            datain  : in  std_logic_vector(8 downto 0);
            dispin  : in  std_logic;
            dataout : out std_logic_vector(9 downto 0);
            dispout : out std_logic
        );
    end component;

    -- Компонент асинхронного FIFO (сгенерируйте Independent Clocks FIFO)
    -- Настройки в IP Catalog: Native, Вход 33 бита (32 данные + 1 tlast), Выход 33 бита
    component fifo_serin
        port (
            rst    : IN  STD_LOGIC;
            wr_clk : IN  STD_LOGIC;
            rd_clk : IN  STD_LOGIC;
            din    : IN  STD_LOGIC_VECTOR(32 DOWNTO 0);
            wr_en  : IN  STD_LOGIC;
            rd_en  : IN  STD_LOGIC;
            dout   : OUT STD_LOGIC_VECTOR(32 DOWNTO 0);
            full   : OUT STD_LOGIC;
            empty  : OUT STD_LOGIC
        );
    end component;

    -- Тактовые частоты передатчика
    -- Сигналы генератора частоты clk_line
    -- Шаг аккумулятора для получения ровно 12.000 МГц из 122.88 МГц
    constant FREQ_ACC_STEP : unsigned(23 downto 0) := TO_UNSIGNED(1638400, 24);
    signal phase_accumulator : unsigned(23 downto 0) := (others => '0');
    signal clk_line_internal : std_logic := '0';
    signal clk_line       : std_logic; -- Частота передачи байт (~10 МГц)
    
        -- Сигналы для автоматической генерации TLAST (домен 122.88 МГц)
    signal wr_sample_counter  : unsigned(7 downto 0) := (others => '0'); -- Счетчик от 0 до 255
    signal internal_tlast     : std_logic := '0';    
    
    -- Сброс линии
    signal reset_line     : std_logic;
    signal rst_sync_reg1  : std_logic := '1';
    signal rst_sync_reg2  : std_logic := '1';

    -- Сигналы FIFO
    signal fifo_din       : std_logic_vector(32 downto 0);
    signal fifo_wren      : std_logic;
    signal fifo_rden      : std_logic := '0';
    signal fifo_dout      : std_logic_vector(32 downto 0);
    signal fifo_full      : std_logic;
    signal fifo_empty     : std_logic;

    -- Сигналы автомата отправки (FSM на частоте clk_line)
    type state_type is (ST_IDLE, ST_SEND_COMMA, ST_READ_WORD, ST_SEND_BYTES);
    signal state : state_type := ST_IDLE;

    signal byte_pos       : integer range 0 to 3 := 0;
    signal reg_word_32bit : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_tlast      : std_logic := '0';

    -- Сигналы подключения кодера 8b/10b
    signal enc_in_9bit    : std_logic_vector(8 downto 0);
    signal enc_data       : std_logic_vector(7 downto 0) := (others => '0');
    signal enc_is_k       : std_logic := '0';
    signal enc_dataout    : std_logic_vector(9 downto 0);
    signal enc_dispout    : std_logic;
    signal current_disp   : std_logic := '0';
    signal reg_enc_dataout : std_logic_vector(9 downto 0) := (others => '0');
    signal reg_enc_dispout : std_logic := '0';
    signal current_disp_delayed : std_logic := '0';

    -- Сигналы сериализатора 10:1 (выдача бит на пин)
    signal tx_shift_reg   : std_logic_vector(9 downto 0) := (others => '0');
    signal bit_count      : integer range 0 to 9 := 0;
    signal tx_bit         : std_logic := '0';

begin

    ---------------------------------------------------------------------------
    -- Генератор точной частоты clk_line (10 МГц) из aclk (122.88 МГц)
    ---------------------------------------------------------------------------
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                phase_accumulator <= (others => '0');
                clk_line_internal <= '0';
            else
                -- Постоянно накапливаем фазу
                phase_accumulator <= phase_accumulator + FREQ_ACC_STEP;
                
                -- Старший бит аккумулятора определяет состояние тактового сигнала
                clk_line_internal <= phase_accumulator(23);
            end if;
        end if;
    end process;
    
    -- Привязываем внутренний клок к сигнальной линии всего остального кода
    clk_line <= clk_line_internal;
    
    ---------------------------------------------------------------------------
    -- ВНУТРЕННИЙ СЧЕТЧИК И АВТОГЕНЕРАЦИЯ TLAST (на частоте 122.88 МГц)
    ---------------------------------------------------------------------------
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_sample_counter <= (others => '0');
                internal_tlast    <= '0';
            else
                -- Если данные от процессора валидны и FIFO готово принять (произошел факт записи сэмпла)
                if (s_axis_tvalid = '1' and fifo_full = '0') then
                    -- Если записали 255-й сэмпл (индексы от 0 до 255 = всего 256), сбрасываемся
                    if wr_sample_counter = 255 then
                        wr_sample_counter <= (others => '0');
                    else
                        wr_sample_counter <= wr_sample_counter + 1;
                    end if;
                end if;

                -- Формируем опережающий флаг TLAST для СЛЕДУЮЩЕГО записываемого слова.
                -- Когда счетчик равен 254 и происходит успешная запись, следующее слово (255-е) будет финальным.
                if (s_axis_tvalid = '1' and fifo_full = '0' and wr_sample_counter = 254) or 
                   (wr_sample_counter = 255 and not(s_axis_tvalid = '1' and fifo_full = '0')) then
                    internal_tlast <= '1';
                else
                    internal_tlast <= '0';
                end if;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- 1. Буферизация входного потока AXI-Stream на частоте 122.88 МГц
    ---------------------------------------------------------------------------
    -- Принимаем данные, если FIFO не заполнено
    s_axis_tready <= not fifo_full;
    fifo_wren     <= s_axis_tvalid and (not fifo_full);
    
    fifo_din(31 downto 0) <= s_axis_tdata;
    fifo_din(32)          <= internal_tlast;

    -- Перенос безопасного сброса в домен clk_line
    process(clk_line)
    begin
        if rising_edge(clk_line) then
            rst_sync_reg1 <= not aresetn;
            rst_sync_reg2 <= rst_sync_reg1;
        end if;
    end process;
    reset_line <= rst_sync_reg2;

    ---------------------------------------------------------------------------
    -- 2. Подключение асинхронного FIFO (Переход с 122.88 МГц на частоту линии)
    ---------------------------------------------------------------------------
    tx_fifo_inst : fifo_serin
        port map (
            rst    => reset_line,
            wr_clk => aclk,          -- 122.88 МГц
            wr_en  => fifo_wren,
            din    => fifo_din,
            
            rd_clk => clk_line,      -- Скорость линии (~10 МГц)
            rd_en  => fifo_rden,
            dout   => fifo_dout,
            full   => fifo_full,
            empty  => fifo_empty
        );

       ---------------------------------------------------------------------------
    -- ПОДКЛЮЧЕНИЕ КОДЕРА (Остаётся комбинаторным)
    ---------------------------------------------------------------------------
    enc_in_9bit <= enc_is_k & enc_data;

    u_encoder : encode
        port map (
            datain  => enc_in_9bit,
            dispin  => current_disp, -- Управляется строго внутри автомата
            dataout => enc_dataout,
            dispout => enc_dispout   -- Для автомата (симулятор больше не зациклится)
        );

    ---------------------------------------------------------------------------
    -- ЕДИНЫЙ, СИНХРОННЫЙ ПРОЦЕСС (Автомат, Полярность и Сериализатор)
    ---------------------------------------------------------------------------
    process(clk_line)
    begin
        if rising_edge(clk_line) then
            if reset_line = '1' then
                -- Сброс сериализатора
                tx_shift_reg   <= (others => '0');
                bit_count      <= 0;
                tx_bit         <= '0';
                
                -- Сброс автомата
                state          <= ST_IDLE;
                fifo_rden      <= '0';
                byte_pos       <= 0;
                reg_word_32bit <= (others => '0');
                reg_tlast      <= '0';
                enc_data       <= (others => '0');
                enc_is_k       <= '0';
                current_disp   <= '0';
            else
                fifo_rden <= '0'; -- Сброс строба чтения FIFO по умолчанию

                -- ШАГ 1: Сериализатор (работает КАЖДЫЙ такт clk_line)
                if bit_count = 0 then
                    -- Защелкиваем готовые 10 бит из кодера
                    tx_shift_reg <= enc_dataout;
                    tx_bit       <= enc_dataout(0);
                    bit_count    <= 1;
                else
                    tx_bit <= tx_shift_reg(bit_count);
                    
                    -- ШАГ 2: Конец байта! Срабатывает строго на 9-м такте
                    if bit_count = 9 then
                        bit_count <= 0; -- На следующем такте загрузим новый байт

                        -- ВАЖНО: Фиксируем полярность ОДНОВРЕМЕННО со сменой состояния автомата.
                        -- Симулятор теперь видит жесткий тактовый триггер и не зацикливается!
                        if state = ST_IDLE then
                            current_disp <= '0';
                        else
                            current_disp <= enc_dispout;
                        end if;

                        -------------------------------------------------------
                        -- ШАГ 3: АВТОМАТ СОСТОЯНИЙ (Раз в 10 тактов)
                        -------------------------------------------------------                      
                          case state is
                            -- Режим ожидания/паузы между кадрами
                            when ST_IDLE =>
                                -- По умолчанию в IDLE мы ВСЕГДА шлем коммы
                                enc_is_k <= '1';
                                enc_data <= X"BC";
                                
                                if fifo_empty = '0' then
                                    fifo_rden <= '1';   -- Запрашиваем слово. Оно придет на СЛЕДУЮЩЕМ такте.
                                    -- Мы НЕ трогаем enc_is_k здесь! В этот такт всё еще улетит комма K28.5.
                                    state     <= ST_READ_WORD; 
                                end if;

                            -- Состояние ST_SEND_COMMA больше не нужно, так как комма шлется непрерывно в IDLE!
                            -- Автомат сразу из IDLE прыгает в чтение слова и отправку байт.

                            when ST_SEND_COMMA =>
                                fifo_rden <= '1';   -- Запрашиваем 32 бита из FIFO
                                enc_is_k  <= '0';   
                                state     <= ST_READ_WORD;

                            when ST_READ_WORD =>
                                enc_is_k  <= '0';
                                reg_word_32bit <= fifo_dout(31 downto 0);
                                reg_tlast      <= fifo_dout(32);
                                enc_data       <= fifo_dout(7 downto 0); -- 1-й байт в кодер
                                byte_pos       <= 1;
                                state          <= ST_SEND_BYTES;

                            when ST_SEND_BYTES =>
                                case byte_pos is
                                    when 0 =>
                                        enc_data <= reg_word_32bit(7 downto 0);
                                        byte_pos <= 1;
                                    when 1 =>
                                        enc_data <= reg_word_32bit(15 downto 8); -- 2-й байт
                                        byte_pos <= 2;
                                    when 2 =>
                                        enc_data <= reg_word_32bit(23 downto 16); -- 3-й байт
                                        byte_pos <= 3;
                                    when 3 =>
                                        enc_data <= reg_word_32bit(31 downto 24); -- 4-й байт
                                        
                                        if reg_tlast = '1' then
                                            state <= ST_IDLE; -- Конец пакета (256 слов)
                                        elsif fifo_empty = '0' then
                                            fifo_rden <= '1';
                                            state     <= ST_READ_WORD;
                                        else
                                            state <= ST_IDLE; 
                                        end if;
                                    when others =>
                                        state <= ST_IDLE;
                                end case;
                            when others =>
                                state <= ST_IDLE;
                        end case;
                        -------------------------------------------------------
                    else
                        bit_count <= bit_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

---------------------------------------------------------------------------
-- 6. Физический вывод на дифференциальные пины LVDS_25
---------------------------------------------------------------------------
-- Буфер вывода тактовой частоты линии
OBUFDS_clk_inst : OBUFDS
    generic map (
        IOSTANDARD => "LVDS_25"
    )
    port map (
        I  => clk_line,
        O  => lvds_clk_p,
        OB => lvds_clk_n
    );

-- Буфер вывода последовательного потока данных
OBUFDS_data_inst : OBUFDS
    generic map (
        IOSTANDARD => "LVDS_25"
    )
    port map (
        I  => tx_bit,
        O  => lvds_data_p,
        OB => lvds_data_n
    );
    
end Behavioral;
