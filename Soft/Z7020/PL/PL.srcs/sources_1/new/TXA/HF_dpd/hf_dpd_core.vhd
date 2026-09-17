library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd_core is
    Generic (
        MEMORY_DEPTH    : integer := 3;
        LUT_ADDR_WIDTH  : integer := 8;
        DATA_WIDTH      : integer := 16;
        COEFF_WIDTH     : integer := 16;
        ERROR_OFFSET    : integer := 2
    );
    Port ( 
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC;
        s_axis_iq_i       : in  signed(15 downto 0);
        s_axis_iq_q       : in  signed(15 downto 0);
        m_axis_iq_i       : out signed(15 downto 0);
        m_axis_iq_q       : out signed(15 downto 0);
        s_axis_fb_i       : in  signed(15 downto 0);
        s_axis_fb_q       : in  signed(15 downto 0);
        s_axis_fb_valid   : in  STD_LOGIC;
        error_i           : in signed(31 downto 0);
        error_q           : in signed(31 downto 0);
        error_valid       : in  STD_LOGIC;
        cfg_learn_rate    : in  std_logic_vector(15 downto 0);
        cfg_delay_ticks   : in  std_logic_vector(4 downto 0); 
        cfg_train_en      : in  STD_LOGIC;
        cfg_hold_coeffs   : in  STD_LOGIC;
        m_ovf             : out STD_LOGIC
    );
end hf_dpd_core;

architecture Behavioral of hf_dpd_core is
    
    -- ========================================================================
    -- 1. ОПРЕДЕЛЕНИЕ ТИПОВ
    -- ========================================================================
    
    type signed_array_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    type fb_delay_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    
    type coeff_pair_t is record
        real_part : signed(COEFF_WIDTH-1 downto 0);
        imag_part : signed(COEFF_WIDTH-1 downto 0);
    end record;
    
    type coeff_pair_array_t is array (0 to MEMORY_DEPTH-1) of coeff_pair_t;
    type mult_result_t is array (0 to MEMORY_DEPTH-1) of signed(31 downto 0);
    
    -- Конвейер задержки адресов чтения для синхронизации с блоком записи (на 32 такта)
    constant PIPELINE_DEPTH : integer := 32;     
    -- Создаем тип: массив из 32 элементов, каждый элемент - это адрес (8 бит)
    type srl_pipe_t is array (0 to PIPELINE_DEPTH-1) of std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
    -- Матрица для всех ветвей памяти MEMORY_DEPTH
    type raddr_matrix_t is array (0 to MEMORY_DEPTH-1) of srl_pipe_t;  
    signal raddr_pipeline : raddr_matrix_t := (others => (others => (others => '0')));
    -- Явное указание Vivado использовать аппаратные SRL32 вместо триггеров
    attribute shreg_extract : string;
    attribute shreg_extract of raddr_pipeline : signal is "yes";
  
    component dpd_lut_bram is
    Generic (
        LUT_ADDR_WIDTH  : integer := 8;    -- 2^8 = 256 адресов
        COEFF_WIDTH     : integer := 16;   -- разрядность коэффициента
        INIT_FILE_REAL  : string  := "lut_real.mem";
        INIT_FILE_IMAG  : string  := "lut_imag.mem";
        MEMORY_DEPTH    : integer := 3     -- сколько BRAM-ветвей (обычно MEMORY_DEPTH DPD)
    );
    Port (
        -- Системные
        aclk            : in  std_logic;
        aresetn         : in  std_logic;

        -- Порт чтения (для прямого тракта)
        rd_addr         : in  std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
        rd_en           : in  std_logic;
        rd_real         : out std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        rd_imag         : out std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);

        -- Порт записи (для адаптации)
        wr_addr         : in  std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
        wr_real         : in  std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        wr_imag         : in  std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        wr_en           : in  std_logic_vector(MEMORY_DEPTH-1 downto 0)
    );
    end component dpd_lut_bram;
    
    component dpd_align_and_error_top is
    Generic (
        DATA_WIDTH   : integer := 16;
        ADDR_WIDTH   : integer := 8;    -- 2^8 = 256 тактов максимальной задержки для RAM
        ALPHA_SHIFT  : integer := 8     -- Коэффициент сглаживания фильтра (1/256)
    );
    Port (
        -- Системные сигналы
        aclk                 : in  std_logic;
        aresetn              : in  std_logic;
        
        -- Интерфейс конфигурации
        cfg_train_en         : in  std_logic;
        cfg_hold_coeffs      : in  std_logic;
        
        -- Входной опорный сигнал (Прямой тракт TX)
        s_axis_ref_tdata_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_ref_tdata_q   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_ref_tvalid    : in  std_logic;
        
        -- Входной сигнал обратной связи (Тракт приема FB от АЦП)
        s_axis_fb_tdata_i    : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_tdata_q    : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_tvalid     : in  std_logic;
        
        -- Выход вычисленной и сглаженной ошибки для адаптации LUT
        m_axis_err_i         : out signed(31 downto 0);
        m_axis_err_q         : out signed(31 downto 0);
        m_axis_err_valid     : out std_logic
    );
    end component dpd_align_and_error_top;
    
    
    signal in_i_reg, in_q_reg       : std_logic_vector(15 downto 0); 
    signal i_delayed, q_delayed : signed_array_t := (others => (others => '0'));
    signal i_curr, q_curr       : signed(15 downto 0) := (others => '0');
    signal amp_sq              : signed_array_t := (others => (others => '0'));
    
    signal bram_rd_addr  : std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
    signal bram_rd_en    : std_logic := '0';
    signal bram_rd_real  : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    signal bram_rd_imag  : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    signal bram_wr_addr  : std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
    signal bram_wr_real  : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    signal bram_wr_imag  : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    signal bram_wr_en    : std_logic_vector(MEMORY_DEPTH-1 downto 0);
    
    signal coeffs : coeff_pair_array_t;
    signal mult_i, mult_q : mult_result_t := (others => (others => '0'));
    signal sum_i, sum_q : signed(31 downto 0) := (others => '0');
    signal learn_rate : signed(15 downto 0);
    signal ovf_i, ovf_q : STD_LOGIC := '0';
    signal init_done : STD_LOGIC := '0';
    signal fb_i_delayed, fb_q_delayed : fb_delay_t := (others => (others => '0'));
    
