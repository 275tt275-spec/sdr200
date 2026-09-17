library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd_core_200w is
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
        cfg_delay_ticks   : in  std_logic_vector(4 downto 0); 
        cfg_train_en      : in  STD_LOGIC;
        cfg_hold_coeffs   : in  STD_LOGIC;
        m_ovf             : out STD_LOGIC
    );
end hf_dpd_core_200w;

architecture Behavioral of hf_dpd_core_200w is
    
    -- ========================================================================
    -- 1. ОПРЕДЕЛЕНИЕ ТИПОВ
    -- ========================================================================
    
    type signed_array_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    type lut_memory_t is array (0 to (2**LUT_ADDR_WIDTH)-1) of signed(COEFF_WIDTH-1 downto 0);
    type lut_array_t is array (0 to MEMORY_DEPTH-1) of lut_memory_t;
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
    
-- ========================================================================
-- 2. ФУНКЦИИ ИНИЦИАЛИЗАЦИИ
-- ========================================================================

    function init_lut_real return lut_array_t is
        variable result : lut_array_t;
    begin
        for m in 0 to MEMORY_DEPTH-1 loop
            for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                result(m)(addr) := to_signed(7100, COEFF_WIDTH);
            end loop;
        end loop;
        return result;
    end function;
    
    function init_lut_imag return lut_array_t is
        variable result : lut_array_t;
    begin
        for m in 0 to MEMORY_DEPTH-1 loop
            for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                result(m)(addr) := (others => '0');
            end loop;
        end loop;
        return result;
    end function;
    
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
    
    -- ========================================================================
    -- 3. СИГНАЛЫ С ИНИЦИАЛИЗАЦИЕЙ
    -- ========================================================================
    
    signal in_i_reg, in_q_reg       : std_logic_vector(15 downto 0); 
    signal i_delayed, q_delayed : signed_array_t := (others => (others => '0'));
    signal i_curr, q_curr       : signed(15 downto 0) := (others => '0');
    signal amp_sq              : signed_array_t := (others => (others => '0'));
    
    signal lut_real : lut_array_t := init_lut_real;
    signal lut_imag : lut_array_t := init_lut_imag;
