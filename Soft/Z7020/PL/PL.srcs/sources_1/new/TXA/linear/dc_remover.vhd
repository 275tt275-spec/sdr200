----------------------------------------------------------------------------------
-- Create Date:    17:08:06 06/13/2012 
--
-- NOTE! din and dout has to be  14 bits actually (right alignment)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dc_remover is
    Port ( clk : in  STD_LOGIC;
           clr_s : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (15 downto 0);
           dout : out  STD_LOGIC_VECTOR (15 downto 0));
end dc_remover;

architecture Behavioral of dc_remover is

    -- Используем тип signed для математики (36 бит для точности накопления)
    signal dc_calc : signed(35 downto 0) := (others => '0');
    signal din_s   : signed(15 downto 0) := (others => '0');
    signal res_17_debug : signed(16 downto 0); 

begin

res_17_debug <= resize(signed(din), 17) - resize(dc_calc(35 downto 20), 17);

din_s <= signed(din);

-- 1. Комбинаторный расчет (0 тактов задержки для этих сигналов)
-- Мы вычисляем результат "на лету" до того, как защелкнуть его в регистр
process(clk)
    variable dif    : signed(35 downto 0);
    variable res_17 : signed(16 downto 0);
begin
    if rising_edge(clk) then
        if clr_s = '1' then
            dc_calc <= (others => '0');
            dout    <= (others => '0');
        else
            -- РАСЧЕТ ПЕТЛИ ОС (обновляется каждый такт)
            dif := shift_left(resize(din_s, 36), 20) - dc_calc;
            dc_calc <= dc_calc + shift_right(dif, 20);

            -- ВЫХОДНОЙ ПУТЬ (минимальная задержка)
            -- Вычитаем уже накопленный к этому моменту DC
            res_17 := resize(din_s, 17) - resize(dc_calc(35 downto 20), 17);

            -- Сатурация и выдача на выход
            if res_17 > 32767 then
                dout <= x"7FFF";
            elsif res_17 < -32768 then
                dout <= x"8000";
            else
                dout <= std_logic_vector(res_17(15 downto 0));
            end if;
        end if;
    end if;
end process;

end Behavioral;