begin
    
-- ========================================================================
-- 5. БЛОК ПРЯМОГО ТРАКТА (С МАСШТАБИРОВАНИЕМ ВХОДА)
-- ========================================================================
process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            i_curr <= (others => '0');
            q_curr <= (others => '0');
            i_delayed <= (others => (others => '0'));
            q_delayed <= (others => (others => '0'));
        else
            i_curr <= resize(shift_right(s_axis_iq_i, 2), 16);  -- Деление на 4                
            q_curr <= resize(shift_right(s_axis_iq_q, 2), 16);  -- Деление на 4
            
            -- Сдвиг задержек памяти полинома
            for m in 0 to MEMORY_DEPTH-2 loop
                i_delayed(m+1) <= i_delayed(m);
                q_delayed(m+1) <= q_delayed(m);
            end loop;
            i_delayed(0) <= i_curr;
            q_delayed(0) <= q_curr;
        end if;
    end if;
end process;
    
-- ========================================================================
-- 6. ВЫЧИСЛЕНИЕ КВАДРАТА АМПЛИТУДЫ И АДРЕСА BRAM
-- ========================================================================
process(aclk)
    variable i_sq_safe, q_sq_safe : signed(31 downto 0);
    variable sum_32               : unsigned(31 downto 0);
    variable shifted_sum          : unsigned(31 downto 0);
    variable amp_sq_curr          : signed(DATA_WIDTH-1 downto 0);
    variable current_addr_vec     : std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            amp_sq       <= (others => (others => '0'));
            bram_rd_addr <= (others => '0');
            bram_rd_en   <= '0';
        else
            -- Такт 1 относительно i_curr: расчет амплитуды
            i_sq_safe := i_curr * i_curr;
            q_sq_safe := q_curr * q_curr;
            sum_32    := unsigned(i_sq_safe) + unsigned(q_sq_safe);
            
            if is_x(std_logic_vector(sum_32)) then
                amp_sq_curr := (others => '0');
            else
                shifted_sum := shift_right(sum_32, 10);
                if shifted_sum > 65535 then
                    amp_sq_curr := to_signed(65535, DATA_WIDTH);
                else
                    amp_sq_curr := signed(resize(shifted_sum, DATA_WIDTH));
                end if;
            end if;
            
            amp_sq(0) <= amp_sq_curr;

            for m in 0 to MEMORY_DEPTH-2 loop
                amp_sq(m+1) <= amp_sq(m);
            end loop;

            -- Такт 2 относительно i_curr: фиксация адреса чтения BRAM
            current_addr_vec := std_logic_vector(amp_sq_curr(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH));
            bram_rd_addr     <= current_addr_vec;
            bram_rd_en       <= '1'; 
        end if;
    end if;
