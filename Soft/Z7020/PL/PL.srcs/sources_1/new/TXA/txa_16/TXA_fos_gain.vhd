
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TXA_fos_gain is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (95 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       gain_correct : in STD_LOGIC_VECTOR (2 downto 0);
       overflow : out STD_LOGIC
    );
end TXA_fos_gain;

architecture Behavioral of TXA_fos_gain is

    signal i_out_rounded     : std_logic_vector(15 downto 0) := (others => '0');
    signal q_out_rounded     : std_logic_vector(15 downto 0) := (others => '0');
    signal m_axis_tvalid_reg : std_logic := '0';
    signal gain_overflow_reg : std_logic := '0';

begin

process(aclk)
    variable i_raw        : signed(47 downto 0);
    variable q_raw        : signed(47 downto 0);
    variable shift_val    : integer range 0 to 7;
    variable i_gain       : signed(47 downto 0);
    variable q_gain       : signed(47 downto 0);
    variable i_rounded    : signed(48 downto 0); -- 49 бит для безопасного сложения
    variable q_rounded    : signed(48 downto 0);
    
    -- ИСПРАВЛЕНО: Добавляем '1' в 24-й бит (половина веса 25-го бита)
    constant ROUND_ADD    : signed(48 downto 0) := to_signed(16777216, 49); -- 2^24
begin
    if rising_edge(aclk) then
        m_axis_tvalid_reg <= s_axis_tvalid;
        gain_overflow_reg <= '0';

        -- Разделение 96-битной шины на I и Q каналы по 48 бит
        i_raw := signed(s_axis_tdata(95 downto 48));
        q_raw := signed(s_axis_tdata(47 downto 0));

        -- Дешифрация величины усиления (сдвига влево)
        case gain_correct is
            when "001"   => shift_val := 1;
            when "010"   => shift_val := 2;
            when "011"   => shift_val := 3;
            when "100"   => shift_val := 4;
            when "101"   => shift_val := 5;
            when "110"   => shift_val := 6;
            when "111"   => shift_val := 7;
            when others  => shift_val := 0;
        end case;

        -- Применяем динамическое усиление сдвигом влево
        i_gain := shift_left(i_raw, shift_val);
        q_gain := shift_left(q_raw, shift_val);

        -- Выполняем округление на базе исходной сетки (добавление 2^24)
        i_rounded := resize(i_gain, 49) + ROUND_ADD;
        q_rounded := resize(q_gain, 49) + ROUND_ADD;

        -- Проверяем биты с 47 по 40. Они обязаны дублировать знак (бит 48).
        if (i_rounded(48) = '0' and (i_rounded(47 downto 37) /= (47 downto 37 => '0'))) then
            i_out_rounded     <= x"7FFF"; -- Положительное насыщение
            gain_overflow_reg <= '1';
        elsif (i_rounded(48) = '1' and (i_rounded(47 downto 37) /= (47 downto 37 => '1'))) then
            i_out_rounded     <= x"8000"; -- Отрицательное насыщение
            gain_overflow_reg <= '1';
        else
            -- Все биты расширения знака совпали, данные не искажены
            i_out_rounded     <= std_logic_vector(i_rounded(37 downto 22));
        end if;
        
        -- Проверяем биты с 47 по 40. Они обязаны дублировать знак (бит 48).
        if (q_rounded(48) = '0' and (q_rounded(47 downto 37) /= (47 downto 37 => '0'))) then
            q_out_rounded     <= x"7FFF"; -- Положительное насыщение
            gain_overflow_reg <= '1';
        elsif (q_rounded(48) = '1' and (q_rounded(47 downto 37) /= (47 downto 37 => '1'))) then
            q_out_rounded     <= x"8000"; -- Отрицательное насыщение
            gain_overflow_reg <= '1';
        else
            -- Все биты расширения знака совпали, данные не искажены
            q_out_rounded     <= std_logic_vector(q_rounded(37 downto 22));
        end if;
        
    end if;
end process;

    -- Формирование выходной шины (I в старших 16 битах, Q в младших 16 битах)
    m_axis_tdata  <= i_out_rounded & q_out_rounded;
    m_axis_tvalid <= m_axis_tvalid_reg;
    overflow      <= gain_overflow_reg;

end Behavioral;
