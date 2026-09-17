library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dpd_error_calc is
    Generic (
        DATA_WIDTH  : integer := 16;
        ALPHA_SHIFT : integer := 8
    );
    Port (
        aclk               : in  STD_LOGIC;
        aresetn            : in  STD_LOGIC;
        s_axis_ref_i       : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_ref_q       : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_ref_valid   : in  STD_LOGIC;
        s_axis_fb_i        : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_q        : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_valid    : in  STD_LOGIC;
        cfg_train_en       : in  STD_LOGIC;
        cfg_hold_coeffs    : in  STD_LOGIC;
        cfg_delay_cycles   : in  std_logic_vector(4 downto 0); 
        m_axis_err_i       : out signed(31 downto 0);
        m_axis_err_q       : out signed(31 downto 0);
        m_axis_err_valid   : out STD_LOGIC
    );
end dpd_error_calc;

architecture Behavioral of dpd_error_calc is

    -- Максимальный размер буфера задержки (32 ячейки, от 0 до 31 такта)
    constant BUFFER_DEPTH  : integer := 32;
    
    type ram_buffer_t is array (0 to BUFFER_DEPTH-1) of signed(DATA_WIDTH-1 downto 0);
    signal ram_pipe_i      : ram_buffer_t := (others => (others => '0'));
    signal ram_pipe_q      : ram_buffer_t := (others => (others => '0'));
    
    -- Указатели адресов для циклического буфера
    signal wr_addr         : unsigned(4 downto 0) := (others => '0');
    signal rd_addr         : unsigned(4 downto 0) := (others => '0');

    -- Регистры для фиксации опорного сигнала, пока мы ждем обратную связь
    signal ref_hold_i      : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal ref_hold_q      : signed(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Сигналы для мгновенной ошибки (расширяем до 32 бит для безопасности)
    signal raw_err_i       : signed(31 downto 0) := (others => '0');
    signal raw_err_q       : signed(31 downto 0) := (others => '0');
    signal raw_err_valid   : std_logic := '0';

    -- Регистры фильтра (интеграторы EMA)
    signal filter_acc_i    : signed(31 downto 0) := (others => '0');
    signal filter_acc_q    : signed(31 downto 0) := (others => '0');
    signal filter_valid    : std_logic := '0';

begin

   -- Вычисление адреса чтения на лету на основе текущей программной задержки
   process(wr_addr, cfg_delay_cycles)
   begin
       rd_addr <= wr_addr - unsigned(cfg_delay_cycles);
   end process;

   process(aclk)
        variable diff_i : signed(31 downto 0);
        variable diff_q : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_addr       <= (others => '0');
                ref_hold_i    <= (others => '0');
                ref_hold_q    <= (others => '0');
                raw_err_i     <= (others => '0');
                raw_err_q     <= (others => '0');
                raw_err_valid <= '0';
                filter_acc_i  <= (others => '0');
                filter_acc_q  <= (others => '0');
                filter_valid  <= '0';
            else
                -- Шаг 1: Запись в циклический буфер RAM по стробу valid
                if s_axis_ref_valid = '1' then
                    ram_pipe_i(to_integer(wr_addr)) <= s_axis_ref_i;
                    ram_pipe_q(to_integer(wr_addr)) <= s_axis_ref_q;
                    wr_addr <= wr_addr + 1; -- Инкремент адреса записи (автоматически сбрасывается в 0 при 31)
                end if;
                
                -- Чтение из буфера с учетом динамического смещения rd_addr
                ref_hold_i <= ram_pipe_i(to_integer(rd_addr));
                ref_hold_q <= ram_pipe_q(to_integer(rd_addr));

                -- Шаг 2: Счет ошибки в момент прихода строба обратной связи
                if s_axis_fb_valid = '1' then
                    raw_err_i     <= resize(ref_hold_i, 32) - resize(s_axis_fb_i, 32);
                    raw_err_q     <= resize(ref_hold_q, 32) - resize(s_axis_fb_q, 32);
                    raw_err_valid <= '1';
                else
                    raw_err_valid <= '0';
                end if;

                -- Этап 2: Экспоненциальный сглаживающий фильтр (EMA)
                if raw_err_valid = '1' then
                    if cfg_train_en = '1' and cfg_hold_coeffs = '0' then
                        
                        diff_i := raw_err_i - filter_acc_i;
                        diff_q := raw_err_q - filter_acc_q;
                        
                        filter_acc_i <= filter_acc_i + shift_right(diff_i, ALPHA_SHIFT);
                        filter_acc_q <= filter_acc_q + shift_right(diff_q, ALPHA_SHIFT);
                        
                    end if;
                    filter_valid <= '1';
                else
                    filter_valid <= '0';
                end if;
                
            end if;
        end if;
    end process;

    -- Назначение выходных портов
    m_axis_err_i     <= filter_acc_i;
    m_axis_err_q     <= filter_acc_q;
    m_axis_err_valid <= filter_valid;

end Behavioral;
