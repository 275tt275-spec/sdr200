----------------------------------------------------------------------------------
-- Create Date:    13:24:07 09/05/2011 
--
-- Orthogonality and gain block
--
-- dout0 = cos * din_c * gain_I
-- dout1 = sin * din_c * gain_I
-- dout2 = (cos - sin * din_s) * gain_Q
-- dout3 = (sin + cos * din_s) * gain_Q
--
-- All douts are in 1Q15 format (-2..+2) range
-- 
-- sin - sin(wt), cos - cos(wt), wt - carrier frequency
-- din_s - sin(phi), din_c - cos(phi), phi - orthogonality angle
-- 
-- Latency: 5 clocks
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;


entity orth_gain is
    Port ( clk : in  STD_LOGIC;
           ce : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           sin : in  STD_LOGIC_VECTOR (15 downto 0);
           cos : in  STD_LOGIC_VECTOR (15 downto 0);
           din_s : in  STD_LOGIC_VECTOR (15 downto 0);
           din_c : in  STD_LOGIC_VECTOR (15 downto 0);
           gain_I : in  STD_LOGIC_VECTOR (15 downto 0);
           gain_Q : in  STD_LOGIC_VECTOR (15 downto 0);
           dout0 : out  STD_LOGIC_VECTOR (16 downto 0);	-- 1Q15
           dout1 : out  STD_LOGIC_VECTOR (16 downto 0);	-- 1Q15
           dout2 : out  STD_LOGIC_VECTOR (16 downto 0);	-- 1Q15
           dout3 : out  STD_LOGIC_VECTOR (16 downto 0)	-- 1Q15
			  );
end orth_gain;

architecture Behavioral of orth_gain is

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

signal ac1, bc1, ac2, bc3, g_I, g_Q : std_logic_vector(17 downto 0);
signal pc1, pc2, pc3, pc4, pg1, pg2, pg3, pg4 : std_logic_vector(35 downto 0);
signal reg1, reg2, reg3, reg4 : std_logic_vector(15 downto 0) := (others => '0');
signal reg5, reg6, sum1, sum2 : std_logic_vector(17 downto 0) := (others => '0');

begin

ac1 <= cos & "00";
bc1 <= din_c & "00";
ac2 <= sin & "00";
bc3 <= din_s & "00";

mult_c1 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => ac1,
		b => bc1,
		m => pc1
	);
mult_c2 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => ac2,
		b => bc1,
		m => pc2
	);
mult_c3 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => ac2,
		b => bc3,
		m => pc3
	);
mult_c4 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => ac1,
		b => bc3,
		m => pc4
	);

g_I <= gain_I & "00";
g_Q <= gain_Q & "00";

mult_g1 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => reg5,
		b => g_I,
		m => pg1
	);
mult_g2 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => reg6,
		b => g_I,
		m => pg2
	);
mult_g3 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => sum1,
		b => g_Q,
		m => pg3
	);
mult_g4 : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => sum2,
		b => g_Q,
		m => pg4
	);

dout0 <= pg1(34 downto 18);
dout1 <= pg2(34 downto 18);
dout2 <= pg3(34 downto 18);
dout3 <= pg4(34 downto 18);

proc: process(clk)
begin
	
	if rising_edge(clk) then
		if clr = '1' then
			reg1 <= (others =>'0');
			reg3 <= (others =>'0');
			reg2 <= (others =>'0');
			reg4 <= (others =>'0');
			reg5 <= (others =>'0');
			reg6 <= (others =>'0');
			sum1 <= (others =>'0');
			sum2 <= (others =>'0');
		else
			reg1 <= cos;
			reg3 <= reg1;
			reg2 <= sin;
			reg4 <= reg2;
			reg5 <= pc1(35 downto 18);	-- +-2 range
			reg6 <= pc2(35 downto 18);
			sum1 <= (reg3(15) & reg3 & '0') - pc3(35 downto 18); -- +-2 range
			sum2 <= (reg4(15) & reg4 & '0') + pc4(35 downto 18);
		end if;
 		
		
	
	
	end if;
	
end process;
end Behavioral;

