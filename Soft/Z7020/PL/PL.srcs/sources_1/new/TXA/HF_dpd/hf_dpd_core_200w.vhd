library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

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
        cfg_train_en      : in  STD_LOGIC;
        cfg_hold_coeffs   : in  STD_LOGIC;
        cfg_bypass        : in  STD_LOGIC;
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
    
    type coeff_pair_t is record
        real_part : signed(COEFF_WIDTH-1 downto 0);
        imag_part : signed(COEFF_WIDTH-1 downto 0);
    end record;
    
    type coeff_pair_array_t is array (0 to MEMORY_DEPTH-1) of coeff_pair_t;
    type mult_result_t is array (0 to MEMORY_DEPTH-1) of signed(31 downto 0);
    type fb_delay_t is array (0 to MEMORY_DEPTH-1) of signed(15 downto 0);
    
-- ========================================================================
-- 2. ФУНКЦИИ ИНИЦИАЛИЗАЦИИ (ЕЩЕ УМЕНЬШЕННЫЕ КОЭФФИЦИЕНТЫ)
-- ========================================================================

    function init_lut_real return lut_array_t is
        variable result : lut_array_t;
    begin
        for m in 0 to MEMORY_DEPTH-1 loop
            for addr in 0 to (2**LUT_ADDR_WIDTH)-1 loop
                result(m)(addr) := to_signed(410, COEFF_WIDTH);  -- Еще уменьшено!
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
    
    -- ========================================================================
    -- 3. СИГНАЛЫ С ИНИЦИАЛИЗАЦИЕЙ
    -- ========================================================================
    
    signal i_delayed, q_delayed : signed_array_t := (others => (others => '0'));
    signal i_curr, q_curr       : signed(15 downto 0) := (others => '0');
    signal amp_sq              : signed_array_t := (others => (others => '0'));
    signal amp_sq_addr         : unsigned(LUT_ADDR_WIDTH-1 downto 0) := (others => '0');
    
    signal lut_real : lut_array_t := init_lut_real;
    signal lut_imag : lut_array_t := init_lut_imag;
    
    signal coeffs : coeff_pair_array_t;
    signal mult_i, mult_q : mult_result_t := (others => (others => '0'));
    signal sum_i, sum_q : signed(31 downto 0) := (others => '0');
    signal fb_i_delayed, fb_q_delayed : fb_delay_t := (others => (others => '0'));
    signal fb_i_curr, fb_q_curr       : signed(15 downto 0) := (others => '0');
    signal error_i, error_q : signed(31 downto 0) := (others => '0');
    signal learn_rate : signed(15 downto 0) := to_signed(8, 16);
    signal ovf_i, ovf_q : STD_LOGIC := '0';
    signal init_done : STD_LOGIC := '0';
    
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
    -- 7. ЧТЕНИЕ ИЗ LUT С ЗАЩИТОЙ
    -- ========================================================================
    gen_luts: for m in 0 to MEMORY_DEPTH-1 generate
        process(aclk)
            variable addr_int : integer;
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    coeffs(m).real_part <= to_signed(32767, COEFF_WIDTH);
                    coeffs(m).imag_part <= (others => '0');
                else
                    -- Защита от X в адресе
                    if is_x(std_logic_vector(amp_sq(m))) then
                        coeffs(m).real_part <= to_signed(32767, COEFF_WIDTH);
                        coeffs(m).imag_part <= (others => '0');
                    else
                        addr_int := to_integer(unsigned(amp_sq(m)(DATA_WIDTH-1 downto DATA_WIDTH-LUT_ADDR_WIDTH)));
                        -- Защита от выхода за пределы массива
                        if addr_int < 2**LUT_ADDR_WIDTH and addr_int >= 0 then
                            -- Защита от X в LUT
                            if is_x(std_logic_vector(lut_real(m)(addr_int))) then
                                coeffs(m).real_part <= to_signed(32767, COEFF_WIDTH);
                            else
                                coeffs(m).real_part <= lut_real(m)(addr_int);
                            end if;
                            
                            if is_x(std_logic_vector(lut_imag(m)(addr_int))) then
                                coeffs(m).imag_part <= (others => '0');
                            else
                                coeffs(m).imag_part <= lut_imag(m)(addr_int);
                            end if;
                        else
                            coeffs(m).real_part <= to_signed(32767, COEFF_WIDTH);
                            coeffs(m).imag_part <= (others => '0');
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
    variable sum_i_scaled, sum_q_scaled : signed(31 downto 0);
    begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            m_axis_iq_i <= (others => '0');
            m_axis_iq_q <= (others => '0');
        elsif cfg_bypass = '1' then
            m_axis_iq_i <= s_axis_iq_i;
            m_axis_iq_q <= s_axis_iq_q;
        else
            -- Масштабирование: делим на 4 (сдвиг вправо на 2)
            sum_i_scaled := shift_right(sum_i, 2);
            sum_q_scaled := shift_right(sum_q, 2);
            
            -- Защита от X в sum
            if is_x(std_logic_vector(sum_i_scaled)) then
                m_axis_iq_i <= (others => '0');
            elsif sum_i_scaled > to_signed(32767, 32) then
                m_axis_iq_i <= to_signed(32767, 16);
            elsif sum_i_scaled < to_signed(-32768, 32) then
                m_axis_iq_i <= to_signed(-32768, 16);
            else
                m_axis_iq_i <= sum_i_scaled(15 downto 0);
            end if;
            
            if is_x(std_logic_vector(sum_q_scaled)) then
                m_axis_iq_q <= (others => '0');
            elsif sum_q_scaled > to_signed(32767, 32) then
                m_axis_iq_q <= to_signed(32767, 16);
            elsif sum_q_scaled < to_signed(-32768, 32) then
                m_axis_iq_q <= to_signed(-32768, 16);
            else
                m_axis_iq_q <= sum_q_scaled(15 downto 0);
            end if;
        end if;
    end if;
    end process;
    
    m_ovf <= ovf_i or ovf_q;
    
    -- ========================================================================
    -- 11. БЛОК АДАПТАЦИИ
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                fb_i_curr <= (others => '0');
                fb_q_curr <= (others => '0');
                fb_i_delayed <= (others => (others => '0'));
                fb_q_delayed <= (others => (others => '0'));
            elsif s_axis_fb_valid = '1' then
                -- Защита от X на входе обратной связи
                if is_x(std_logic_vector(s_axis_fb_i)) then
                    fb_i_curr <= (others => '0');
                else
                    fb_i_curr <= s_axis_fb_i;
                end if;
                
                if is_x(std_logic_vector(s_axis_fb_q)) then
                    fb_q_curr <= (others => '0');
                else
                    fb_q_curr <= s_axis_fb_q;
                end if;
                
                for m in 0 to MEMORY_DEPTH-2 loop
                    fb_i_delayed(m+1) <= fb_i_delayed(m);
                    fb_q_delayed(m+1) <= fb_q_delayed(m);
                end loop;
                fb_i_delayed(0) <= fb_i_curr;
                fb_q_delayed(0) <= fb_q_curr;
            end if;
        end if;
    end process;
    
    -- Вычисление ошибки
    process(aclk)
    begin
        if rising_edge(aclk) then
            if cfg_train_en = '1' and cfg_hold_coeffs = '0' then
                if is_x(std_logic_vector(i_curr)) or is_x(std_logic_vector(fb_i_curr)) then
                    error_i <= (others => '0');
                else
                    error_i <= resize((i_curr - fb_i_curr), 32);
                end if;
                
                if is_x(std_logic_vector(q_curr)) or is_x(std_logic_vector(fb_q_curr)) then
                    error_q <= (others => '0');
                else
                    error_q <= resize((q_curr - fb_q_curr), 32);
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;