end process;

u_bram : dpd_lut_bram 
    Generic map(
        LUT_ADDR_WIDTH  => LUT_ADDR_WIDTH,
        COEFF_WIDTH     => COEFF_WIDTH,
        INIT_FILE_REAL  => "lut_real.mem",
        INIT_FILE_IMAG  => "lut_imag.mem",
        MEMORY_DEPTH    => MEMORY_DEPTH
    )
    Port map(
        aclk            => aclk,
        aresetn         => aresetn,
        rd_addr         => bram_rd_addr,
        rd_en           => bram_rd_en,
        rd_real         => bram_rd_real,
        rd_imag         => bram_rd_imag,
        wr_addr         => bram_wr_addr,
        wr_real         => bram_wr_real,
        wr_imag         => bram_wr_imag,
        wr_en           => bram_wr_en
    );

-- ========================================================================
-- 7. СИНХРОННОЕ ЧТЕНИЕ ИЗ BRAM И ПОДДЕРЖКА КОНВЕЙЕРА АДРЕСОВ
-- ========================================================================
gen_luts: for m in 0 to MEMORY_DEPTH-1 generate
    signal slice_real : std_logic_vector(COEFF_WIDTH-1 downto 0);
    signal slice_imag : std_logic_vector(COEFF_WIDTH-1 downto 0);
