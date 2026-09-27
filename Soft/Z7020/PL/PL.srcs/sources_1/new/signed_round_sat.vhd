library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity signed_round_sat is
    generic (
        IWID : integer := 37; -- Исходная разрядность данных
        OWID : integer := 24  -- Выходная разрядность после округления
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;
        i_data  : in  std_logic_vector(IWID-1 downto 0);
        i_valid : in  std_logic;
        o_data  : out std_logic_vector(OWID-1 downto 0);
        o_valid : out  std_logic;
        ovf     : out std_logic -- Флаг фиксации переполнения (сатурации)
    );
end signed_round_sat;

architecture Behavioral of signed_round_sat is

    -- Вычисляем позицию битов для удобства
    constant LSB_IDX   : integer := IWID - OWID;     -- Младший сохраняемый бит
    constant ROUND_IDX : integer := IWID - OWID - 1; -- Отбрасываемый бит (0.5 LSB)

    -- Константы для сатурации (максимальные и минимальные границы знакового выхода)
    constant MAX_VAL   : signed(OWID-1 downto 0) := (OWID-1 => '0', others => '1'); -- 0111...11
    constant MIN_VAL   : signed(OWID-1 downto 0) := (OWID-1 => '1', others => '0'); -- 1000...00

    -- Внутренние сигналы конвейера
    signal data_in_reg : signed(IWID-1 downto 0) := (others => '0');
    signal o_data_reg  : std_logic_vector(OWID-1 downto 0) := (others => '0');
    signal ovf_reg     : std_logic := '0';

begin

    process(aclk)
        variable base_val  : signed(OWID-1 downto 0);
        variable lsb_bit   : std_logic;
        variable round_bit : std_logic;
        variable has_tail  : boolean;
        
        -- Расширенная переменная для безопасного сложения без потери знака при перегрузе
        variable rounded_val : signed(OWID downto 0); 
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                data_in_reg <= (others => '0');
                o_data_reg  <= (others => '0');
                ovf_reg     <= '0';
            else
                -- 1. Входной регистр для стабильности таймингов
                if i_valid = '1' then
                    data_in_reg <= signed(i_data);
                end if;
                    
                o_valid <= i_valid;

                -- 2. Выделяем составные части числа
                base_val  := data_in_reg(IWID-1 downto LSB_IDX);
                lsb_bit   := data_in_reg(LSB_IDX);
                round_bit := data_in_reg(ROUND_IDX);
                
                -- Проверяем, есть ли хотя бы одна '1' в битах, которые младше бита округления
                has_tail := false;
                if ROUND_IDX > 0 then
                    if data_in_reg(ROUND_IDX-1 downto 0) /= (ROUND_IDX-1 downto 0 => '0') then
                        has_tail := true;
                    end if;
                end if;

                -- 3. Математика Round to Nearest Even
                -- Расширяем на 1 бит вверх для контроля переноса знака при сложении
                if round_bit = '1' then
                    -- Если остаток строго равен 0.5 (round=1, а в хвосте нули), 
                    -- то прибавляем 1 только если LSB нечетный (lsb=1), делая результат четным.
                    -- Если остаток больше 0.5 (has_tail = true), округляем вверх всегда.
                    if has_tail or (lsb_bit = '1') then
                        rounded_val := resize(base_val, OWID+1) + 1;
                    else
                        rounded_val := resize(base_val, OWID+1);
                    end if;
                else
                    -- Меньше 0.5, просто отбрасываем дробный хвост
                    rounded_val := resize(base_val, OWID+1);
                end if;
 
                -- 4. Сатурация (Борьба с переполнением)
                if rounded_val(OWID) /= rounded_val(OWID-1) then
                    -- Биты знака разошлись - зафиксировано переполнение
                    ovf_reg <= '1';
                    if rounded_val(OWID) = '0' then
                        -- Положительный перегруз (выход вверх за границы 0111...11)
                        o_data_reg <= std_logic_vector(MAX_VAL);
                    else
                        -- Отрицательный перегруз (выход вниз за границы 1000...00)
                        o_data_reg <= std_logic_vector(MIN_VAL);
                    end if;
                else
                    -- Данные чистые, без переполнения, знаки совпадают
                    o_data_reg <= std_logic_vector(rounded_val(OWID-1 downto 0));
                    ovf_reg    <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Назначение выходов
    o_data <= o_data_reg;
    ovf    <= ovf_reg;

end Behavioral;
