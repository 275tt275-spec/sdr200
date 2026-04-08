----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity liner_n_iir is
    Port ( clk : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (17 downto 0);
           clr : in  STD_LOGIC;
           ce : in  STD_LOGIC;
           dout : out  STD_LOGIC_VECTOR (17 downto 0));
end liner_n_iir;

architecture Behavioral of liner_n_iir is

signal sub : std_logic_vector(18 downto 0);
signal sum : std_logic_vector(30 downto 0) := (others => '0');


begin

sub <= (din(17) & din) - sum(30 downto 12);

add_30 : process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			sum <= (others => '0');
			dout <= (others => '0');
		else
--			if ce = '1' then
				sum <= sum + (sub(18) & sub(18) & sub(18) & sub(18) &
				              sub(18) & sub(18) & sub(18) & sub(18) &
								  sub(18) & sub(18) & sub(18) & sub & '0' );	-- 1/2^11

				if sum(30 downto 29) = "00" or sum(30 downto 29) = "11" then
					dout <= sum(29 downto 12);
				else
					if sum(30) = '0' then
						dout <= "01" & x"ffff";
					else
						dout <= "10" & x"0000";
					end if;
				end if;

--			end if;
		end if;
	end if;
end process add_30;

end Behavioral;