begin
    slice_real <= bram_rd_real((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH);
    slice_imag <= bram_rd_imag((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH);

    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                coeffs(m).real_part <= to_signed(16384, COEFF_WIDTH);
                coeffs(m).imag_part <= (others => '0');
                raddr_pipeline(m)   <= (others => (others => '0'));
            else
                raddr_pipeline(m) <= bram_rd_addr & raddr_pipeline(m)(0 to PIPELINE_DEPTH-2);                
                coeffs(m).real_part <= signed(slice_real);                
                coeffs(m).imag_part <= signed(slice_imag);
            end if;
        end if;
    end process;
end generate gen_luts;
    
-- ========================================================================
-- 8. ИСПРАВЛЕННЫЙ ВЫРОВНЕННЫЙ КОМПЛЕКСНЫЙ УМНОЖИТЕЛЬ ПОЛИНОМА ПАМЯТИ
-- ========================================================================
-- Использует конвейер синхронизации с BRAM и внутренние сумматоры DSP.
-- Полностью освобождает Slice LUT на операциях сложения/вычитания.
gen_mult: for m in 0 to MEMORY_DEPTH-1 generate
    signal x_i, x_q : signed(15 downto 0);
    
    -- Выравнивающий сдвиговый регистр на 4 такта для компенсации задержки LUT
    type delay_pipe_t is array (0 to 3) of signed(15 downto 0);
    signal x_i_pipe_reg : delay_pipe_t := (others => (others => '0'));
    signal x_q_pipe_reg : delay_pipe_t := (others => (others => '0'));
    
    -- Выровненные сигналы данных, пришедшие одновременно с coeffs(m)
    signal x_i_aligned  : signed(15 downto 0);
    signal x_q_aligned  : signed(15 downto 0);
    
    -- Конвейерные промежуточные регистры вычислений внутри DSP
    signal prod_i_stage1 : signed(31 downto 0) := (others => '0');
    signal prod_q_stage1 : signed(31 downto 0) := (others => '0');
    signal x_q_del        : signed(15 downto 0) := (others => '0');
    signal cr_del         : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
    signal ci_del         : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
begin
    -- Определение базовых отсчетов для текущей ветви нелинейной памяти DPD
    x_i <= i_curr when m = 0 else i_delayed(m-1);
    x_q <= q_curr when m = 0 else q_delayed(m-1);
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                x_i_pipe_reg  <= (others => (others => '0'));
                x_q_pipe_reg  <= (others => (others => '0'));
                prod_i_stage1 <= (others => '0');
                prod_q_stage1 <= (others => '0');
                x_q_del       <= (others => '0');
                cr_del        <= (others => '0');
                ci_del        <= (others => '0');
                mult_i(m)     <= (others => '0');
                mult_q(m)     <= (others => '0');
            else
                -----------------------------------------------------------
                -- ТАКТЫ 1-4: Линия задержки данных под логику работы BRAM
                -----------------------------------------------------------
                x_i_pipe_reg <= x_i & x_i_pipe_reg(0 to 2);
                x_q_pipe_reg <= x_q & x_q_pipe_reg(0 to 2);
                
                -- Эти сигналы теперь идеально выровнены по времени с coeffs(m)
                x_i_aligned <= x_i_pipe_reg(1);
                x_q_aligned <= x_q_pipe_reg(1);
                
                -----------------------------------------------------------
                -- ТАКТ 5 (УМНОЖЕНИЕ): DSP Stage 1
                -----------------------------------------------------------
                prod_i_stage1 <= x_i_aligned * coeffs(m).real_part; -- (Xi * Cr)
                prod_q_stage1 <= x_i_aligned * coeffs(m).imag_part; -- (Xi * Ci)
                
                x_q_del <= x_q_aligned;
                cr_del  <= coeffs(m).real_part;
                ci_del  <= coeffs(m).imag_part;
                
                -----------------------------------------------------------
                -- ТАКТ 6 (СЛОЖЕНИЕ/ВЫЧИТАНИЕ): DSP Stage 2
                -----------------------------------------------------------
                -- Для I: mult_i = (Xi * Cr) - (Xq * Ci)
                mult_i(m) <= prod_i_stage1 - (x_q_del * ci_del);
                
                -- Для Q: mult_q = (Xi * Ci) + (Xq * Cr)
                mult_q(m) <= prod_q_stage1 + (x_q_del * cr_del);
            end if;
        end if;
    end process;
end generate;

    
-- ========================================================================
-- 9. СУММИРОВАНИЕ С ЗАЩИТОЙ ОТ ПЕРЕПОЛНЕНИЯ
-- ========================================================================
process(aclk)
    variable temp_i, temp_q : signed(63 downto 0);
    constant MAX_32BIT : signed(63 downto 0) := to_signed(2147483647, 64);
    constant MIN_32BIT : signed(63 downto 0) := to_signed(-2147483648, 64);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            sum_i <= (others => '0');
            sum_q <= (others => '0');
            ovf_i <= '0';
            ovf_q <= '0';
        else
            ovf_i <= '0';
            ovf_q <= '0';
            
            temp_i := (others => '0');
            temp_q := (others => '0');
            
            for m in 0 to MEMORY_DEPTH-1 loop
                temp_i := temp_i + resize(mult_i(m), 64);                    
                temp_q := temp_q + resize(mult_q(m), 64);
            end loop;
            
            -- Насыщение для I
            if temp_i > MAX_32BIT then
                sum_i <= to_signed(2147483647, 32);
                ovf_i <= '1';
            elsif temp_i < MIN_32BIT then
                sum_i <= to_signed(-2147483648, 32);
                ovf_i <= '1';
            else
                sum_i <= resize(temp_i, 32);
            end if;
            
            -- Насыщение для Q
            if temp_q > MAX_32BIT then
                sum_q <= to_signed(2147483647, 32);
                ovf_q <= '1';
            elsif temp_q < MIN_32BIT then
                sum_q <= to_signed(-2147483648, 32);
                ovf_q <= '1';
            else
                sum_q <= resize(temp_q, 32);
            end if;
        end if;
    end if;
end process;
    
    -- ========================================================================
    -- 10. ФОРМИРОВАНИЕ ВЫХОДНОГО СИГНАЛА (С МАСШТАБИРОВАНИЕМ)
    -- ========================================================================
    process(aclk)
        variable temp_i, temp_q : signed(15 downto 0);
        variable sum_i_rounded, sum_q_rounded : signed(31 downto 0);
        constant SHIFT : integer := 12;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_axis_iq_i <= (others => '0');
                m_axis_iq_q <= (others => '0');
            else
                -- ================================================================
                -- I КАНАЛ
                -- ================================================================
                -- Добавляем половину для округления
                sum_i_rounded := sum_i + to_signed(2**(SHIFT-1), 32);
                temp_i := resize(shift_right(sum_i_rounded, SHIFT), 16);
                
                if temp_i > to_signed(32767, 16) then
                    m_axis_iq_i <= to_signed(32767, 16);
                elsif temp_i < to_signed(-32768, 16) then
                    m_axis_iq_i <= to_signed(-32768, 16);
                else
                    m_axis_iq_i <= temp_i;
                end if;
                
                -- ================================================================
                -- Q КАНАЛ
                -- ================================================================
                sum_q_rounded := sum_q + to_signed(2**(SHIFT-1), 32);
                temp_q := resize(shift_right(sum_q_rounded, SHIFT), 16);
                
                if temp_q > to_signed(32767, 16) then
                    m_axis_iq_q <= to_signed(32767, 16);
                elsif temp_q < to_signed(-32768, 16) then
                    m_axis_iq_q <= to_signed(-32768, 16);
                else
                    m_axis_iq_q <= temp_q;
                end if;
            end if;
        end if;
    end process;
    
    m_ovf <= ovf_i or ovf_q; 
    
    -- ========================================================================
    -- 11.ФОРМИРОВАНИЕ СДВИГОВЫХ РЕГИСТРОВ ОБРАТНОЙ СВЯЗИ (ПО СТРОБУ DDC)
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                fb_i_delayed <= (others => (others => '0'));
                fb_q_delayed <= (others => (others => '0'));
            else
                -- КРИТИЧЕСКИ ВАЖНО: сдвиг происходит ТОЛЬКО когда DDC выдал новый отсчет
                if s_axis_fb_valid = '1' then
                    
                    -- Сдвигаем историю задержек памяти для полинома назад
                    for m in MEMORY_DEPTH-1 downto 1 loop
                        fb_i_delayed(m) <= fb_i_delayed(m-1);
                        fb_q_delayed(m) <= fb_q_delayed(m-1);
                    end loop;
                    
                    -- Записываем свежий отсчет с выхода DDC в нулевую ячейку
                    fb_i_delayed(0) <= s_axis_fb_i;
                    fb_q_delayed(0) <= s_axis_fb_q;
                    
                end if;
            end if;
        end if;
    end process;
    
    learn_rate <= resize(signed(cfg_learn_rate), 16);

-- ========================================================================
-- 12. АППАРАТНО ОПТИМИЗИРОВАННЫЙ БЛОК ОБНОВЛЕНИЯ LUT (ZYNQ-7020 COMPLIANT)
-- ========================================================================
-- Адаптирован для работы с внешним Block RAM (через порты bram_wr_...)
process(aclk)
    -- Локальный массив-аккумулятор для ВСЕХ 256 адресов и всех ветвей памяти.
    -- Позволяет мгновенно извлекать и обновлять веса при любой динамике адреса.
    type lut_cache_t is array (0 to 2**LUT_ADDR_WIDTH-1) of signed(COEFF_WIDTH-1 downto 0);
    type lut_cache_matrix_t is array (0 to MEMORY_DEPTH-1) of lut_cache_t;
    
    variable shadow_matrix_real   : lut_cache_matrix_t := (others => (others => to_signed(16384, COEFF_WIDTH)));
    variable shadow_matrix_imag   : lut_cache_matrix_t := (others => (others => (others => '0')));
    variable local_init_done      : std_logic := '0';

    variable grad_i, grad_q       : signed(31 downto 0);
    variable update_i, update_q   : signed(31 downto 0);
    variable new_real, new_imag   : signed(COEFF_WIDTH-1 downto 0);
    variable addr_int             : integer;
    variable safe_real, safe_imag : signed(COEFF_WIDTH-1 downto 0);
    
    variable delay_idx            : integer range 0 to PIPELINE_DEPTH-1;
    
    -- Выровненные 16-битные порты для DSP48E1 (16x16 = 32 бита на выходе)
    variable err_i_16, err_q_16   : signed(15 downto 0);
    variable prod_ii, prod_qq     : signed(31 downto 0);
    variable prod_qi, prod_iq     : signed(31 downto 0);
    variable shift_i, shift_q     : signed(31 downto 0);        
    
    -- Границы 16-битного знакового диапазона для входной ошибки
    constant MAX_ERR_IN_16BIT     : signed(31 downto 0) := to_signed(32767, 32);
    constant MIN_ERR_IN_16BIT     : signed(31 downto 0) := to_signed(-32768, 32);
    
    constant MAX_COEFF            : signed(COEFF_WIDTH-1 downto 0) := to_signed(32767, COEFF_WIDTH);
    constant MIN_COEFF            : signed(COEFF_WIDTH-1 downto 0) := to_signed(-32768, COEFF_WIDTH);
    constant MAX_UPDATE           : signed(31 downto 0) := to_signed(512, 32);
    constant MAX_GRAD             : signed(31 downto 0) := to_signed(32767, 32);  
    
    -- Временные переменные для сборки упакованных шин записи в BRAM
    variable v_wr_real : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    variable v_wr_imag : std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
    variable v_wr_en   : std_logic_vector(MEMORY_DEPTH-1 downto 0);
    variable v_wr_addr : std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            init_done    <= '1';
            bram_wr_en   <= (others => '0');
            bram_wr_addr <= (others => '0');
            bram_wr_real <= (others => '0');
            bram_wr_imag <= (others => '0');
        else
            -- Первичная инициализация локального кэша стартовыми значениями при выходе из сброса
            if local_init_done = '0' then
                for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                    for m in 0 to MEMORY_DEPTH-1 loop
                        shadow_matrix_real(m)(addr) := to_signed(16384, COEFF_WIDTH);
                        shadow_matrix_imag(m)(addr) := (others => '0');
                    end loop;
                end loop;
                local_init_done := '1';
            end if;
        
            -- По умолчанию запись в BRAM выключена
            v_wr_en   := (others => '0');
            v_wr_addr := (others => '0');
            v_wr_real := (others => '0');
            v_wr_imag := (others => '0');

            if cfg_train_en = '1' and cfg_hold_coeffs = '0' and s_axis_fb_valid = '1' then                    
                
                -- 1. НАДЁЖНОЕ ВЫРЕЗАНИЕ И НАСЫЩЕНИЕ АКТИВНОЙ ЗОНЫ ОШИБКИ
                if error_i > MAX_ERR_IN_16BIT then
                    err_i_16 := to_signed(32767, 16);
                elsif error_i < MIN_ERR_IN_16BIT then
                    err_i_16 := to_signed(-32768, 16);
                else
                    err_i_16 := resize(error_i, 16);
                end if;
                
                if error_q > MAX_ERR_IN_16BIT then
                    err_q_16 := to_signed(32767, 16);
                elsif error_q < MIN_ERR_IN_16BIT then
                    err_q_16 := to_signed(-32768, 16);
                else
                    err_q_16 := resize(error_q, 16);
                end if;
                
                -- Вычисление индекса чтения адреса записи
                delay_idx := to_integer(unsigned(cfg_delay_ticks)) + ERROR_OFFSET;
                if delay_idx > PIPELINE_DEPTH-1 then
                    delay_idx := PIPELINE_DEPTH-1;
                end if;
                
                -- Все ветви DPD в данном ядре обновляются по одному и тому же адресу задержки,
                -- так как raddr_pipeline(m) для всех ветвей работает синхронно.
                -- Берем адрес из конвейера нулевой ветви.
                addr_int := to_integer(unsigned(raddr_pipeline(0)(delay_idx)));
                if addr_int >= 2**LUT_ADDR_WIDTH then
                    addr_int := 2**LUT_ADDR_WIDTH - 1;
                elsif addr_int < 0 then
                    addr_int := 0;
                end if;

                v_wr_addr := std_logic_vector(to_unsigned(addr_int, LUT_ADDR_WIDTH));

                -- Цикл адаптации весов полинома памяти
                for m in 0 to MEMORY_DEPTH-1 loop                        

                    -- 2. ВЫЧИСЛЕНИЕ ПРОИЗВЕДЕНИЙ (16х16 = 32 бита)
                    prod_ii := fb_i_delayed(m) * err_i_16;
                    prod_qq := fb_q_delayed(m) * err_q_16;
                    prod_qi := fb_q_delayed(m) * err_i_16;
                    prod_iq := fb_i_delayed(m) * err_q_16;

                    -- 3. МАСШТАБИРОВАНИЕ ГРАДИЕНТА С ПРАВИЛЬНЫМ СДВИГОМ (14 БИТ)
                    if addr_int > 18 then
                        shift_i := shift_right(prod_ii, 14) + shift_right(prod_qq, 14);
                        shift_q := shift_right(prod_qi, 14) - shift_right(prod_iq, 14);
                    elsif addr_int > 7 then
                        shift_i := shift_right(prod_ii, 13) + shift_right(prod_qq, 13);
                        shift_q := shift_right(prod_qi, 13) - shift_right(prod_iq, 13);  
                    else
                        shift_i := shift_right(prod_ii, 11) + shift_right(prod_qq, 11);
                        shift_q := shift_right(prod_qi, 11) - shift_right(prod_iq, 11);  
                    end if;  

                    grad_i := shift_i;
                    grad_q := shift_q;
                                                
                    -- Ограничение градиента
                    if grad_i > MAX_GRAD then
                        grad_i := MAX_GRAD;
                    elsif grad_i < -MAX_GRAD then
                        grad_i := -MAX_GRAD;
                    end if;
                    
                    if grad_q > MAX_GRAD then
                        grad_q := MAX_GRAD;
                    elsif grad_q < -MAX_GRAD then
                        grad_q := -MAX_GRAD;
                    end if;
                                        
                    -- Шаг адаптации LMS
                    update_i := resize(((grad_i * learn_rate) + 16384) / 32768, 32);
                    update_q := resize(((grad_q * learn_rate) + 16384) / 32768, 32);
                    
                    if update_i > MAX_UPDATE then
                        update_i := MAX_UPDATE;
                    elsif update_i < -MAX_UPDATE then
                        update_i := -MAX_UPDATE;
                    end if;
                    
                    if update_q > MAX_UPDATE then
                        update_q := MAX_UPDATE;
                    elsif update_q < -MAX_UPDATE then
                        update_q := -MAX_UPDATE;
                    end if;
                    
                    -- Извлечение текущего коэффициента, который сейчас находится на выходе BRAM
                    -- (Он зафиксирован в coeffs(m) благодаря конвейеру чтения)
--                   safe_real := coeffs(m).real_part;
--                    safe_imag := coeffs(m).imag_part;
                    
                    -- Читаем предыдущее состояние ИЗ ПОЛНОЦЕННОЙ МАТРИЦЫ КЭША по текущему адресу записи
                    safe_real := shadow_matrix_real(m)(addr_int);
                    safe_imag := shadow_matrix_imag(m)(addr_int);
                    
                    new_real := safe_real + resize(update_i, COEFF_WIDTH);
                    new_imag := safe_imag + resize(update_q, COEFF_WIDTH);
                    
                    -- Насыщение результатов адаптации
                    if new_real > MAX_COEFF then
                        new_real := MAX_COEFF;
                    elsif new_real < MIN_COEFF then
                        new_real := MIN_COEFF;
                    end if;
                    
                    if new_imag > MAX_COEFF then
                        new_imag := MAX_COEFF;
                    elsif new_imag < MIN_COEFF then
                        new_imag := MIN_COEFF;
                    end if;
                    
                    -- Обновляем значение прямо в матрице локального кэша
                    shadow_matrix_real(m)(addr_int) := new_real;
                    shadow_matrix_imag(m)(addr_int) := new_imag;

                    -- Упаковываем вычисленные значения в соответствующие слайсы переменных шины записи
                    v_wr_real((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH) := std_logic_vector(new_real);
                    v_wr_imag((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH) := std_logic_vector(new_imag);
                    v_wr_en(m) := '1'; -- Активируем флаг записи для этой ветви

                end loop;
            end if;

            -- Переносим значения из переменных процесса на сигналы портов BRAM
            bram_wr_addr <= v_wr_addr;
            bram_wr_real <= v_wr_real;
            bram_wr_imag <= v_wr_imag;
            bram_wr_en   <= v_wr_en;
        end if;
    end if;
end process;

   
    
end Behavioral;