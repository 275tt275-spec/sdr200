----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:35:48 08/13/2014 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;


entity m1_3 is
    Port ( a1 : in  STD_LOGIC_VECTOR (17 downto 0);
           b1 : in  STD_LOGIC_VECTOR (17 downto 0);
           a2 : in  STD_LOGIC_VECTOR (17 downto 0);
           b2 : in  STD_LOGIC_VECTOR (17 downto 0);
			  op_minus : std_logic;
           clk : in  STD_LOGIC;
           ce : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           dout : out  STD_LOGIC_VECTOR (15 downto 0));
end m1_3;

architecture Behavioral of m1_3 is
signal c1, p1, p2 : std_logic_vector(47 downto 0);
signal a1_30, a2_30 : std_logic_vector(29 downto 0);
signal alumode : std_logic_vector(3 downto 0);

begin

m1 : DSP48E1
	generic map (
	-- Feature Control Attributes: Data Path Selection
		A_INPUT => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
		B_INPUT => "DIRECT", -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
		USE_DPORT => FALSE, -- Select D port usage (TRUE or FALSE)
		USE_MULT => "MULTIPLY", -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
	-- Pattern Detector Attributes: Pattern Detection Configuration
		AUTORESET_PATDET => "NO_RESET", -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
		MASK => X"3fffffffffff", -- 48-bit mask value for pattern detect (1=ignore)
		PATTERN => X"000000000000", -- 48-bit pattern match for pattern detect
		SEL_MASK => "MASK", -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
		SEL_PATTERN => "PATTERN", -- Select pattern value ("PATTERN" or "C")
		USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")
	-- Register Control Attributes: Pipeline Register Configuration
		ACASCREG => 1, -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
		ADREG => 1, -- Number of pipeline stages for pre-adder (0 or 1)
		ALUMODEREG => 1, -- Number of pipeline stages for ALUMODE (0 or 1)
		AREG => 2, -- Number of pipeline stages for A (0, 1 or 2)
		BCASCREG => 1, -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
		BREG => 2, -- Number of pipeline stages for B (0, 1 or 2)
		CARRYINREG => 1, -- Number of pipeline stages for CARRYIN (0 or 1))
		CARRYINSELREG => 1, -- Number of pipeline stages for CARRYINSEL (0 or 1)
		CREG => 1, -- Number of pipeline stages for C (0 or 1)
		DREG => 1, -- Number of pipeline stages for D (0 or 1)
		INMODEREG => 1, -- Number of pipeline stages for INMODE (0 or 1)
		MREG => 1, -- Number of multiplier pipeline stages (0 or 1)
		OPMODEREG => 1, -- Number of pipeline stages for OPMODE (0 or 1)
		PREG => 1, -- Number of pipeline stages for P (0 or 1)
		USE_SIMD => "ONE48" -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	)
	port map (
	-- Cascade: 30-bit (each) output: Cascade Ports
		ACOUT => open, -- 30-bit output: A port cascade output
		BCOUT => open, -- 18-bit output: B port cascade output
		CARRYCASCOUT => open, -- 1-bit output: Cascade carry output
		MULTSIGNOUT => open, -- 1-bit output: Multiplier sign cascade output
		PCOUT => open, -- 48-bit output: Cascade output
	-- Control: 1-bit (each) output: Control Inputs/Status Bits
		OVERFLOW => open, -- 1-bit output: Overflow in add/acc output
		PATTERNBDETECT => open, -- 1-bit output: Pattern bar detect output
		PATTERNDETECT => open, -- 1-bit output: Pattern detect output
		UNDERFLOW => open, -- 1-bit output: Underflow in add/acc output
	-- Data: 4-bit (each) output: Data Ports
		CARRYOUT => open, -- 4-bit output: Carry output
		P => p1, -- 48-bit output: Primary data output
	-- Cascade: 30-bit (each) input: Cascade Ports
		ACIN => (others => '0'), -- 30-bit input: A cascade data input
		BCIN => (others => '0'), -- 18-bit input: B cascade input
		CARRYCASCIN => '0', -- 1-bit input: Cascade carry input
		MULTSIGNIN => '0', -- 1-bit input: Multiplier sign input
		PCIN => (others => '0'), -- 48-bit input: P cascade input
	-- Control: 4-bit (each) input: Control Inputs/Status Bits
		ALUMODE => alumode, -- 4-bit input: ALU control input
		CARRYINSEL => "000", -- 3-bit input: Carry select input
		CEINMODE => '1', -- 1-bit input: Clock enable input for INMODEREG
		CLK => clk, -- 1-bit input: Clock input
		INMODE => "00000", -- 5-bit input: INMODE control input
		OPMODE => "0110101", -- 7-bit input: Operation mode input
		RSTINMODE => '0', -- 1-bit input: Reset input for INMODEREG
	-- Data: 30-bit (each) input: Data Ports
		A => a1_30, -- 30-bit input: A data input
		B => b1, -- 18-bit input: B data input
		C => c1, -- 48-bit input: C data input
		CARRYIN => '0', -- 1-bit input: Carry input signal
		D => (others => '0'), -- 25-bit input: D data input
	-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
		CEA1 => ce, -- 1-bit input: Clock enable input for 1st stage AREG
		CEA2 => ce, -- 1-bit input: Clock enable input for 2nd stage AREG
		CEAD => ce, -- 1-bit input: Clock enable input for ADREG
		CEALUMODE => ce, -- 1-bit input: Clock enable input for ALUMODERE
		CEB1 => ce, -- 1-bit input: Clock enable input for 1st stage BREG
		CEB2 => ce, -- 1-bit input: Clock enable input for 2nd stage BREG
		CEC => ce, -- 1-bit input: Clock enable input for CREG
		CECARRYIN => ce, -- 1-bit input: Clock enable input for CARRYINREG
		CECTRL => ce, -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
		CED => '0', -- 1-bit input: Clock enable input for DREG
		CEM => ce, -- 1-bit input: Clock enable input for MREG
		CEP => ce, -- 1-bit input: Clock enable input for PREG
		RSTA => clr, -- 1-bit input: Reset input for AREG
		RSTALLCARRYIN => '0', -- 1-bit input: Reset input for CARRYINREG
		RSTALUMODE => '0', -- 1-bit input: Reset input for ALUMODEREG
		RSTB => clr, -- 1-bit input: Reset input for BREG
		RSTC => '0', -- 1-bit input: Reset input for CREG
		RSTCTRL => '0', -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
		RSTD => '0', -- 1-bit input: Reset input for DREG and ADREG
		RSTM => clr, -- 1-bit input: Reset input for MREG
		RSTP => clr -- 1-bit input: Reset input for PREG
	);
	
