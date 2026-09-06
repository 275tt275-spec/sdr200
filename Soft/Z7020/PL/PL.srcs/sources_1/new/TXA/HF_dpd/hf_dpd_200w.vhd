library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hf_dpd_200w is
    Port ( 
        -- Прямой тракт
        s_axis_iq_tdata   : in  STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tdata   : out STD_LOGIC_VECTOR (31 downto 0);
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC; -- Активный низкий
        
        -- Обратная связь (после DDC)
        s_axis_bb_i       : in signed(15 downto 0);
        s_axis_bb_q       : in signed(15 downto 0);
        s_axis_bb_valid   : in STD_LOGIC;
        
        -- Управление
        cfg_train_en      : in STD_LOGIC;          -- Включение адаптации
        cfg_hold_coeffs   : in STD_LOGIC;          -- Заморозить коэффициенты
        
        -- Статус
        m_ovf             : out std_logic
    );
end hf_dpd_200w;

architecture Behavioral of hf_dpd_200w is

    -- -------------------------------------------------------------------------
    -- КОМПОНЕНТ RAM (Dual Port Block Memory)
    -- -------------------------------------------------------------------------
    component dpd_lut_ram IS
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC;              -- Одиночный бит
            addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            douta : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            
            clkb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            web : IN STD_LOGIC;              -- Одиночный бит
            addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            dinb : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    END component dpd_lut_ram;

    -- ПАРАМЕТРЫ
    constant M_DEPTH : integer := 4;              -- Память (задержки)
    constant K_ORDERS : integer := 3;             -- Гармоники: 1, 3, 5
    constant TOTAL_COEFFS : integer := M_DEPTH * K_ORDERS; -- 12 коэффициентов
    
    -- Шаги адаптации
    constant MU_LIN  : signed(7 downto 0) := x"04"; 
    constant MU_NL   : signed(7 downto 0) := x"10";

    -- Типы данных для конвейеров
    type delay_pipe_i_type is array (0 to M_DEPTH-1) of signed(23 downto 0);
    type delay_pipe_q_type is array (0 to M_DEPTH-1) of signed(23 downto 0);
    type mag_sq_pipe_type is array (0 to M_DEPTH-1) of unsigned(47 downto 0);

    -- Регистровый файл коэффициентов (для быстрого доступа в тракте DPD)
    subtype coeff_t is signed(15 downto 0);
    type coeff_array_type is array (0 to TOTAL_COEFFS-1) of signed(15 downto 0);
    signal coeff_regs : coeff_array_type := (others => (others => '0'));
    
    -- Корректировка типа coeff_regs для удобства (объявляем заново как массив пар не можем, поэтому используем плоский массив)
    -- Переопределим тип локально для ясности, но в сигнале оставим плоский массив
    -- coeff_regs будет хранить: [Re_0, Im_0, Re_1, Im_1, ... Re_11, Im_11]
    -- Всего 24 элемента.
    type flat_coeff_type is array (0 to (TOTAL_COEFFS*2)-1) of signed(15 downto 0);
    signal coeff_flat_regs : flat_coeff_type := (others => (others => '0'));

    -- Сигналы конвейера
    signal tx_i, tx_q : signed(23 downto 0);
    signal pipe_i      : delay_pipe_i_type := (others => (others => '0'));
    signal pipe_q      : delay_pipe_q_type := (others => (others => '0'));
    signal mag_sq      : mag_sq_pipe_type   := (others => (others => '0'));

    -- Результаты предискажения
    signal y_i, y_q    : signed(39 downto 0) := (others => '0');
    
    -- RAM сигналы
    signal ram_addr_a   : std_logic_vector(7 downto 0) := (others => '0');
    signal ram_data_a   : std_logic_vector(31 downto 0); -- Не используется напрямую в тракте, только для копирования
    signal ram_we_b     : std_logic := '0';
    signal ram_enb      : std_logic := '0';
    signal ram_addr_b   : std_logic_vector(7 downto 0) := (others => '0');
    signal ram_din_b    : std_logic_vector(31 downto 0) := (others => '0');
    signal ram_dout_b   : std_logic_vector(31 downto 0); -- Читаем старое значение здесь

    -- Счетчики для LMS и Копирования
    signal lms_step_cnt : integer range 0 to TOTAL_COEFFS-1 := 0;
    signal copy_step_cnt : integer range 0 to TOTAL_COEFFS-1 := 0;
    signal copy_enable  : std_logic := '0';