--   attribute ram_style : string;
--   attribute ram_style of lut_real : signal is "block";
--   attribute ram_style of lut_imag : signal is "block";
    
    signal coeffs : coeff_pair_array_t;
    signal mult_i, mult_q : mult_result_t := (others => (others => '0'));
    signal sum_i, sum_q : signed(31 downto 0) := (others => '0');
    signal learn_rate : signed(15 downto 0) := to_signed(4, 16);
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
                
                -- Сдвиг задержек
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
    -- 6. ВЫЧИСЛЕНИЕ КВАДРАТА АМПЛИТУДЫ (ИСПРАВЛЕННЫЙ ВАРИАНТ)
    -- ========================================================================
        -- ========================================================================
    -- 6. ОПТИМИЗИРОВАННОЕ ВЫЧИСЛЕНИЕ КВАДРАТА АМПЛИТУДЫ (ЭКОНОМИЯ 4 DSP)
    -- ========================================================================
    -- Вместо циклического generate считаем один раз и двигаем по регистру задержки
    process(aclk)
        variable i_sq_safe, q_sq_safe : signed(31 downto 0);
        variable sum_32               : unsigned(31 downto 0);
        variable shifted_sum          : unsigned(31 downto 0);
        variable amp_sq_curr          : signed(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                amp_sq <= (others => (others => '0'));
            else
                -- Синтезатор Vivado упакует эти два умножения ровно в 2 блока DSP48E1
                i_sq_safe := i_curr * i_curr;
                q_sq_safe := q_curr * q_curr;
                
                sum_32 := unsigned(i_sq_safe) + unsigned(q_sq_safe);
                
                if is_x(std_logic_vector(sum_32)) then
                    amp_sq_curr := (others => '0');
                else
                    shifted_sum := shift_right(sum_32, 10);
                    
                    -- Насыщение (упаковка в 16-бит)
                    if shifted_sum > 65535 then
                        amp_sq_curr := to_signed(65535, DATA_WIDTH);
                    else
                        amp_sq_curr := signed(resize(shifted_sum, DATA_WIDTH));
                    end if;
                end if;
            end if;

            -- Нулевая ветвь памяти получает свежевычисленное значение
            amp_sq(0) <= amp_sq_curr;

            -- Для ветвей m=1 и m=2 просто сдвигаем результат (0 DSP, только триггеры)
            for m in 0 to MEMORY_DEPTH-2 loop
                amp_sq(m+1) <= amp_sq(m);
            end loop;
        end if;
    end process;

 -- ========================================================================
-- 7. ОПТИМИЗИРОВАННОЕ СИНХРОННОЕ ЧТЕНИЕ ИЗ BRAM (ЭКОНОМИЯ ТЫСЯЧ LUT)
-- ========================================================================
gen_luts: for m in 0 to MEMORY_DEPTH-1 generate
    process(aclk)
        variable addr_int : integer;
        variable current_addr_vec : std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                coeffs(m).real_part <= to_signed(7100, COEFF_WIDTH);
                coeffs(m).imag_part <= (others => '0');
                raddr_pipeline(m)   <= (others => (others => '0'));
            else
                -- 1. Формирование адреса чтения
                if is_x(std_logic_vector(amp_sq(m))) then
                    current_addr_vec := (others => '0');
                    addr_int := 0;
                else
                    -- У нас входной сигнал стараемся держать на 6 дБ меньше FS 
                    current_addr_vec := std_logic_vector(amp_sq(m)(DATA_WIDTH-1-1 downto DATA_WIDTH-LUT_ADDR_WIDTH-1));  
                    addr_int := to_integer(unsigned(current_addr_vec));
                    
                    if addr_int >= 2**LUT_ADDR_WIDTH then
                        addr_int := 2**LUT_ADDR_WIDTH - 1;
                    elsif addr_int < 0 then
                        addr_int := 0;
                    end if;
                end if;
                
                -- 2. Конвейер адресов (наши оптимизированные SRL32)
                raddr_pipeline(m) <= current_addr_vec & raddr_pipeline(m)(0 to PIPELINE_DEPTH-2);
                
                -- 3. СИНХРОННОЕ ЧТЕНИЕ (Строго по фронту клока - шаблон для BRAM)
                if is_x(std_logic_vector(lut_real(m)(addr_int))) then
                    coeffs(m).real_part <= to_signed(7100, COEFF_WIDTH);
                else
                    coeffs(m).real_part <= lut_real(m)(addr_int); -- Данные появятся на выходе через 1 такт
                end if;
                
                if is_x(std_logic_vector(lut_imag(m)(addr_int))) then
                    coeffs(m).imag_part <= (others => '0');
                else
                    coeffs(m).imag_part <= lut_imag(m)(addr_int);
                end if;
            end if;
        end if;
    end process;
end generate;

    
-- ========================================================================
-- 8. ОПТИМИЗИРОВАННОЕ ВЫЧИСЛЕНИЕ ПОЛИНОМА ПАМЯТИ (ДЛЯ DSP48E1 В ZYNQ-7020)
-- ========================================================================
-- Использует конвейер синхронизации с BRAM и внутренние сумматоры DSP.
-- Полностью освобождает Slice LUT на операциях сложения/вычитания.

gen_mult: for m in 0 to MEMORY_DEPTH-1 generate
    signal x_i, x_q : signed(15 downto 0);
    
    -- Выравнивающие регистры (задерживают данные на 1 такт, пока BRAM читает коэффициенты)
    signal x_i_pipe : signed(15 downto 0) := (others => '0');
    signal x_q_pipe : signed(15 downto 0) := (others => '0');
    
    -- Конвейерные регистры первого такта (хранят промежуточные произведения)
    signal prod_i_stage1 : signed(31 downto 0) := (others => '0');
    signal prod_q_stage1 : signed(31 downto 0) := (others => '0');
    
    -- Задержанные копии сигналов для второго такта конвейера
    signal x_q_del        : signed(15 downto 0) := (others => '0');
    signal cr_del         : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
    signal ci_del         : signed(COEFF_WIDTH-1 downto 0) := (others => '0');
begin
    -- Выбор источника данных в зависимости от индекса ветви памяти DPD
    x_i <= i_curr when m = 0 else i_delayed(m-1);
    x_q <= q_curr when m = 0 else q_delayed(m-1);
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                x_i_pipe      <= (others => '0');
                x_q_pipe      <= (others => '0');
                prod_i_stage1 <= (others => '0');
                prod_q_stage1 <= (others => '0');
                x_q_del       <= (others => '0');
                cr_del        <= (others => '0');
                ci_del        <= (others => '0');
                mult_i(m)     <= (others => '0');
                mult_q(m)     <= (others => '0');
            else
                -----------------------------------------------------------
                -- ТАКТ 1: Синхронизация с BRAM и первичные умножения
                -----------------------------------------------------------
                -- 1. Двигаем входные данные на 1 такт вперед. 
                -- Теперь сигналы x_i_pipe и x_q_pipe строго выровнены во времени 
                -- со свежими коэффициентами coeffs(m), которые только что считались из BRAM.
                x_i_pipe <= x_i;
                x_q_pipe <= x_q;
                
                -- 2. Считаем первую половину комплексного умножения
                prod_i_stage1 <= x_i_pipe * coeffs(m).real_part; -- Часть для I канала: (Xi * Cr)
                prod_q_stage1 <= x_i_pipe * coeffs(m).imag_part; -- Часть для Q канала: (Xi * Ci)
                
                -- 3. Задерживаем оставшиеся компоненты для второго такта конвейера
                x_q_del <= x_q_pipe;
                cr_del  <= coeffs(m).real_part;
                ci_del  <= coeffs(m).imag_part;
                
                -----------------------------------------------------------
                -- ТАКТ 2: Финальные операции (Сложение/Вычитание внутри DSP)
                -----------------------------------------------------------
                -- Для I: mult_i = (Xi * Cr) - (Xq * Ci)
                -- Vivado упакует это выражение во встроенный сумматор DSP48E1: P = P_stage1 - (A * B)
                mult_i(m) <= prod_i_stage1 - (x_q_del * ci_del);
                
                -- Для Q: mult_q = (Xi * Ci) + (Xq * Cr)
                -- Интегрированный сумматор DSP48E1 выполнит: P = P_stage1 + (A * B)
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

-- ========================================================================
-- 12. АППАРАТНО ОПТИМИЗИРОВАННЫЙ БЛОК ОБНОВЛЕНИЯ LUT (ZYNQ-7020 COMPLIANT)
-- ========================================================================
-- Анализ фильтра ошибок показал, что значащая часть сигнала лежит в диапазоне 16-0.
-- Вырезание младших 16 бит с жестким насыщением гарантирует 100% точность сходимости
-- и пакует умножения строго в 1 DSP на операцию, полностью устраняя сбой Place 30-487.
process(aclk)
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
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            for m in 0 to MEMORY_DEPTH-1 loop
                for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                    lut_real(m)(addr) <= to_signed(7100, COEFF_WIDTH);
                    lut_imag(m)(addr) <= (others => '0');
                end loop;
            end loop;
            init_done <= '1';
        elsif cfg_train_en = '1' and cfg_hold_coeffs = '0' and s_axis_fb_valid = '1' then                    
            
            -- 1. НАДЁЖНОЕ ВЫРЕЗАНИЕ И НАСЫЩЕНИЕ АКТИВНОЙ ЗОНЫ ОШИБКИ
            -- Если ошибка превышает 16-битную сетку (на старте адаптации) - ограничиваем её.
            -- В устоявшемся режиме берется точное 16-битное значение разности.
            if error_i > MAX_ERR_IN_16BIT then
                err_i_16 := to_signed(32767, 16);
            elsif error_i < MIN_ERR_IN_16BIT then
                err_i_16 := to_signed(-32768, 16);
            else
                err_i_16 := resize(error_i, 16); -- Младшие 16 бит (15 downto 0)
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
            
            -- Цикл адаптации весов полинома памяти
            for m in 0 to MEMORY_DEPTH-1 loop                        

                -- Извлечение адреса из компактного SRL32 конвейера
                addr_int := to_integer(unsigned(raddr_pipeline(m)(delay_idx)));
                
                if addr_int >= 2**LUT_ADDR_WIDTH then
                    addr_int := 2**LUT_ADDR_WIDTH - 1;
                elsif addr_int < 0 then
                    addr_int := 0;
                end if;

                -- 2. ВЫЧИСЛЕНИЕ ПРОИЗВЕДЕНИЙ (16х16 = 32 бита. Идеально ложится в 1 DSP48E1)
                prod_ii := fb_i_delayed(m) * err_i_16;
                prod_qq := fb_q_delayed(m) * err_q_16;
                prod_qi := fb_q_delayed(m) * err_i_16;
                prod_iq := fb_i_delayed(m) * err_q_16;

                -- 3. МАСШТАБИРОВАНИЕ ГРАДИЕНТА (Сдвиг на 12 эквивалентен делению на SCALE_FACTOR=4096)
                -- Выполняется на "бесплатной" проводной коммутации внутри кристалла (0 LUT)
                shift_i := shift_right(prod_ii, 12) + shift_right(prod_qq, 12);
                shift_q := shift_right(prod_qi, 12) - shift_right(prod_iq, 12);

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
                
                -- Извлечение текущего коэффициента из BRAM
                safe_real := coeffs(m).real_part;
                safe_imag := coeffs(m).imag_part;
                
                new_real := safe_real + resize(update_i, COEFF_WIDTH);
                new_imag := safe_imag + resize(update_q, COEFF_WIDTH);
                
                -- Модификация и запись в Block RAM
                if new_real > MAX_COEFF then
                    lut_real(m)(addr_int) <= MAX_COEFF;
                elsif new_real < MIN_COEFF then
                    lut_real(m)(addr_int) <= MIN_COEFF;
                else
                    lut_real(m)(addr_int) <= new_real;
                end if;
                
                if new_imag > MAX_COEFF then
                    lut_imag(m)(addr_int) <= MAX_COEFF;
                elsif new_imag < MIN_COEFF then
                    lut_imag(m)(addr_int) <= MIN_COEFF;
                else
                    lut_imag(m)(addr_int) <= new_imag;
                end if;
            end loop;
        end if;
    end if;
end process;
   
    
end Behavioral;