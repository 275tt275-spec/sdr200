library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

use std.textio.all;
use ieee.std_logic_textio.all;

entity hf_dpd_core_200w is
    Generic (
        MEMORY_DEPTH    : integer := 3;
        LUT_ADDR_WIDTH  : integer := 8;
        DATA_WIDTH      : integer := 16;
        COEFF_WIDTH     : integer := 16
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
        cfg_delay_ticks   : in  std_logic_vector(7 downto 0);
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
    
-- ========================================================================
-- 2. ФУНКЦИИ ИНИЦИАЛИЗАЦИИ (ЕЩЕ УМЕНЬШЕННЫЕ КОЭФФИЦИЕНТЫ)
-- ========================================================================

    function init_lut_real return lut_array_t is
        variable result : lut_array_t;
    begin
        for m in 0 to MEMORY_DEPTH-1 loop
            for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                result(m)(addr) := to_signed(410, COEFF_WIDTH);  -- Было 410! Уменьшили в 10 раз
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
        cfg_delay_ticks      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
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
    signal amp_sq_addr         : unsigned(LUT_ADDR_WIDTH-1 downto 0) := (others => '0');
    
    signal lut_real : lut_array_t := init_lut_real;
    signal lut_imag : lut_array_t := init_lut_imag;
    
    signal coeffs : coeff_pair_array_t;
    signal mult_i, mult_q : mult_result_t := (others => (others => '0'));
    signal sum_i, sum_q : signed(31 downto 0) := (others => '0');
    signal learn_rate : signed(15 downto 0) := to_signed(32, 16);
    signal ovf_i, ovf_q : STD_LOGIC := '0';
    signal init_done : STD_LOGIC := '0';
    signal fb_i_delayed, fb_q_delayed : fb_delay_t := (others => (others => '0'));
    
begin
    
    -- ========================================================================
    -- 4. ИНИЦИАЛИЗАЦИЯ ПРИ СБРОСЕ
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                for m in 0 to MEMORY_DEPTH-1 loop
                    for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                        lut_real(m)(addr) <= to_signed(410, COEFF_WIDTH);  -- Еще уменьшено!
                        lut_imag(m)(addr) <= (others => '0');
                    end loop;
                end loop;
                init_done <= '1';
            end if;
        end if;
    end process;
    
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
                -- Защита от X на входе + масштабирование (деление на 4)
                if is_x(std_logic_vector(s_axis_iq_i)) then
                    i_curr <= (others => '0');
                else
                    i_curr <= resize(shift_right(s_axis_iq_i, 2), 16);  -- Деление на 4
                end if;
                
                if is_x(std_logic_vector(s_axis_iq_q)) then
                    q_curr <= (others => '0');
                else
                    q_curr <= resize(shift_right(s_axis_iq_q, 2), 16);  -- Деление на 4
                end if;
                
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
    -- 6. ВЫЧИСЛЕНИЕ КВАДРАТА АМПЛИТУДЫ
    -- ========================================================================
    gen_amp_sq: for m in 0 to MEMORY_DEPTH-1 generate
        signal i_sq, q_sq : signed(31 downto 0);
        signal x_i, x_q : signed(15 downto 0);
    begin
        x_i <= i_curr when m = 0 else i_delayed(m-1);
        x_q <= q_curr when m = 0 else q_delayed(m-1);
        
        process(aclk)
            variable i_sq_safe, q_sq_safe : signed(31 downto 0);
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    amp_sq(m) <= (others => '0');
                else
                    -- Защита от X
                    if is_x(std_logic_vector(x_i)) or is_x(std_logic_vector(x_q)) then
                        amp_sq(m) <= (others => '0');
                    else
                        i_sq_safe := x_i * x_i;
                        q_sq_safe := x_q * x_q;
                        if is_x(std_logic_vector(i_sq_safe + q_sq_safe)) then
                            amp_sq(m) <= (others => '0');
                        else
                            amp_sq(m) <= resize((i_sq_safe + q_sq_safe), DATA_WIDTH);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;
    
   -- ========================================================================
    -- 7. ЧТЕНИЕ ИЗ LUT С ПРАВИЛЬНОЙ АДРЕСАЦИЕЙ
    -- ========================================================================
    gen_luts: for m in 0 to MEMORY_DEPTH-1 generate
        process(aclk)
            variable addr_int : integer;
            variable amp_val : unsigned(15 downto 0);
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    coeffs(m).real_part <= to_signed(410, COEFF_WIDTH);
                    coeffs(m).imag_part <= (others => '0');
                else
                    -- Защита от X в адресе
                    if is_x(std_logic_vector(amp_sq(m))) then
                        coeffs(m).real_part <= to_signed(410, COEFF_WIDTH);
                        coeffs(m).imag_part <= (others => '0');
                    else
                        -- ========================================================
                        -- ПРАВИЛЬНОЕ ФОРМИРОВАНИЕ АДРЕСА
                        -- ========================================================
                        -- Берем старшие LUT_ADDR_WIDTH бит
                        addr_int := to_integer(unsigned(amp_sq(m)(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH)));
                        
                        -- ЗАЩИТА ОТ ВЫХОДА ЗА ПРЕДЕЛЫ МАССИВА
                        if addr_int >= 2**LUT_ADDR_WIDTH then
                            addr_int := 2**LUT_ADDR_WIDTH - 1;  -- Насыщение адреса
                        elsif addr_int < 0 then
                            addr_int := 0;
                        end if;
                        
                        -- Защита от X в LUT
                        if is_x(std_logic_vector(lut_real(m)(addr_int))) then
                            coeffs(m).real_part <= to_signed(410, COEFF_WIDTH);
                        else
                            coeffs(m).real_part <= lut_real(m)(addr_int);
                        end if;
                        
                        if is_x(std_logic_vector(lut_imag(m)(addr_int))) then
                            coeffs(m).imag_part <= (others => '0');
                        else
                            coeffs(m).imag_part <= lut_imag(m)(addr_int);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;
    
    -- ========================================================================
    -- 8. ВЫЧИСЛЕНИЕ ПОЛИНОМА ПАМЯТИ С ЗАЩИТОЙ ОТ X
    -- ========================================================================
    gen_mult: for m in 0 to MEMORY_DEPTH-1 generate
        signal x_i, x_q : signed(15 downto 0);
    begin
        x_i <= i_curr when m = 0 else i_delayed(m-1);
        x_q <= q_curr when m = 0 else q_delayed(m-1);
        
        process(aclk)
            variable mult_i_var, mult_q_var : signed(31 downto 0);
            variable x_i_safe, x_q_safe : signed(15 downto 0);
            variable cr_safe, ci_safe : signed(COEFF_WIDTH-1 downto 0);
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    mult_i(m) <= (others => '0');
                    mult_q(m) <= (others => '0');
                else
                    -- Защита входных данных от X
                    if is_x(std_logic_vector(x_i)) then
                        x_i_safe := (others => '0');
                    else
                        x_i_safe := x_i;
                    end if;
                    
                    if is_x(std_logic_vector(x_q)) then
                        x_q_safe := (others => '0');
                    else
                        x_q_safe := x_q;
                    end if;
                    
                    -- Защита коэффициентов от X
                    if is_x(std_logic_vector(coeffs(m).real_part)) then
                        cr_safe := to_signed(32767, COEFF_WIDTH);
                    else
                        cr_safe := coeffs(m).real_part;
                    end if;
                    
                    if is_x(std_logic_vector(coeffs(m).imag_part)) then
                        ci_safe := (others => '0');
                    else
                        ci_safe := coeffs(m).imag_part;
                    end if;
                    
                    -- Вычисление с защитой от переполнения
                    -- I = x_i * cr - x_q * ci
                    mult_i_var := resize(x_i_safe * cr_safe - x_q_safe * ci_safe, 32);
                    
                    -- Q = x_i * ci + x_q * cr
                    mult_q_var := resize(x_i_safe * ci_safe + x_q_safe * cr_safe, 32);
                    
                    -- Проверка результата на X
                    if is_x(std_logic_vector(mult_i_var)) then
                        mult_i(m) <= (others => '0');
                    else
                        mult_i(m) <= mult_i_var;
                    end if;
                    
                    if is_x(std_logic_vector(mult_q_var)) then
                        mult_q(m) <= (others => '0');
                    else
                        mult_q(m) <= mult_q_var;
                    end if;
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
                    -- Защита от X в mult
                    if is_x(std_logic_vector(mult_i(m))) then
                        temp_i := temp_i;
                    else
                        temp_i := temp_i + resize(mult_i(m), 64);
                    end if;
                    
                    if is_x(std_logic_vector(mult_q(m))) then
                        temp_q := temp_q;
                    else
                        temp_q := temp_q + resize(mult_q(m), 64);
                    end if;
                end loop;
                
                -- Насыщение для I
                if temp_i > MAX_32BIT then
                    sum_i <= to_signed(2147483647, 32);
                    ovf_i <= '1';
                elsif temp_i < MIN_32BIT then
                    sum_i <= to_signed(-2147483648, 32);
                    ovf_i <= '1';
                else
                    if is_x(std_logic_vector(resize(temp_i, 32))) then
                        sum_i <= (others => '0');
                    else
                        sum_i <= resize(temp_i, 32);
                    end if;
                end if;
                
                -- Насыщение для Q
                if temp_q > MAX_32BIT then
                    sum_q <= to_signed(2147483647, 32);
                    ovf_q <= '1';
                elsif temp_q < MIN_32BIT then
                    sum_q <= to_signed(-2147483648, 32);
                    ovf_q <= '1';
                else
                    if is_x(std_logic_vector(resize(temp_q, 32))) then
                        sum_q <= (others => '0');
                    else
                        sum_q <= resize(temp_q, 32);
                    end if;
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
        constant SHIFT : integer := 9;
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
-- 12. БЛОК ОБНОВЛЕНИЯ LUT (С ФИЛЬТРОВАННОЙ ОШИБКОЙ)
-- ========================================================================
    process(aclk)
        variable grad_i, grad_q : signed(31 downto 0);
        variable update_i, update_q : signed(31 downto 0);
        variable new_real, new_imag : signed(COEFF_WIDTH-1 downto 0);
        variable addr_int : integer;
        variable safe_real, safe_imag : signed(COEFF_WIDTH-1 downto 0);
        variable err_i_safe, err_q_safe : signed(31 downto 0);
        
        constant MAX_COEFF : signed(COEFF_WIDTH-1 downto 0) := to_signed(32767, COEFF_WIDTH);
        constant MIN_COEFF : signed(COEFF_WIDTH-1 downto 0) := to_signed(-32768, COEFF_WIDTH);
        constant MAX_UPDATE : signed(31 downto 0) := to_signed(640, 32);
        constant MAX_GRAD : signed(31 downto 0) := to_signed(32768, 32);  -- Было 131072
        constant MAX_ERROR  : signed(31 downto 0) := to_signed(131072, 32);
        constant SCALE_FACTOR : integer := 256;  -- Было 4096
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                null;
            elsif cfg_train_en = '1' and cfg_hold_coeffs = '0' and s_axis_fb_valid = '1' then
                if not is_x(std_logic_vector(amp_sq(0))) and
                   not is_x(std_logic_vector(error_i)) and  -- Используем фильтрованную!
                   not is_x(std_logic_vector(error_q)) then
                    
                    -- ================================================================
                    -- ОГРАНИЧЕНИЕ ФИЛЬТРОВАННОЙ ОШИБКИ
                    -- ================================================================
                    if error_i > MAX_ERROR then
                        err_i_safe := MAX_ERROR;
                    elsif error_i < -MAX_ERROR then
                        err_i_safe := -MAX_ERROR;
                    else
                        err_i_safe := error_i;
                    end if;
                    
                    if error_q > MAX_ERROR then
                        err_q_safe := MAX_ERROR;
                    elsif error_q< -MAX_ERROR then
                        err_q_safe := -MAX_ERROR;
                    else
                        err_q_safe := error_q;
                    end if;
                    
                    for m in 0 to MEMORY_DEPTH-1 loop
                        if not is_x(std_logic_vector(fb_i_delayed(m))) and 
                           not is_x(std_logic_vector(fb_q_delayed(m))) then
                           
                            -- Вычисляем адрес индивидуально для каждой ветви памяти!
                            addr_int := to_integer(unsigned(amp_sq(m)(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH)));
                            
                            -- Защита от выхода за границы для текущего addr_int
                            if addr_int >= 2**LUT_ADDR_WIDTH then
                                addr_int := 2**LUT_ADDR_WIDTH - 1;
                            elsif addr_int < 0 then
                                addr_int := 0;
                            end if;

                            -- ВЫЧИСЛЕНИЕ ГРАДИЕНТА (используем фильтрованную ошибку)
                            grad_i := resize((fb_i_delayed(m) * err_i_safe) / SCALE_FACTOR + 
                                             (fb_q_delayed(m) * err_q_safe) / SCALE_FACTOR, 32);
                            
                            grad_q := resize((fb_q_delayed(m) * err_i_safe) / SCALE_FACTOR - 
                                             (fb_i_delayed(m) * err_q_safe) / SCALE_FACTOR, 32);
                                                        
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
                            
                            -- Обновление
                            update_i := resize((grad_i * learn_rate) / 32768, 32);
                            update_q := resize((grad_q * learn_rate) / 32768, 32);
                            
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
                            
                            -- Чтение из LUT с защитой
                            if is_x(std_logic_vector(lut_real(m)(addr_int))) then
                                safe_real := to_signed(410, COEFF_WIDTH);
                            else
                                safe_real := lut_real(m)(addr_int);
                            end if;
                            
                            if is_x(std_logic_vector(lut_imag(m)(addr_int))) then
                                safe_imag := to_signed(0, COEFF_WIDTH);
                            else
                                safe_imag := lut_imag(m)(addr_int);
                            end if;
                            
                            -- Обновление
                            new_real := safe_real + resize(update_i, COEFF_WIDTH);
                            new_imag := safe_imag + resize(update_q, COEFF_WIDTH);
                            
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
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;    

-- ========================================================================
-- ЗАПИСЬ ОТЛАДОЧНЫХ ДАННЫХ В ФАЙЛ (С ПРАВИЛЬНЫМ ОБЪЯВЛЕНИЕМ)
-- ========================================================================
process(aclk)
    file log_file : text open write_mode is "debug_data.csv";
    variable line_out : line;
    variable time_ns : integer;
    variable dbg_addr : integer;  -- <-- ОБЪЯВЛЯЕМ ПЕРЕМЕННУЮ ЗДЕСЬ!
begin
    if rising_edge(aclk) then
        if aresetn = '1' then
            -- Время в наносекундах
            time_ns := (now / 1 ns);
            write(line_out, time_ns);
            write(line_out, string'(";"));
            
            -- sum_i и sum_q
            write(line_out, to_integer(sum_i));
            write(line_out, string'(";"));
            write(line_out, to_integer(sum_q));
            write(line_out, string'(";"));
            
            -- error_i и error_q
            write(line_out, to_integer(error_i));
            write(line_out, string'(";"));
            write(line_out, to_integer(error_q));
            write(line_out, string'(";"));
            
            -- Коэффициенты LUT для адреса 0
            write(line_out, to_integer(lut_real(0)(0)));
            write(line_out, string'(";"));
            write(line_out, to_integer(lut_imag(0)(0)));
            write(line_out, string'(";"));
            
            -- ТЕПЕРЬ МОЖНО ИСПОЛЬЗОВАТЬ addr_int
            -- Вычисляем адрес
            if not is_x(std_logic_vector(amp_sq(0))) then
                dbg_addr := to_integer(unsigned(amp_sq(0)(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH)));
                if dbg_addr >= 2**LUT_ADDR_WIDTH then
                    dbg_addr := 2**LUT_ADDR_WIDTH - 1;
                end if;
            else
                dbg_addr := 0;
            end if;
            
            write(line_out, dbg_addr);
            write(line_out, string'(";"));
            
            -- Значение LUT по текущему адресу
            if dbg_addr < 2**LUT_ADDR_WIDTH and dbg_addr >= 0 then
                write(line_out, to_integer(lut_real(0)(dbg_addr)));
                write(line_out, string'(";"));
                write(line_out, to_integer(lut_imag(0)(dbg_addr)));
            else
                write(line_out, 0);
                write(line_out, string'(";"));
                write(line_out, 0);
            end if;
            write(line_out, string'(";"));
            
            -- Флаги
            write(line_out, ovf_i);
            write(line_out, string'(";"));
            write(line_out, ovf_q);
            
            -- Флаги условий
            write(line_out, string'(";"));
            write(line_out, cfg_train_en);
            write(line_out, string'(";"));
            write(line_out, cfg_hold_coeffs);
            write(line_out, string'(";"));
            write(line_out, s_axis_fb_valid);            
            
            writeline(log_file, line_out);
        end if;
    end if;
end process;
    
end Behavioral;