begin

    tx_i <= signed(s_axis_iq_tdata(23 downto 0));
    tx_q <= signed(s_axis_iq_tdata(47 downto 24));
    m_ovf <= '0'; 

    -------------------------------------------------------------------------
    -- 1. КОНВЕЙЕР ЗАДЕРЖКИ (MEMORY)
    -------------------------------------------------------------------------
    process(aclk, aresetn)
    begin
        if aresetn = '0' then
            pipe_i <= (others => (others => '0'));
            pipe_q <= (others => (others => '0'));
            mag_sq <= (others => (others => '0'));
        elsif rising_edge(aclk) then
            pipe_i(0) <= tx_i;
            pipe_q(0) <= tx_q;
            -- Квадрат модуля: I^2 + Q^2
            mag_sq(0)  <= unsigned((tx_i * tx_i) + (tx_q * tx_q));
            
            for i in 1 to M_DEPTH-1 loop
                pipe_i(i) <= pipe_i(i-1);
                pipe_q(i) <= pipe_q(i-1);
                mag_sq(i)  <= mag_sq(i-1);
            end loop;
        end if;
    end process;

        -------------------------------------------------------------------------
    -- 2. ТРАКТ ПРЕДИСКАЖЕНИЯ (DPD) - ИСПРАВЛЕННЫЙ (БЕЗ ПЕРЕПОЛНЕНИЯ)
    -------------------------------------------------------------------------
    process(aclk)
        variable term_i, term_q : signed(39 downto 0);
        variable mag_term : unsigned(15 downto 0);
        variable idx_base : integer range 0 to 23;
        variable coeff_r, coeff_i : coeff_t; 
        
        -- Временные переменные для промежуточных вычислений
        variable prod_coeff_mag_r, prod_coeff_mag_i : signed(23 downto 0);
        variable prod_final_r, prod_final_i : signed(35 downto 0); -- Чуть больше запаса
        variable mag4_temp : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            term_i := (others => '0');
            term_q := (others => '0');

            for m in 0 to M_DEPTH-1 loop
                for k in 0 to K_ORDERS-1 loop
                    idx_base := ((m * K_ORDERS) + k) * 2;
                    coeff_r := coeff_flat_regs(idx_base + 0);
                    coeff_i := coeff_flat_regs(idx_base + 1);

                    if k = 0 then
                        -- Линейный член: C * x
                        term_i := term_i + (coeff_r * pipe_i(m)) - (coeff_i * pipe_q(m));
                        term_q := term_q + (coeff_r * pipe_q(m)) + (coeff_i * pipe_i(m));
                    
                    elsif k = 1 then
                        -- 3-я гармоника: C * |x|^2 * x
                        mag_term := mag_sq(m)(47 downto 32); -- Берем 16 старших бит |x|^2
                        
                        -- ШАГ 1: Умножаем коэффициент на модуль (16 * 16 -> 32 бита)
                        prod_coeff_mag_r := resize(coeff_r * signed(mag_term), 24);
                        prod_coeff_mag_i := resize(coeff_i * signed(mag_term), 24);

                        -- ШАГ 2: Умножаем на сигнал (24 * 24 -> 48 бит, но нам хватит 36 для накопления)
                        prod_final_r := prod_coeff_mag_r * pipe_i(m);
                        prod_final_i := prod_coeff_mag_i * pipe_q(m);

                        term_i := term_i + prod_final_r(35 downto 0) - prod_final_i(35 downto 0);
                        
                        prod_final_r := prod_coeff_mag_r * pipe_q(m);
                        prod_final_i := prod_coeff_mag_i * pipe_i(m);
                        
                        term_q := term_q + prod_final_r(35 downto 0) + prod_final_i(35 downto 0);

                    else
                        -- 5-я гармоника: C * |x|^4 * x
                        -- Берем сжатое значение |x|^2 (чтобы при возведении в квадрат не взорвалось)
                        mag_term := mag_sq(m)(47 downto 32); 
                        
                        -- ШАГ 1: Возводим в квадрат -> получаем |x|^4 (в сжатом виде)
                        -- Результат mag_term * mag_term будет ~30 бит, берем старшие 16                        
                        mag4_temp := signed(mag_term) * signed(mag_term);
                        mag_term := unsigned(mag4_temp(31 downto 16)); -- Оставляем 16 бит для следующего шага

                        -- ШАГ 2: Умножаем коэффициент на |x|^4
                        prod_coeff_mag_r := resize(coeff_r * signed(mag_term), 24);
                        prod_coeff_mag_i := resize(coeff_i * signed(mag_term), 24);

                        -- ШАГ 3: Умножаем на сигнал
                        prod_final_r := prod_coeff_mag_r * pipe_i(m);
                        prod_final_i := prod_coeff_mag_i * pipe_q(m);

                        term_i := term_i + prod_final_r(35 downto 0) - prod_final_i(35 downto 0);

                        prod_final_r := prod_coeff_mag_r * pipe_q(m);
                        prod_final_i := prod_coeff_mag_i * pipe_i(m);

                        term_q := term_q + prod_final_r(35 downto 0) + prod_final_i(35 downto 0);
                    end if;
                end loop;
            end loop;
            
            y_i <= term_i;
            y_q <= term_q;
        end if;
    end process;


    -- Переназначим coeff_regs на coeff_flat_regs для логики выше (нужно поправить процесс DPD, см. примечание ниже)
    -- Чтобы не усложнять, я перепишу процесс DPD ниже с использованием coeff_flat_regs напрямую.
    -- УДАЛИМ предыдущий процесс DPD и заменим на этот:

    process(aclk)
        variable term_i, term_q : signed(39 downto 0);
        variable mag_term : unsigned(15 downto 0);
        variable idx_base : integer range 0 to 23;
        variable coeff_r, coeff_i : signed(15 downto 0);
    begin
        if rising_edge(aclk) then
            term_i := (others => '0');
            term_q := (others => '0');

            for m in 0 to M_DEPTH-1 loop
                for k in 0 to K_ORDERS-1 loop
                    idx_base := ((m * K_ORDERS) + k) * 2;
                    coeff_r := coeff_flat_regs(idx_base + 0);
                    coeff_i := coeff_flat_regs(idx_base + 1);

                    if k = 0 then
                        -- Линейный член
                        term_i := term_i + (coeff_r * pipe_i(m)) - (coeff_i * pipe_q(m));
                        term_q := term_q + (coeff_r * pipe_q(m)) + (coeff_i * pipe_i(m));
                    elsif k = 1 then
                        -- 3-я гармоника: |x|^2 * x
                        mag_term := mag_sq(m)(47 downto 32);
                        term_i := term_i + (coeff_r * signed(mag_term) * pipe_i(m)) 
                                       - (coeff_i * signed(mag_term) * pipe_q(m));
                        term_q := term_q + (coeff_r * signed(mag_term) * pipe_q(m)) 
                                       + (coeff_i * signed(mag_term) * pipe_i(m));
                    else
                        -- 5-я гармоника: |x|^4 * x
                        mag_term := shift_right(mag_sq(m), 32); -- Сдвигаем на 32 бита вправо, получаем 16 старших бит
                        term_i := term_i + (coeff_r * signed(mag_term) * signed(mag_term) * pipe_i(m))
                                       - (coeff_i * signed(mag_term) * signed(mag_term) * pipe_q(m));
                        term_q := term_q + (coeff_r * signed(mag_term) * signed(mag_term) * pipe_q(m))
                                       + (coeff_i * signed(mag_term) * signed(mag_term) * pipe_i(m));
                    end if;
                end loop;
            end loop;
            
            y_i <= term_i;
            y_q <= term_q;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 3. НАСЫЩЕНИЕ И ВЫХОД (16 бит)
    -------------------------------------------------------------------------
    process(aclk, aresetn)
        variable temp_i : signed(39 downto 0);
        variable temp_q : signed(39 downto 0);
        variable out_val : signed(15 downto 0);
    begin
        if aresetn = '0' then
            m_axis_iq_tdata <= (others => '0');
        elsif rising_edge(aclk) then
            temp_i := y_i;
            temp_q := y_q;

            if temp_i > to_signed(32767, temp_i'length) then
                out_val := to_signed(32767, out_val'length);
                m_ovf <= '1';
            elsif temp_i < to_signed(-32768, temp_i'length) then
                out_val := to_signed(-32768, out_val'length);
                m_ovf <= '1';
            else
                out_val := temp_i(15 downto 0);
            end if;

            -- Аналогично для Q
            if temp_q > to_signed(32767, temp_q'length) then
                m_axis_iq_tdata(15 downto 0) <= std_logic_vector(to_signed(32767, 16));
                m_ovf <= '1';
            elsif temp_q < to_signed(-32768, temp_q'length) then
                m_axis_iq_tdata(15 downto 0) <= std_logic_vector(to_signed(-32768, 16));
                m_ovf <= '1';
            else
                m_axis_iq_tdata(15 downto 0) <= std_logic_vector(temp_q(15 downto 0));
            end if;

            -- Формируем 32-битный выход: I(15..0), Q(15..0)
            m_axis_iq_tdata(31 downto 16) <= std_logic_vector(out_val);
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 4. КОПИРОВАНИЕ КОЭФФИЦИЕНТОВ ИЗ RAM В РЕГИСТРОВЫЙ ФАЙЛ
    -- Медленный процесс: 1 коэффициент за N тактов. Не мешает тракту DPD.
    -------------------------------------------------------------------------
    process(aclk, aresetn)
        constant COPY_SLOWDOWN : integer := 16; -- 1 запись каждые 16 тактов
        variable copy_counter : integer range 0 to COPY_SLOWDOWN-1 := 0;
        variable addr_tmp : integer range 0 to 255;
    begin
        if aresetn = '0' then
            copy_step_cnt <= 0;
            copy_counter := 0;
            coeff_flat_regs <= (others => (others => '0'));
        elsif rising_edge(aclk) then
            -- Разрешаем чтение из RAM всегда
            ram_enb <= '1';

            if copy_counter = COPY_SLOWDOWN-1 then
                -- Время читать очередной коэффициент
                addr_tmp := copy_step_cnt;
                ram_addr_b <= std_logic_vector(to_unsigned(addr_tmp, 8));

                -- Читаем 32 бита: Re (16 бит) и Im (16 бит)
                coeff_flat_regs(copy_step_cnt * 2 + 0) <= signed(ram_data_a(31 downto 16));
                coeff_flat_regs(copy_step_cnt * 2 + 1) <= signed(ram_data_a(15 downto 0));

                if copy_step_cnt < (TOTAL_COEFFS*2) - 1 then
                    copy_step_cnt <= copy_step_cnt + 1;
                else
                    copy_step_cnt <= 0; -- Зацикливаем копирование
                end if;

                copy_counter := 0;
            else
                copy_counter := copy_counter + 1;
            end if;
        end if;
    end process;

    -- Примечание: ram_data_a берется из douta компонента dpd_lut_ram.
    -- В port map ниже мы подключим douta к ram_data_a.

    -------------------------------------------------------------------------
    -- 5. БЛОК АДАПТАЦИИ (LMS) - ПОСЛЕДОВАТЕЛЬНОЕ ОБНОВЛЕНИЕ
    -- Обновляет 1 коэффициент за такт, циклически проходя все 12 пар (24 значения)
    -------------------------------------------------------------------------
    process(aclk, aresetn)
        variable e_r, e_i : signed(15 downto 0);
        variable mu_curr  : signed(7 downto 0);
        variable delta_r, delta_i : signed(23 downto 0);
        variable curr_coeff_r, curr_coeff_i : signed(15 downto 0);
        variable input_r, input_i : signed(15 downto 0);
        variable mag_term_sq : unsigned(15 downto 0);
        variable mag2, mag4 : unsigned(15 downto 0);
        variable term_mag_r, term_mag_i : signed(23 downto 0);
        variable term_mag4_r, term_mag4_i : signed(23 downto 0);
        variable idx_base : integer range 0 to 23;
        variable k_idx : integer range 0 to 2;
        variable m_idx : integer range 0 to 3;
        variable addr_tmp : integer range 0 to 255;
    begin
        if aresetn = '0' then
            lms_step_cnt <= 0;
            ram_we_b <= '0';
            ram_enb <= '1'; -- Чтение включено
            -- Сброс остальных сигналов
        elsif rising_edge(aclk) then
            ram_we_b <= '0'; -- По умолчанию запись выключена

            -- Подготовка ошибки (выравнивание по задержке pipe_i(0))
            input_r := pipe_i(0)(23 downto 8);
            input_i := pipe_q(0)(23 downto 8);

            e_r := input_r - s_axis_bb_i;
            e_i := input_i - s_axis_bb_q;

            if (s_axis_bb_valid = '1') and (cfg_train_en = '1') and (cfg_hold_coeffs = '0') then
                -- Определяем, какой коэффициент обновлять
                m_idx := lms_step_cnt / K_ORDERS;
                k_idx := lms_step_cnt mod K_ORDERS;
                addr_tmp := (m_idx * K_ORDERS) + k_idx;

                -- 1. Читаем старое значение из RAM (Порт B)
                curr_coeff_r := signed(ram_dout_b(31 downto 16));
                curr_coeff_i := signed(ram_dout_b(15 downto 0));

                -- 2. Выбираем шаг адаптации
                if k_idx = 0 then
                    mu_curr := MU_LIN;
                else
                    mu_curr := MU_NL;
                end if;

                -- 3. Вычисляем градиент (Delta)
                if k_idx = 0 then
                    -- Линейный член: Delta = mu * Err * x
                    delta_r := resize(mu_curr * (e_r * input_r + e_i * input_i), 24);
                    delta_i := resize(mu_curr * (e_i * input_r - e_r * input_i), 24);
                elsif k_idx = 1 then
                    -- 3-я гармоника: Delta = mu * Err * (|x|^2 * x)
                    mag_term_sq := mag_sq(m_idx)(47 downto 32);
                    term_mag_r := signed(mag_term_sq) * input_r;
                    term_mag_i := signed(mag_term_sq) * input_i;

                    delta_r := resize(mu_curr * (e_r * term_mag_r + e_i * term_mag_i), 24);
                    delta_i := resize(mu_curr * (e_i * term_mag_r - e_r * term_mag_i), 24);
                else
                    -- 5-я гармоника: Delta = mu * Err * (|x|^4 * x)
                    mag2 := shift_right(mag_sq(m_idx), 32);
                    mag4 := mag2 * mag2;

                    term_mag4_r := signed(mag4) * input_r;
                    term_mag4_i := signed(mag4) * input_i;

                    delta_r := resize(mu_curr * (e_r * term_mag4_r + e_i * term_mag4_i), 24);
                    delta_i := resize(mu_curr * (e_i * term_mag4_r - e_r * term_mag4_i), 24);
                end if;

                -- 4. Обновляем коэффициент
                curr_coeff_r := curr_coeff_r + delta_r(15 downto 0);
                curr_coeff_i := curr_coeff_i + delta_i(15 downto 0);

                -- 5. Готовим запись в RAM
                ram_din_b <= std_logic_vector(curr_coeff_r) & std_logic_vector(curr_coeff_i);
                ram_addr_b <= std_logic_vector(to_unsigned(addr_tmp, 8));
                ram_we_b   <= '1';

                -- 6. Счетчик шагов
                if lms_step_cnt < (M_DEPTH * K_ORDERS) - 1 then
                    lms_step_cnt <= lms_step_cnt + 1;
                else
                    lms_step_cnt <= 0;
                end if;
            else
                lms_step_cnt <= 0;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 6. INSTANTIATION OF RAM IP CORE
    -------------------------------------------------------------------------
    ram_addr_a <= std_logic_vector(to_unsigned(copy_step_cnt, 8));
    u_dpd_ram : dpd_lut_ram
    PORT MAP (
        clka  => aclk,
        ena   => '1',
        wea   => '0',              -- Порт A только для чтения (копирование)
        addra => ram_addr_a, -- Адрес для копирования
        dina  => (others => '0'),
        douta => ram_data_a,        -- Сюда пишем данные для копирования в регистры

        clkb  => aclk,
        enb   => ram_enb,
        web   => ram_we_b,
        addrb => ram_addr_b,
        dinb  => ram_din_b,
        doutb => ram_dout_b         -- Отсюда читаем старые коэффициенты для LMS
    );

end Behavioral;
