----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:32:08 06/28/2021 

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_signed.ALL;

entity calc_rms is
    Port ( clk : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           din_i : in  STD_LOGIC_VECTOR (15 downto 0);
           din_q : in  STD_LOGIC_VECTOR (15 downto 0);
           dout : out  STD_LOGIC_VECTOR (31 downto 0));
end calc_rms;

architecture Behavioral of calc_rms is

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

signal i18, q18 : std_logic_vector(17 downto 0);
signal m_i, m_q : std_logic_vector(35 downto 0);
signal sum, diff : std_logic_vector(32 downto 0) := (others => '0');
signal acc : std_logic_vector(48 downto 0) := (others => '0');
 
begin

dout <= acc(47 downto 16);

i18 <= sxt(din_i, 18);
q18 <= sxt(din_q, 18);

mult_i: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => i18,
		b => i18,
		m => m_i
	);
mult_q: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => q18,
		b => q18,
		m => m_q
	);

diff <= sum - acc(48 downto 16);
 
process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			sum <= (others => '0');
			acc <= (others => '0');
		else
			sum <= m_i(32 downto 0) + m_q(32 downto 0);
			acc <= acc + sxt(diff, 49);
		end if;
	end if;
end process;
	
end Behavioral;

