library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_dpd_align_and_error is
-- Тестбенч не имеет внешних портов
end tb_dpd_align_and_error;

architecture Behavioral of tb_dpd_align_and_error is

    -- Константы симуляции
    constant CLK_PERIOD : time := 8.138 ns; -- ~122.88 МГц (типичная частота для SDR)
    constant DATA_WIDTH : integer := 16;
    constant ADDR_WIDTH : integer := 8;
    constant ALPHA_SHIFT : integer := 4;   -- Сделаем фильтр быстрее (1/16) для симуляции

    -- Сигналы генератора тактов и сброса
    signal clk             : std_logic := '0';
    signal rst_n           : std_logic := '0';

    -- Сигналы управления
    signal cfg_delay_ticks : std_logic_vector(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal cfg_train_en    : std_logic := '1';
    signal cfg_hold_coeffs : std_logic := '0';

    -- Интерфейс TX (Ref)
    signal tx_data_i       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal tx_data_q       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal tx_valid        : std_logic := '0';

    -- Интерфейс FB (Обратная связь)
    signal fb_data_i       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal fb_data_q       : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal fb_valid        : std_logic := '0';

    -- Выходы модуля
    signal m_err_i         : signed(31 downto 0);
    signal m_err_q         : signed(31 downto 0);
    signal m_err_valid     : std_logic;

    -- Эмуляция аналоговой задержки тракта (например, 12 тактов)
    type delay_line_t is array (0 to 11) of signed(DATA_WIDTH-1 downto 0);
    signal fb_sim_delay_i  : delay_line_t := (others => (others => '0'));
    signal fb_sim_delay_q  : delay_line_t := (others => (others => '0'));
    signal fb_sim_valid    : std_logic_vector(0 to 11) := (others => '0');

begin

    -- 1. Тактовый генератор
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 2. Генератор тестового DDS (Синусоидальный сигнал для TX)
    tx_signal_gen : process(clk)
        variable sample_cnt : integer := 0;
        variable angle      : real;
        variable s_i, s_q   : integer;
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                sample_cnt := 0;
                tx_data_i  <= (others => '0');
                tx_data_q  <= (others => '0');
                tx_valid   <= '0';
            else
                tx_valid   <= '1';
                -- Генерируем частоту f = Частота_Клока / 32
                angle := 2.0 * MATH_PI * real(sample_cnt) / 32.0;
                
                -- Амплитуда 20000 (в рамках 16-битного signed)
                s_i := integer(20000.0 * cos(angle));
                s_q := integer(20000.0 * sin(angle));
                
                tx_data_i <= std_logic_vector(to_signed(s_i, DATA_WIDTH));
                tx_data_q <= std_logic_vector(to_signed(s_q, DATA_WIDTH));
                
                sample_cnt := sample_cnt + 1;
            end if;
        end if;
    end process;

    -- 3. Эмулятор аппаратной задержки радио-тракта (Задержка TX -> FB на 12 тактов)
    -- Добавим также небольшое искажение (ослабление амплитуды и DC-offset)
    fb_hardware_emulator : process(clk)
    begin
        if rising_edge(clk) then
            if rst_n = '0' then
                fb_sim_delay_i <= (others => (others => '0'));
                fb_sim_delay_q <= (others => (others => '0'));
                fb_sim_valid   <= (others => '0');
            else
                -- Сдвиговый регистр для эмуляции физической дистанции / фильтров
                fb_sim_delay_i(0) <= signed(tx_data_i);
                fb_sim_delay_q(0) <= signed(tx_data_q);
                fb_sim_valid(0)   <= tx_valid;
                
                for k in 1 to 11 loop
                    fb_sim_delay_i(k) <= fb_sim_delay_i(k-1);
                    fb_sim_delay_q(k) <= fb_sim_delay_q(k-1);
                    fb_sim_valid(k)   <= fb_sim_valid(k-1);
                end loop;
            end if;
        end if;
    end process;

    -- Имитируем сигнал, пришедший с АЦП (ослаблен на 500 единиц + смещение постоянного тока +50)
    fb_data_i <= std_logic_vector(fb_sim_delay_i(11) - 500 + 50) when fb_sim_valid(11) = '1' else (others => '0');
    fb_data_q <= std_logic_vector(fb_sim_delay_q(11) - 500)      when fb_sim_valid(11) = '1' else (others => '0');
    fb_valid <= fb_sim_valid(11);

UUT_BLOCK : entity work.dpd_align_and_error_top
    GENERIC
    MAP (
        DATA_WIDTH  => 16,
        ADDR_WIDTH  => 8,
        ALPHA_SHIFT => 4
    )
    PORT
    MAP (
        aclk                 => clk,
        aresetn              => rst_n,
        cfg_delay_ticks      => cfg_delay_ticks,
        cfg_train_en         => cfg_train_en,
        cfg_hold_coeffs      => cfg_hold_coeffs,
        s_axis_ref_tdata_i   => tx_data_i,
        s_axis_ref_tdata_q   => tx_data_q,
        s_axis_ref_tvalid    => tx_valid,
        s_axis_fb_tdata_i    => fb_data_i,
        s_axis_fb_tdata_q    => fb_data_q,
        s_axis_fb_tvalid     => fb_valid,
        m_axis_err_i         => m_err_i,
        m_axis_err_q         => m_err_q,
        m_axis_err_valid     => m_err_valid
    );

    -- 5. Сценарий тестирования (Stimulus)
    stimulus_process : process
    begin
        -- Сброс системы
        rst_n <= '0';
        cfg_delay_ticks <= std_logic_vector(to_unsigned(0, ADDR_WIDTH));
        wait for 100 ns;
        rst_n <= '1';
        
        -- ШАГ 1: Задержка в модуле равна 0, но реальный тракт задерживает на 12 тактов.
        -- Наблюдаем в симуляторе огромную ошибку (m_err_i / q), так как сигналы рассинхронизированы.
        wait for 2 us;
        
        -- ШАГ 2: Выравниваем задержку. Выставляем cfg_delay_ticks = 12 тактов.
        -- Сигналы внутри модуля совместятся. Ошибка резко упадет.
        -- Фильтр начнет сходиться к чистому математическому значению искажения (500 + DC смещение).
        cfg_delay_ticks <= std_logic_vector(to_unsigned(12, ADDR_WIDTH));
        wait for 3 us;
        
        -- ШАГ 3: Замораживаем коэффициенты обучения
        cfg_hold_coeffs <= '1';
        wait for 1 us;
        
        -- Завершение симуляции
        assert false report "Симуляция успешно завершена!" severity failure;
        wait;
    end process;

end Behavioral;
