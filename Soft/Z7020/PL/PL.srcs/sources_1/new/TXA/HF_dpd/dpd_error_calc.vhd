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
        m_axis_err_i       : out signed(31 downto 0);
        m_axis_err_q       : out signed(31 downto 0);
        m_axis_err_valid   : out STD_LOGIC
    );
end dpd_error_calc;

architecture Behavioral of dpd_error_calc is

    -- Сигналы для мгновенной ошибки (расширяем до 32 бит для безопасности)
    signal raw_err_i       : signed(31 downto 0) := (others => '0');
    signal raw_err_q       : signed(31 downto 0) := (others => '0');
    signal raw_err_valid   : std_logic := '0';

    -- Регистры фильтра (интеграторы EMA)
    signal filter_acc_i    : signed(31 downto 0) := (others => '0');
    signal filter_acc_q    : signed(31 downto 0) := (others => '0');
    signal filter_valid    : std_logic := '0';

begin
   process(aclk)
        variable diff_i : signed(31 downto 0);
        variable diff_q : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                raw_err_i     <= (others => '0');
                raw_err_q     <= (others => '0');
                raw_err_valid <= '0';
                filter_acc_i  <= (others => '0');
                filter_acc_q  <= (others => '0');
                filter_valid  <= '0';
            else
                -- Этап 1: Синхронное вычисление мгновенной ошибки
                -- Ошибка считается только тогда, когда и опорный сигнал, и обратная связь валидны
                if (s_axis_ref_valid = '1' and s_axis_fb_valid = '1') then
                    raw_err_i     <= resize(s_axis_ref_i, 32) - resize(s_axis_fb_i, 32);
                    raw_err_q     <= resize(s_axis_ref_q, 32) - resize(s_axis_fb_q, 32);
                    raw_err_valid <= '1';
                else
                    raw_err_valid <= '0';
                end if;

                -- Этап 2: Экспоненциальный сглаживающий фильтр (EMA)
                -- Уравнение: Y(n) = Y(n-1) + (X(n) - Y(n-1)) / 2^ALPHA_SHIFT
                if raw_err_valid = '1' then
                    if cfg_train_en = '1' and cfg_hold_coeffs = '0' then
                        
                        -- Разность между новым отсчетом ошибки и текущим состоянием фильтра
                        diff_i := raw_err_i - filter_acc_i;
                        diff_q := raw_err_q - filter_acc_q;
                        
                        -- Обновление аккумулятора фильтра со сдвигом (делением на 2^ALPHA_SHIFT)
                        filter_acc_i <= filter_acc_i + shift_right(diff_i, ALPHA_SHIFT);
                        filter_acc_q <= filter_acc_q + shift_right(diff_q, ALPHA_SHIFT);
                        
                    end if;
                    -- Валидность выхода обновляется по цепочке конвейера
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
