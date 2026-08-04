----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04.08.2026 09:50:55
-- Design Name: 
-- Module Name: filter_gain - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity filter_gain is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (63 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (47 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       gain_correct : in STD_LOGIC_VECTOR (2 downto 0);
       overflow : out STD_LOGIC
    );
end filter_gain;

architecture Behavioral of filter_gain is

    signal i_out_rounded     : signed(23 downto 0) := (others => '0');
    signal q_out_rounded     : signed(23 downto 0) := (others => '0');
    signal m_axis_tvalid_reg : std_logic := '0';
    signal gain_overflow_reg : std_logic := '0';


begin

process(aclk)
    variable i_raw      : signed(31 downto 0);
    variable q_raw      : signed(31 downto 0);
    variable shift_val  : integer range 0 to 7;
    variable i_shifted  : signed(31 downto 0);
    variable q_shifted  : signed(31 downto 0);
    variable i_rounded  : signed(32 downto 0); -- 33 бита для безопасного сложения
    variable q_rounded  : signed(32 downto 0);
begin
    if rising_edge(aclk) then
        -- Конвейеризируем валидность на 1 такт для синхронизации с данными
        m_axis_tvalid_reg <= s_axis_tvalid;
        
        -- Сброс флага насыщения по умолчанию для текущего такта
        gain_overflow_reg <= '0';

        -- Разделение входной шины на каналы I и Q (по 32 бита)
        i_raw := signed(s_axis_tdata(63 downto 32));
        q_raw := signed(s_axis_tdata(31 downto 0));

        -- Преобразование gain_correct в целочисленный шаг сдвига
        case gain_correct is
            when "001"   => shift_val := 1;
            when "010"   => shift_val := 2;
            when "011"   => shift_val := 3;
            when "100"   => shift_val := 4;
            when "101"   => shift_val := 5;
            when "110"   => shift_val := 6;
            when "111"   => shift_val := 7;
            when others  => shift_val := 0; -- Для "000" и неопределенных состояний
        end case;

        -- Арифметический сдвиг влево (динамическое усиление)
        i_shifted := shift_left(i_raw, shift_val);
        q_shifted := shift_left(q_raw, shift_val);

        -- Округление: добавляем половину веса отбрасываемой части (бит 6 -> +64)
        i_rounded := resize(i_shifted, 33) + 64;
        q_rounded := resize(q_shifted, 33) + 64;

        -- === Контроль насыщения и усечение до 24 бит для канала I ===
        if (i_rounded(32) = '0' and i_rounded(31) /= '0') then
            i_out_rounded     <= x"7FFFFF"; -- Положительное насыщение (строго 24 бита)
            gain_overflow_reg <= '1';
        elsif (i_rounded(32) = '1' and i_rounded(31) /= '1') then
            i_out_rounded     <= x"800000"; -- Отрицательное насыщение (строго 24 бита)
            gain_overflow_reg <= '1';
        else
            i_out_rounded     <= i_rounded(31 downto 8); -- Оставляем старшие 24 бита
        end if;
        
        -- === Контроль насыщения и усечение до 24 бит для канала Q ===
        if (q_rounded(32) = '0' and q_rounded(31) /= '0') then
            q_out_rounded     <= x"7FFFFF"; -- Положительное насыщение (строго 24 бита)
            gain_overflow_reg <= '1';
        elsif (q_rounded(32) = '1' and q_rounded(31) /= '1') then
            q_out_rounded     <= x"800000"; -- Отрицательное насыщение (строго 24 бита)
            gain_overflow_reg <= '1';
        else
            q_out_rounded     <= q_rounded(31 downto 8);
        end if;
        
    end if;
end process;

    -- Формирование выходной шины (I в старших битах, Q в младших)
    m_axis_tdata  <= std_logic_vector(i_out_rounded) & std_logic_vector(q_out_rounded);
    m_axis_tvalid <= m_axis_tvalid_reg;
    
    -- Вывод бита насыщения наружу
    overflow <= gain_overflow_reg;

end Behavioral;
