library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity signed_round_sat is
    generic (
        IWID       : integer := 37; -- Исходная разрядность данных
        OWID       : integer := 24; -- Выходная разрядность после округления
        SHIFT_LEFT : integer := 0   -- Параметр сдвига данных вверх перед округлением (0, 1, 2...)
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;
        i_data  : in  std_logic_vector(IWID-1 downto 0);
        i_valid : in  std_logic;
        o_data  : out std_logic_vector(OWID-1 downto 0);
        o_valid : out std_logic;
        ovf     : out std_logic -- Флаг фиксации переполнения (сатурации)
    );
end signed_round_sat;

architecture Behavioral of signed_round_sat is

    -- Абсолютно статические константы индексов
    constant LSB_IDX   : integer := (IWID - OWID) - SHIFT_LEFT;
    constant ROUND_IDX : integer := (IWID - OWID - 1) - SHIFT_LEFT;

    -- Константы для сатурации (максимальные и минимальные границы знакового выхода)
    constant MAX_VAL   : signed(OWID-1 downto 0) := (OWID-1 => '0', others => '1'); -- 0111...11
    constant MIN_VAL   : signed(OWID-1 downto 0) := (OWID-1 => '1', others => '0'); -- 1000...00

    -- Внутренние сигналы конвейера
    signal data_in_reg : signed(IWID-1 downto 0) := (others => '0');
    signal o_data_reg  : std_logic_vector(OWID-1 downto 0) := (others => '0');
    signal ovf_reg     : std_logic := '0';
    signal o_valid_reg : std_logic := '0';

begin

    process(aclk)
        variable base_val      : signed(OWID-1 downto 0);
        variable lsb_bit       : std_logic;
        variable round_bit     : std_logic;
        variable has_tail      : boolean;
        variable shift_ovf     : boolean;
        variable math_ovf      : boolean;
        
        -- ИСПРАВЛЕНО: Расширенная переменная до OWID+2 бит для безопасного контроля знака (индексы от OWID+1 до 0)
        variable rounded_val   : signed(OWID+1 downto 0); 
        
        -- Константы для контроля переполнения от сдвига
        constant SIGN_BIT_IDX  : integer := IWID - 1;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                data_in_reg <= (others => '0');
                o_data_reg  <= (others => '0');
                ovf_reg     <= '0';
                o_valid_reg <= '0';
            else
                -- 1. Входной регистр для стабильности таймингов
                if i_valid = '1' then
                    data_in_reg <= signed(i_data);
                end if;
                    
                o_valid_reg <= i_valid;

                -- 2. Выделяем составные части числа напрямую из data_in_reg.
                base_val  := data_in_reg(LSB_IDX + OWID - 1 downto LSB_IDX);
                lsb_bit   := data_in_reg(LSB_IDX);
                
                -- Защита от ухода в отрицательную зону, если ROUND_IDX равен -1 (когда округлять нечего)
                if ROUND_IDX >= 0 then
                    round_bit := data_in_reg(ROUND_IDX);
                else
                    round_bit := '0';
                end if;
                
                -- 3. Проверяем наличие «хвоста» младших бит для алгоритма Round to Nearest Even
                has_tail := false;
                if ROUND_IDX > 0 then
                    if data_in_reg(ROUND_IDX-1 downto 0) /= to_signed(0, ROUND_IDX) then
                        has_tail := true;
                    end if;
                end if;

                -- 4. Математика Round to Nearest Even (теперь ресайз до OWID+2)
                if round_bit = '1' then
                    if has_tail or (lsb_bit = '1') then
                        rounded_val := resize(base_val, OWID+2) + 1;
                    else
                        rounded_val := resize(base_val, OWID+2);
                    end if;
                else
                    rounded_val := resize(base_val, OWID+2);
                end if;
                
                -- 5. ИСПРАВЛЕНО: Безопасный контроль переполнения из-за левого сдвига (SHIFT_LEFT)
                -- Стабильно компилируется в Vivado при любых значениях generic параметров
                shift_ovf := false;
                if SHIFT_LEFT > 0 then
                    for i in 0 to IWID-1 loop
                        if (i >= LSB_IDX + OWID) and (i < SIGN_BIT_IDX) then
                            if data_in_reg(i) /= data_in_reg(SIGN_BIT_IDX) then
                                shift_ovf := true;
                            end if;
                        end if;
                    end loop;
                end if;

                -- 6. ИСПРАВЛЕНО: Теперь индексы OWID+1 и OWID существуют и полностью легальны
                if rounded_val(OWID+1) /= rounded_val(OWID) then
                    math_ovf := true;
                else
                    math_ovf := false;
                end if;

                -- 7. Финальная сатурация (Защита от переполнения)
                if math_ovf or shift_ovf then
                    ovf_reg <= '1';
                    if data_in_reg(SIGN_BIT_IDX) = '0' then
                        o_data_reg <= std_logic_vector(MAX_VAL);
                    else
                        o_data_reg <= std_logic_vector(MIN_VAL);
                    end if;
                else
                    o_data_reg <= std_logic_vector(rounded_val(OWID-1 downto 0));
                    ovf_reg    <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Назначение выходов
    o_data  <= o_data_reg;
    ovf     <= ovf_reg;
    o_valid <= o_valid_reg;

end Behavioral;
