----------------------------------------------------------------------------------

-- Create Date:    12:50:47 10/21/2011 

--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity liner_n_agc is
    Port ( din_i : in  STD_LOGIC_VECTOR (15 downto 0);
           din_q : in  STD_LOGIC_VECTOR (15 downto 0);
           fwd_i : in  STD_LOGIC_VECTOR (15 downto 0);
           fwd_q : in  STD_LOGIC_VECTOR (15 downto 0);
           clk : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           k : in  STD_LOGIC_VECTOR (2 downto 0);
           sat : in  STD_LOGIC_VECTOR (2 downto 0);
           dout_i : out  STD_LOGIC_VECTOR (15 downto 0);
           dout_q : out  STD_LOGIC_VECTOR (15 downto 0);
			  k_out : out  STD_LOGIC_VECTOR (15 downto 0));
end liner_n_agc;

architecture Behavioral of liner_n_agc is
	COMPONENT mult48cc
	PORT(
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;
		a : IN std_logic_vector(17 downto 0);
		b : IN std_logic_vector(17 downto 0);          
		m : OUT std_logic_vector(35 downto 0)
		);
	END COMPONENT;

constant C1 : std_logic_vector(15 downto 0) := x"3333"; -- 0.8 !1Q14
constant C2 : std_logic_vector(27 downto 0) := x"0000002"; -- 1/2^25 !1Q26

signal a1, a2, a3, a4 : std_logic_vector(17 downto 0);
signal p1, p2, p3, p4 : std_logic_vector(35 downto 0);

signal sum1, dif1, sat3 : std_logic_vector(15 downto 0) := (others => '0') ;
signal sat3k, sum2, sat2 : std_logic_vector(27 downto 0)  := (others => '0');	-- 1Q26

signal dif2 : std_logic_vector(27 downto 0);	-- 1Q26
signal sum3: std_logic_vector(27 downto 0) := (others => '0');	-- 1Q26
signal sat1 : std_logic_vector(17 downto 0); -- 0Q17


begin

k_out <= sat1(17 downto 2);

a1 <= fwd_i & "00";
a2 <= fwd_q & "00";

mult_i : mult48cc port map (
		clk => clk,
		ce => '1',
		clr => clr,
		a => a1,
		b => a1,
		m => p1
	);
mult_q : mult48cc port map (
		clk => clk,
		ce => '1',
		clr => clr,
		a => a2,
		b => a2,
		m => p2
	);

a3 <= din_i & "00";
a4 <= din_q & "00";

	
prod_i : mult48cc port map (
		clk => clk,
		ce => '1',
		clr => clr,
		a => a3,
		b => sat1,
		m => p3
	);

prod_q : mult48cc port map (
		clk => clk,
		ce => '1',
		clr => clr,
		a => a4,
		b => sat1,
		m => p4
	);

dif2 <= sat2 - sum3;

proc : process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			sum1 <= (others => '0');
			dif1 <= (others => '0');
			sat3 <= (others => '0');
			sum2 <= (others => '0');
			sat2 <= (others => '0');
			sum3 <= (others => '0');
			sat1 <= (others => '0');
		else
		
-- sum1 1Q14 (-2..+2)
			sum1 <= p1(35 downto 20) + p2(35 downto 20);

			dif1 <= sum1 - C1;
			
			if dif1(15) = '1' then
				sat3 <= x"0000";
			elsif dif1(14 downto 13) /= "00" then
				sat3 <= x"3fff";	-- 0.5
			else
				sat3 <= dif1(14 downto 0) & '0';	--  0Q15 limited to 0..0.5
			end if;
			
			case k is
			when "000" =>
				sat3k <= "000000000000" & sat3;							-- 11 shifts
			when "001" =>
				sat3k <= "0000000000000" & sat3(15 downto 1) ;		-- 12
			when "010" =>
				sat3k <= "00000000000000" & sat3(15 downto 2);		-- 13	
			when "011" =>
				sat3k <= "000000000000000" & sat3(15 downto 3);		-- 14
			when "100" =>
				sat3k <= "0000000000000000" & sat3(15 downto 4);	-- 15
			when "101" =>
				sat3k <= "00000000000000000" & sat3(15 downto 5);	-- 16
			when "110" =>
				sat3k <= "000000000000000000" & sat3(15 downto 6);	-- 17
			when others =>
				sat3k <= "000000000000000000000" & sat3(15 downto 9);-- 20 shifts
			end case;
				
--			sum2 <= sat2 + sat3k - C2;
			sum2 <= sat2 + sat3k;
-- sat2 0.25 .. 0.75			
			if sum2(27) = '1' or sum2(27 downto 24) = "0000" then	-- < 0 or < 0.25
				sat2 <= x"1000000";	--	1Q26 0.25;
			elsif sum2(27 downto 24) = "0001" or sum2(27 downto 24) = "0010" then	
				sat2 <= sum2;
			else
				sat2 <= x"3000000";	--	1Q26 0.75
			end if;
			
-- K= 1/2^14
			sum3 <= sum3 + (dif2(27) & dif2(27) & dif2(27) & dif2(27) &
								 dif2(27) & dif2(27) & dif2(27) & dif2(27) &
								 dif2(27) & dif2(27) & dif2(27) & dif2(27) & 
								 dif2(27) & dif2(27) & dif2(27 downto 14)
								 );
			
			if sum3(27) = '1' or sum3(27 downto 24) = "0000" then -- < 0.25
				sat1 <= x"2000" & "00";
			elsif sum3(27 downto 24) = "0001" or sum3(27 downto 24) = "0010" then	-- 0.25..0.75
				sat1 <= sum3(26 downto 9);
			else
				sat1 <= x"6000" & "00";
			end if;
		
			if p3(35 downto 32) = "0000" or p3(35 downto 32) = "1111" then
				dout_i <= p3(32 downto 17);
			else
				if p3(35) = '0' then
					dout_i <= x"7fff";
				else
					dout_i <= x"8000";
				end if;
			end if;

			if p4(35 downto 32) = "0000" or p4(35 downto 32) = "1111" then
				dout_q <= p4(32 downto 17);
			else
				if p4(35) = '0' then
					dout_q <= x"7fff";
				else
					dout_q <= x"8000";
				end if;
			end if;
			
		end if;
		
	end if;
end process;
end Behavioral;

