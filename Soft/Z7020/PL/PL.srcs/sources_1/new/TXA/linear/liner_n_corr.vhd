
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;


entity liner_n_corr is
    Port ( din_new : in  STD_LOGIC_VECTOR (17 downto 0);
           clr : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           din_fb : in  STD_LOGIC_VECTOR (17 downto 0);
           din_stab : in  STD_LOGIC_VECTOR (17 downto 0);
			  k_prop  : in  STD_LOGIC_VECTOR (17 downto 0);
			  k_dif  : in  STD_LOGIC_VECTOR (17 downto 0);
           dout_sum : out  STD_LOGIC_VECTOR (17 downto 0);
           dout_integ : out  STD_LOGIC_VECTOR (17 downto 0);
           dout_err : out  STD_LOGIC_VECTOR (17 downto 0);
           dout_stab : out  STD_LOGIC_VECTOR (17 downto 0)
			  );
end liner_n_corr;

architecture Behavioral of liner_n_corr is

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

	COMPONENT liner_n_iir
	PORT(
		clk : IN std_logic;
		din : IN std_logic_vector(17 downto 0);
		clr : IN std_logic;
		ce : IN std_logic;          
		dout : OUT std_logic_vector(17 downto 0)
		);
	END COMPONENT;


signal delay8_fix,  delay9_fix, delay1_fix, delay3_fix, delay10, delay4_fix, delay2, delay7 : std_logic_vector(17 downto 0) := (others => '0');
signal delay9, delay8, delay3, delay4: std_logic_vector(18 downto 0) := (others => '0');
signal delay1 : std_logic_vector(19 downto 0) := (others => '0');
signal delay6, k_prop_m, k_diff_m, kdiff_m : std_logic_vector(35 downto 0);

signal delay6_18, delay5_fix: std_logic_vector(23 downto 0) := (others => '0');
signal delay5: std_logic_vector(24 downto 0) := (others => '0');
	
begin

delay6_18 <= delay6(34 downto 11);

	product: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => delay8_fix,
		b => din_stab,
		m => delay6
	);
	
	k_prop_mult: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => delay8_fix,
		b => k_prop,	
		m => k_prop_m
	);

	k_diff_mult: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => delay4_fix,
		b => k_dif,	
		m => k_diff_m
	);
	kdiff_mult: mult48cc PORT MAP(
		clk => clk,
		ce => '1',
		clr => clr,
		a => delay4_fix,
		b =>   "011110011001100110",	-- 0.95 
		m => kdiff_m
	);
	Inst_liner_n_iir: liner_n_iir PORT MAP(
		clk => clk,
		din => delay1_fix,
		clr => clr,
		ce => '1',
		dout => dout_sum
	);

dout_err <= delay6_18(23 downto 6);
dout_integ <= delay5_fix(23 downto 6);
dout_stab <= delay4_fix;

proc : process (clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			delay8 <= (others => '0');
			delay8_fix <= (others => '0');
			delay5 <= (others => '0');
			delay5_fix <= (others => '0');
			delay2 <= (others => '0');
			delay9 <= (others => '0');
			delay9_fix <= (others => '0');
			delay7 <= (others => '0');
			delay1 <= (others => '0');
			delay1_fix <= (others => '0');
			delay10 <= (others => '0');
			delay3 <= (others => '0');
			delay3_fix <= (others => '0');
			delay4 <= (others => '0');
			delay4_fix <= (others => '0');
		else
			delay8 <= (din_new(17) & din_new) - (din_fb(17) & din_fb);
-- limit to -1/16..1/16			
			if delay8(18 downto 13) = "000000" or delay8(18 downto 13) = "111111" then
				delay8_fix <= delay8(17 downto 0);
			else
				if delay8(18) = '0' then
					delay8_fix <= "00" & x"1fff";
				else
					delay8_fix <= "11" & x"e000";
				end if;
			end if;
				
-- IQerr1 (19 bits)			
			delay5 <= (delay6_18(23) & delay6_18) + (delay5_fix(23) & delay5_fix);
			if delay5(24 downto 23) = "00" or delay5(24 downto 23) = "11" then
				delay5_fix <= delay5(23 downto 0);
			else
				if delay5(24) = '0' then
					delay5_fix <= x"7fffff";
				else
					delay5_fix <= x"800000";
				end if;
			end if;
-- Prop
			if	k_prop_m(35 downto 26) = "0000000000" or k_prop_m(35 downto 26) = "1111111111" then
				delay2 <= k_prop_m(26 downto 9);
			else
				if	k_prop_m(35) = '0' then
					delay2 <= "01" & x"ffff";
				else
					delay2 <= "10" & x"0000";
				end if;
			end if;
-- sum3 (19 bit)			
			delay9 <= (delay5_fix(23) & delay5_fix(23 downto 6)) + (delay2(17) & delay2);
--			if delay9(18 downto 17) = "00" or delay9(18 downto 17) = "11" then
--				delay9_fix <= delay9(17 downto 0);
--			else
--				if delay9(18) = '0' then
--					delay9_fix <= "01" & x"ffff";
--				else
--					delay9_fix <= "10" & x"0000";
--				end if;
--			end if;

-- Diff
			if	k_diff_m(35 downto 26) = "0000000000" or k_diff_m(35 downto 26) = "1111111111" then
				delay7 <= k_diff_m(26 downto 9);
			else
				if	k_diff_m(35) = '0' then
					delay7 <= "01" & x"ffff";
				else
					delay7 <= "10" & x"0000";
				end if;
			end if;
-- sum1 (20 bit)
			delay1 <= (delay7(17) & delay7(17) & delay7) + (delay9(18) & delay9);
			if delay1(19 downto 17) = "000" or delay1(19 downto 17) = "111" then
				delay1_fix <= delay1(17 downto 0);
			else
				if delay1(19) = '0' then
					delay1_fix <= "01" & x"ffff";
				else
					delay1_fix <= "10" & x"0000";
				end if;
			end if;
			
-- diff			
			delay10 <= delay6_18(23 downto 6);
			delay3 <= (delay6_18(23) & delay6_18(23 downto 6)) - (delay10(17) & delay10);
			if delay3(18 downto 17) = "00" or delay3(18 downto 17) = "11" then
				delay3_fix <= delay3(17 downto 0);
			else
				if delay3(18) = '0' then
					delay3_fix <= "01" & x"ffff";
				else
					delay3_fix <= "10" & x"0000";
				end if;
			end if;
			delay4 <= (delay3_fix(17) & delay3_fix) + kdiff_m(35 downto 17);
			if delay4(18 downto 17) = "00" or delay4(18 downto 17) = "11" then
				delay4_fix <= delay4(17 downto 0);
			else
				if delay4(18) = '0' then
					delay4_fix <= "01" & x"ffff";
				else
					delay4_fix <= "10" & x"0000";
				end if;
			end if;
		end if;	-- clr
	end if;	-- clk
end process;
	
end Behavioral;

