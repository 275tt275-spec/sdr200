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
    signal dc_calc, dif : signed(35 downto 0) := (others => '0');
    signal din_s   : signed(15 downto 0);
    signal dout17 : signed(16 downto 0) := (others => '0');

begin

din_s <= signed(din);
-- 1. Вычисляем разность (вход расширяем до 36 бит)
-- (din_s & x"00000") это аналог din_s * 2^20
dif <= (resize(din_s, 20) & x"0000") - dc_calc;
-- 3. Вычитаем накопленный DC из входного сигнала
-- Берем старшие 16 бит из dc_calc
dout17 <= resize(din_s, 17) - resize(dc_calc(35 downto 20), 17);

process(clk)
begin
	if rising_edge(clk) then
		if clr_s = '1' then
			dc_calc <= (others => '0');
		else		
            -- 2. Интегрируем сдвинутую разность (фильтр НЧ)
            dc_calc <= dc_calc + shift_right(dif, 20);
            -- 4. Логика насыщения (Saturation) под честные 16 бит
            if dout17 > 32767 then
                dout <= x"7FFF"; -- Максимум Positive
            elsif dout17 < -32768 then
                dout <= x"8000"; -- Максимум Negative
            else
                dout <= std_logic_vector(dout17(15 downto 0));
            end if;
		end if;
	end if;
	
end process;

end Behavioral;

