library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd_core_200w is
    Generic (
        MEMORY_DEPTH    : integer := 3;           -- Глубина памяти (M=0,1,2)
        LUT_ADDR_WIDTH  : integer := 8;           -- 8 бит = 256 точек в LUT
        DATA_WIDTH      : integer := 16;          -- Разрядность данных
        COEFF_WIDTH     : integer := 16           -- Разрядность коэффициентов
    );
    Port ( 
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC;
        
        -- Входной сигнал (прямой тракт)
        s_axis_iq_i       : in  signed(15 downto 0);
        s_axis_iq_q       : in  signed(15 downto 0);
        s_axis_iq_valid   : in  STD_LOGIC;
        
        -- Выходной сигнал (после линеаризации)
        m_axis_iq_i       : out signed(15 downto 0);
        m_axis_iq_q       : out signed(15 downto 0);
        m_axis_iq_valid   : out STD_LOGIC;
        m_axis_iq_ready   : in  STD_LOGIC;
        
        -- Сигнал обратной связи (с выхода PA)
        s_axis_fb_i       : in  signed(15 downto 0);
        s_axis_fb_q       : in  signed(15 downto 0);
        s_axis_fb_valid   : in  STD_LOGIC;
        
        -- Управление
        cfg_train_en      : in  STD_LOGIC;
        cfg_hold_coeffs   : in  STD_LOGIC;
        
        -- Статус
        m_ovf             : out STD_LOGIC
    );
end hf_dpd_core_200w;

architecture Behavioral of hf_dpd_core_200w is
    
    -- ========================================================================
    -- 1. ОПРЕДЕЛЕНИЕ ТИПОВ (ИСПРАВЛЕНО)
    -- ========================================================================
    
    -- Тип для массива задержек
    type signed_array_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    
    -- Тип для LUT (одномерный массив)
    type lut_memory_t is array (0 to (2**LUT_ADDR_WIDTH)-1) of signed(COEFF_WIDTH-1 downto 0);
    
    -- Тип для массива LUT (двумерный массив) - ИСПРАВЛЕНО
    type lut_array_t is array (0 to MEMORY_DEPTH-1) of lut_memory_t;
    
    -- Тип для коэффициентов
    type coeff_pair_t is record
        real_part : signed(COEFF_WIDTH-1 downto 0);
        imag_part : signed(COEFF_WIDTH-1 downto 0);
    end record;
    
    type coeff_pair_array_t is array (0 to MEMORY_DEPTH-1) of coeff_pair_t;
    
    -- Тип для результатов умножения
    type mult_result_t is array (0 to MEMORY_DEPTH-1) of signed(31 downto 0);
    
    -- Тип для задержек обратной связи
    type fb_delay_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    
    -- ========================================================================
    -- 2. СИГНАЛЫ
    -- ========================================================================
    
    -- Сигналы для задержек
    signal i_delayed, q_delayed : signed_array_t := (others => (others => '0'));
    signal i_curr, q_curr       : signed(15 downto 0);
    
    -- Квадрат амплитуды
    signal amp_sq              : signed_array_t;
    signal amp_sq_addr         : unsigned(LUT_ADDR_WIDTH-1 downto 0);
    
    -- LUT память (исправлено)
    signal lut_real, lut_imag : lut_array_t;
    
    -- Коэффициенты из LUT
    signal coeffs : coeff_pair_array_t;
    
    -- Промежуточные результаты
    signal mult_i, mult_q : mult_result_t;
    signal sum_i, sum_q : signed(31 downto 0);
    
    -- Сигналы для адаптации
    signal fb_i_delayed, fb_q_delayed : fb_delay_t;
    signal fb_i_curr, fb_q_curr       : signed(15 downto 0);
    signal fb_amp_sq                  : signed_array_t;
    
    -- Ошибка
    signal error_i, error_q : signed(31 downto 0);
    signal error_abs_sq     : signed(63 downto 0);
    
    -- Коэффициенты обновления
    signal coeff_update_en : STD_LOGIC;
    signal learn_rate      : signed(15 downto 0) := to_signed(64, 16);
    
    -- Контроль переполнения
    signal ovf_i, ovf_q : STD_LOGIC;
    
