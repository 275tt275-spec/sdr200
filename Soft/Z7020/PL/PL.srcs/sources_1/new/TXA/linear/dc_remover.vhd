----------------------------------------------------------------------------------
-- Create Date:    17:08:06 06/13/2012 
--
-- NOTE! din and dout has to be  14 bits actually (right alignment)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity dc_remover is
    Port ( clk : in  STD_LOGIC;
           clr_s : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (15 downto 0);
           tst : out  STD_LOGIC_VECTOR (15 downto 0);
           dout : out  STD_LOGIC_VECTOR (15 downto 0));
end dc_remover;

architecture Behavioral of dc_remover is

signal dc_calc, sum, dif : std_logic_vector(35 downto 0) := (others => '0');
signal dc_err : std_logic_vector(19 downto 0) := (others => '0');
signal dout17 : std_logic_vector(16 downto 0) := (others => '0');

begin

tst <= dc_err(19 downto 4);

sum <= dc_calc + (x"0000" & dc_err); 
dif <= (din & x"00000") - dc_calc;

process(clk)
begin
	if rising_edge(clk) then
		if clr_s = '1' then
			dc_calc <= (others => '0');
			dc_err <= (others => '0');
			dout17 <= (others => '0');
		else
			dc_calc <= dc_calc + to_stdlogicvector(to_bitvector(dif) SRA 20);
			dout17 <= (din(15) & din) - (sum(35) & sum(35 downto 20));
			dc_err <= sum(19 downto 0);

			if dout17(16 downto 15) = "00" or dout17(16 downto 15) = "11" then
				dout <= dout17(15 downto 0);
			elsif dout17(16) = '0' then
				dout <= x"1fff";
			else
				dout <= x"e000";
			end if;
		end if;
	end if;
	
end process;

end Behavioral;