m2 : DSP48E1
	generic map (
	-- Feature Control Attributes: Data Path Selection
		A_INPUT => "DIRECT", -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
		B_INPUT => "DIRECT", -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
		USE_DPORT => FALSE, -- Select D port usage (TRUE or FALSE)
		USE_MULT => "MULTIPLY", -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
	-- Pattern Detector Attributes: Pattern Detection Configuration
		AUTORESET_PATDET => "NO_RESET", -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
		MASK => X"3fffffffffff", -- 48-bit mask value for pattern detect (1=ignore)
		PATTERN => X"000000000000", -- 48-bit pattern match for pattern detect
		SEL_MASK => "MASK", -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
		SEL_PATTERN => "PATTERN", -- Select pattern value ("PATTERN" or "C")
		USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")
	-- Register Control Attributes: Pipeline Register Configuration
		ACASCREG => 1, -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
		ADREG => 1, -- Number of pipeline stages for pre-adder (0 or 1)
		ALUMODEREG => 1, -- Number of pipeline stages for ALUMODE (0 or 1)
		AREG => 1, -- Number of pipeline stages for A (0, 1 or 2)
		BCASCREG => 1, -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
		BREG => 1, -- Number of pipeline stages for B (0, 1 or 2)
		CARRYINREG => 1, -- Number of pipeline stages for CARRYIN (0 or 1))
		CARRYINSELREG => 1, -- Number of pipeline stages for CARRYINSEL (0 or 1)
		CREG => 1, -- Number of pipeline stages for C (0 or 1)
		DREG => 1, -- Number of pipeline stages for D (0 or 1)
		INMODEREG => 1, -- Number of pipeline stages for INMODE (0 or 1)
		MREG => 0, -- Number of multiplier pipeline stages (0 or 1)
		OPMODEREG => 1, -- Number of pipeline stages for OPMODE (0 or 1)
		PREG => 1, -- Number of pipeline stages for P (0 or 1)
		USE_SIMD => "ONE48" -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	)
	port map (
	-- Cascade: 30-bit (each) output: Cascade Ports
		ACOUT => open, -- 30-bit output: A port cascade output
		BCOUT => open, -- 18-bit output: B port cascade output
		CARRYCASCOUT => open, -- 1-bit output: Cascade carry output
		MULTSIGNOUT => open, -- 1-bit output: Multiplier sign cascade output
		PCOUT => open, -- 48-bit output: Cascade output
	-- Control: 1-bit (each) output: Control Inputs/Status Bits
		OVERFLOW => open, -- 1-bit output: Overflow in add/acc output
		PATTERNBDETECT => open, -- 1-bit output: Pattern bar detect output
		PATTERNDETECT => open, -- 1-bit output: Pattern detect output
		UNDERFLOW => open, -- 1-bit output: Underflow in add/acc output
	-- Data: 4-bit (each) output: Data Ports
		CARRYOUT => open, -- 4-bit output: Carry output
		P => p2, -- 48-bit output: Primary data output
	-- Cascade: 30-bit (each) input: Cascade Ports
		ACIN => (others => '0'), -- 30-bit input: A cascade data input
		BCIN => (others => '0'), -- 18-bit input: B cascade input
		CARRYCASCIN => '0', -- 1-bit input: Cascade carry input
		MULTSIGNIN => '0', -- 1-bit input: Multiplier sign input
		PCIN => (others => '0'), -- 48-bit input: P cascade input
	-- Control: 4-bit (each) input: Control Inputs/Status Bits
		ALUMODE => "0000", -- 4-bit input: ALU control input
		CARRYINSEL => "000", -- 3-bit input: Carry select input
		CEINMODE => '1', -- 1-bit input: Clock enable input for INMODEREG
		CLK => clk, -- 1-bit input: Clock input
		INMODE => "10001", -- 5-bit input: INMODE control input
		OPMODE => "0000101", -- 7-bit input: Operation mode input
		RSTINMODE => '0', -- 1-bit input: Reset input for INMODEREG
	-- Data: 30-bit (each) input: Data Ports
		A => a2_30, -- 30-bit input: A data input
		B => b2, -- 18-bit input: B data input
		C => (others => '0'), -- 48-bit input: C data input
		CARRYIN => '0', -- 1-bit input: Carry input signal
		D => (others => '0'), -- 25-bit input: D data input
	-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
		CEA1 => ce, -- 1-bit input: Clock enable input for 1st stage AREG
		CEA2 => ce, -- 1-bit input: Clock enable input for 2nd stage AREG
		CEAD => ce, -- 1-bit input: Clock enable input for ADREG
		CEALUMODE => ce, -- 1-bit input: Clock enable input for ALUMODERE
		CEB1 => ce, -- 1-bit input: Clock enable input for 1st stage BREG
		CEB2 => ce, -- 1-bit input: Clock enable input for 2nd stage BREG
		CEC => ce, -- 1-bit input: Clock enable input for CREG
		CECARRYIN => ce, -- 1-bit input: Clock enable input for CARRYINREG
		CECTRL => ce, -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
		CED => '0', -- 1-bit input: Clock enable input for DREG
		CEM => ce, -- 1-bit input: Clock enable input for MREG
		CEP => ce, -- 1-bit input: Clock enable input for PREG
		RSTA => clr, -- 1-bit input: Reset input for AREG
		RSTALLCARRYIN => '0', -- 1-bit input: Reset input for CARRYINREG
		RSTALUMODE => '0', -- 1-bit input: Reset input for ALUMODEREG
		RSTB => clr, -- 1-bit input: Reset input for BREG
		RSTC => '0', -- 1-bit input: Reset input for CREG
		RSTCTRL => '0', -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
		RSTD => '0', -- 1-bit input: Reset input for DREG and ADREG
		RSTM => clr, -- 1-bit input: Reset input for MREG
		RSTP => clr -- 1-bit input: Reset input for PREG
	);

a1_30 <= "00000" & sxt(a1, 25);
a2_30 <= "00000" & sxt(a2, 25);
c1 <= sxt(p2, 48);

alumode <= "0000" when op_minus = '0' else
           "0011";
			 
just_proc : process(clk)
begin
	if rising_edge(clk) then
		if ce = '1' then
--			
-- Check for overflow			
--
			if p1(47 downto 31) = "00000000000000000" or p1(47 downto 31) = "11111111111111111" then
				dout <= p1(31 downto 16);
			else
				if p1(47) = '0' then
					dout <= x"7fff";
				else
					dout <= x"8000";
				end if;
			end if;
		end if;	--ce
	end if; --clk
	
end process just_proc;

end Behavioral;

