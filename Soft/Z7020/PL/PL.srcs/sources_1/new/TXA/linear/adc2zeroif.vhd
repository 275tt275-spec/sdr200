----------------------------------------------------------------------------------
-- Create Date:    15:47:43 11/19/20124
--
-- Переносит входной сигнал на 0 частоту. Сначала формируются i/q компоненты, потом
--  полученный сигнал комплексно переносится по частоте
--
--	i_amp, q_amp - 8192 означает умножение на 1, 131071 соответсвенно умножение на 16
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity adc2zeroif is
    Port ( clk : in  STD_LOGIC;
			  ce : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (15 downto 0);
           cosine : in  STD_LOGIC_VECTOR (15 downto 0);
           sine : in  STD_LOGIC_VECTOR (15 downto 0);
           i_amp : in  STD_LOGIC_VECTOR (17 downto 0);
           q_amp : in  STD_LOGIC_VECTOR (17 downto 0);
           i_out : out  STD_LOGIC_VECTOR (15 downto 0);
           q_out : out  STD_LOGIC_VECTOR (15 downto 0));
end adc2zeroif;

architecture Behavioral of adc2zeroif is

	COMPONENT dc_remover
	PORT(
		clk : IN std_logic;
		clr_s : IN std_logic;
		din : IN std_logic_vector(15 downto 0);          
		tst : OUT std_logic_vector(15 downto 0);
		dout : OUT std_logic_vector(15 downto 0)
	);
	END COMPONENT;

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
	
	COMPONENT scope
	PORT(
		clk : IN std_logic;
		data : IN std_logic_vector(63 downto 0);
		trig0 : IN std_logic_vector(1 downto 0)       
		);
	END COMPONENT;
	

signal adc_no_dc, adc_no_dc_prev : std_logic_vector(15 downto 0);
signal i_raw, q_raw : std_logic_vector(17 downto 0);
signal mult_i_raw, mult_q_raw : std_logic_vector(17 downto 0);
signal mult_i_hi_freq, mult_q_hi_freq : std_logic_vector(35 downto 0);
signal i_hi_freq, q_hi_freq : std_logic_vector(17 downto 0);
signal mult_cosine, mult_sine : std_logic_vector(17 downto 0);
signal mult_icos, mult_qcos, mult_isin, mult_qsin : std_logic_vector(35 downto 0);

signal scope_d : std_logic_vector(63 downto 0);
signal scope_trg : std_logic_vector(1 downto 0) := "00";

signal i_zeroif, q_zeroif : std_logic_vector(35 downto 0);

begin

--	Inst_scope: scope PORT MAP(
--		clk => clk,
--		data => scope_d,
--		trig0 => scope_trg
--	);
	
scope_d <= din & i_raw(17 downto 2) & i_hi_freq(17 downto 2) & i_zeroif(35 downto 20);
	
inst_dc_remover : dc_remover
		port map (
			clk => clk,
			clr_s => '0',
			din => din,
			tst => open,
			dout => adc_no_dc
		);
--adc_no_dc <= din;

-- i/q коррекция амплитуды
mult_i_correction : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => i_raw,
		b => i_amp,
		m => mult_i_hi_freq
	);

mult_q_correction : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => q_raw,
		b => q_amp,
		m => mult_q_hi_freq
	);		

-- комплексный перенос по частоте
mult_cosine <= cosine & "00";
mult_sine <= sine & "00";

inst_mult_icos : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => i_hi_freq,
		b => mult_cosine,
		m => mult_icos
	);

inst_mult_isin : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => i_hi_freq,
		b => mult_sine,
		m => mult_isin
	);

inst_mult_qcos : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => q_hi_freq,
		b => mult_cosine,
		m => mult_qcos
	);

inst_mult_qsin : mult48cc port map (
		clk => clk,
		ce => ce,
		clr => clr,
		a => q_hi_freq,
		b => mult_sine,
		m => mult_qsin
	);

process(clk)
begin
	if rising_edge(clk) then
		adc_no_dc_prev <= adc_no_dc;
    
		if clr = '1' then
		else
      
			i_raw <= (adc_no_dc(15) & adc_no_dc & "0") - (adc_no_dc_prev(15) & adc_no_dc_prev & "0");
			q_raw <= (adc_no_dc(15) & adc_no_dc & "0") + (adc_no_dc_prev(15) & adc_no_dc_prev & "0");
					
			-- ограничиваем i/q после выравнивания амплитуды
			if	mult_i_hi_freq(35 downto 29) = "0000000" or mult_i_hi_freq(35 downto 29) = "1111111" then
				i_hi_freq <= mult_i_hi_freq(29 downto 12);
			else
				if	mult_i_hi_freq(35) = '0' then
					i_hi_freq <= "01" & x"ffff";
				else
					i_hi_freq <= "10" & x"0000";
				end if;
			end if;
			
			if	mult_q_hi_freq(35 downto 29) = "0000000" or mult_q_hi_freq(35 downto 29) = "1111111" then
				q_hi_freq <= mult_q_hi_freq(29 downto 12);
			else
				if	mult_q_hi_freq(35) = '0' then
					q_hi_freq <= "01" & x"ffff";
				else
					q_hi_freq <= "10" & x"0000";
				end if;
			end if;

			-- формируем выходные i/q без переполнения
			i_zeroif <= (mult_icos(35) & mult_icos(35 downto 1)) + (mult_qsin(35) & mult_qsin(35 downto 1));
			q_zeroif <= (mult_qcos(35) & mult_qcos(35 downto 1)) - (mult_isin(35) & mult_isin(35 downto 1));

			-- FIRs, выход ограничиваем
			if i_zeroif(35 downto 31) = "00000" or i_zeroif(35 downto 31) = "11111" then
				i_out <= i_zeroif(31 downto 16);  
			else
				if i_zeroif(35) = '0' then
					i_out <= x"7fff";
				else
					i_out <= x"8000";
				end if;
			end if;
			if q_zeroif(35 downto 31) = "00000" or q_zeroif(35 downto 31) = "11111" then
				q_out <= q_zeroif(31 downto 16);  
			else
				if q_zeroif(35) = '0' then
					q_out <= x"7fff";
				else
					q_out <= x"8000";
				end if;
			end if;
			
		end if;
	end if;
	
end process;

end Behavioral;