begin
    
    -- ========================================================================
    -- 3. ИНИЦИАЛИЗАЦИЯ LUT
    -- ========================================================================
    
    -- Процесс инициализации LUT начальными значениями
    init_lut_proc: process
    begin
        -- Инициализация LUT (выполняется один раз при старте симуляции)
        for m in 0 to MEMORY_DEPTH-1 loop
            for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                -- Начальные коэффициенты: реальная часть = 1.0, мнимая = 0.0
                lut_real(m)(addr) <= to_signed(32767, COEFF_WIDTH);
                lut_imag(m)(addr) <= (others => '0');
            end loop;
        end loop;
        wait; -- Останавливаем процесс после инициализации
    end process;
    
    -- ========================================================================
    -- 4. БЛОК ПРЯМОГО ТРАКТА
    -- ========================================================================
    
    -- Сдвиговый регистр для задержки сигнала
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                i_curr <= (others => '0');
                q_curr <= (others => '0');
                i_delayed <= (others => (others => '0'));
                q_delayed <= (others => (others => '0'));
            elsif s_axis_iq_valid = '1' then
                i_curr <= s_axis_iq_i;
                q_curr <= s_axis_iq_q;
                
                -- Сдвиг задержек
                for m in 0 to MEMORY_DEPTH-2 loop
                    i_delayed(m+1) <= i_delayed(m);
                    q_delayed(m+1) <= q_delayed(m);
                end loop;
                i_delayed(0) <= s_axis_iq_i;
                q_delayed(0) <= s_axis_iq_q;
            end if;
        end if;
    end process;
    
    -- Вычисление квадрата амплитуды
    gen_amp_sq: for m in 0 to MEMORY_DEPTH-1 generate
        signal i_sq, q_sq : signed(31 downto 0);
    begin
        process(aclk)
        begin
            if rising_edge(aclk) then
                if m = 0 then
                    i_sq <= i_curr * i_curr;
                    q_sq <= q_curr * q_curr;
                else
                    i_sq <= i_delayed(m-1) * i_delayed(m-1);
                    q_sq <= q_delayed(m-1) * q_delayed(m-1);
                end if;
                amp_sq(m) <= resize((i_sq + q_sq), DATA_WIDTH);
            end if;
        end process;
    end generate;
    
    -- Чтение из LUT
    gen_luts: for m in 0 to MEMORY_DEPTH-1 generate
        process(aclk)
        begin
            if rising_edge(aclk) then
                amp_sq_addr <= unsigned(amp_sq(m)(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH));
                coeffs(m).real_part <= lut_real(m)(to_integer(amp_sq_addr));
                coeffs(m).imag_part <= lut_imag(m)(to_integer(amp_sq_addr));
            end if;
        end process;
    end generate;
    
    -- Вычисление полинома памяти
    gen_mult: for m in 0 to MEMORY_DEPTH-1 generate
        signal x_i, x_q : signed(15 downto 0);
    begin
        x_i <= i_curr when m = 0 else i_delayed(m-1);
        x_q <= q_curr when m = 0 else q_delayed(m-1);
        
        process(aclk)
        begin
            if rising_edge(aclk) then
                mult_i(m) <= resize(x_i * coeffs(m).real_part - x_q * coeffs(m).imag_part, 32);
                mult_q(m) <= resize(x_i * coeffs(m).imag_part + x_q * coeffs(m).real_part, 32);
            end if;
        end process;
    end generate;
    
    -- Суммирование
    process(aclk)
        variable sum_i_var, sum_q_var : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                sum_i <= (others => '0');
                sum_q <= (others => '0');
                ovf_i <= '0';
                ovf_q <= '0';
            else
                sum_i_var := (others => '0');
                sum_q_var := (others => '0');
                
                for m in 0 to MEMORY_DEPTH-1 loop
                    sum_i_var := sum_i_var + mult_i(m);
                    sum_q_var := sum_q_var + mult_q(m);
                end loop;
                
                -- Проверка переполнения
                if sum_i_var > to_signed(32767, 32) or sum_i_var < to_signed(-32768, 32) then
                    ovf_i <= '1';
                end if;
                if sum_q_var > to_signed(32767, 32) or sum_q_var < to_signed(-32768, 32) then
                    ovf_q <= '1';
                end if;
                
                sum_i <= sum_i_var;
                sum_q <= sum_q_var;
            end if;
        end if;
    end process;
    
    -- Формирование выходного сигнала
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_axis_iq_i <= (others => '0');
                m_axis_iq_q <= (others => '0');
                m_axis_iq_valid <= '0';
            else
                if sum_i > to_signed(32767, 32) then
                    m_axis_iq_i <= to_signed(32767, 16);
                elsif sum_i < to_signed(-32768, 32) then
                    m_axis_iq_i <= to_signed(-32768, 16);
                else
                    m_axis_iq_i <= sum_i(15 downto 0);
                end if;
                
                if sum_q > to_signed(32767, 32) then
                    m_axis_iq_q <= to_signed(32767, 16);
                elsif sum_q < to_signed(-32768, 32) then
                    m_axis_iq_q <= to_signed(-32768, 16);
                else
                    m_axis_iq_q <= sum_q(15 downto 0);
                end if;
                
                m_axis_iq_valid <= s_axis_iq_valid;
            end if;
        end if;
    end process;
    
    m_ovf <= ovf_i or ovf_q;
    
    -- ========================================================================
    -- 5. БЛОК АДАПТАЦИИ
    -- ========================================================================
    
    -- Задержка сигнала обратной связи
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                fb_i_curr <= (others => '0');
                fb_q_curr <= (others => '0');
                fb_i_delayed <= (others => (others => '0'));
                fb_q_delayed <= (others => (others => '0'));
            elsif s_axis_fb_valid = '1' then
                fb_i_curr <= s_axis_fb_i;
                fb_q_curr <= s_axis_fb_q;
                
                for m in 0 to MEMORY_DEPTH-2 loop
                    fb_i_delayed(m+1) <= fb_i_delayed(m);
                    fb_q_delayed(m+1) <= fb_q_delayed(m);
                end loop;
                fb_i_delayed(0) <= s_axis_fb_i;
                fb_q_delayed(0) <= s_axis_fb_q;
            end if;
        end if;
    end process;
    
    -- Вычисление ошибки
    process(aclk)
    begin
        if rising_edge(aclk) then
            if cfg_train_en = '1' and cfg_hold_coeffs = '0' then
                error_i <= resize((signed(i_curr) - fb_i_curr), 32);
                error_q <= resize((signed(q_curr) - fb_q_curr), 32);
                error_abs_sq <= error_i * error_i + error_q * error_q;
            end if;
        end if;
    end process;
    
    -- Обновление коэффициентов LUT
    process(aclk)
        variable grad_i, grad_q : signed(31 downto 0);
        variable update_i, update_q : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                -- LUT инициализируется в отдельном процессе
                null;
            elsif cfg_train_en = '1' and cfg_hold_coeffs = '0' and s_axis_fb_valid = '1' then
                for m in 0 to MEMORY_DEPTH-1 loop
                    grad_i := resize(fb_i_delayed(m) * error_i + fb_q_delayed(m) * error_q, 32);
                    grad_q := resize(fb_q_delayed(m) * error_i - fb_i_delayed(m) * error_q, 32);
                    
                    update_i := resize((grad_i * learn_rate) / 32768, 32);
                    update_q := resize((grad_q * learn_rate) / 32768, 32);
                    
                    if coeff_update_en = '1' then
                        -- Обновление LUT (исправлено)
                        lut_real(m)(to_integer(amp_sq_addr)) <= 
                            lut_real(m)(to_integer(amp_sq_addr)) + resize(update_i, COEFF_WIDTH);
                        lut_imag(m)(to_integer(amp_sq_addr)) <= 
                            lut_imag(m)(to_integer(amp_sq_addr)) + resize(update_q, COEFF_WIDTH);
                    end if;
                end loop;
            end if;
        end if;
    end process;
    
end Behavioral;