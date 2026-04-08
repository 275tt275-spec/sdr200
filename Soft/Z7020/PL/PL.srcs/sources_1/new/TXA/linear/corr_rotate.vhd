----------------------------------------------------------------------------------
-- Create Date:    15:01:02 06/28/2010 
-- Module Name:    corr_rotate - Behavioral 

-- Delays : 27 ticks from phase change, 3 ticks from data change
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity corr_rotate is
    Port ( din_i : in  STD_LOGIC_VECTOR (15 downto 0);
           din_q : in  STD_LOGIC_VECTOR (15 downto 0);
           phi : in  STD_LOGIC_VECTOR (17 downto 0);
           clk : in  STD_LOGIC;
           ce : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           dout_i : out  STD_LOGIC_VECTOR (15 downto 0);
           dout_q : out  STD_LOGIC_VECTOR (15 downto 0));
end corr_rotate;

architecture Behavioral of corr_rotate is

COMPONENT m1_3
	PORT(
		a1 : IN std_logic_vector(17 downto 0);
		b1 : IN std_logic_vector(17 downto 0);
		a2 : IN std_logic_vector(17 downto 0);
		b2 : IN std_logic_vector(17 downto 0);
		op_minus : IN std_logic;
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;          
		dout : OUT std_logic_vector(15 downto 0)
		);
	END COMPONENT;

--component sin_cos_dds
--	port (
--	clk: IN std_logic;
--	phase_in: IN std_logic_VECTOR(17 downto 0);
--	cosine: OUT std_logic_VECTOR(15 downto 0);
--	sine: OUT std_logic_VECTOR(15 downto 0));
--end component;

COMPONENT sin_cos_dds
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_phase_tvalid : IN STD_LOGIC;
    s_axis_phase_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT;

signal sin, cos, i, q,  phi_inv, phi_denorm: std_logic_vector(17 downto 0);
signal sin16, cos16 : std_logic_vector(15 downto 0);
signal m : std_logic_vector(35 downto 0);

signal in_tdata : std_logic_vector(23 downto 0);
signal out_tdata : std_logic_vector(31 downto 0);

begin

m1_2: m1_3 PORT MAP(
		a1 => q,
		b1 => sin,
		a2 => i,
		b2 => cos,
		op_minus => '1',
		clk => clk,
		ce => ce,
		clr => clr,
		dout => dout_i
	);

m2_3: m1_3 PORT MAP(
		a1 => q,
		b1 => cos,
		a2 => i,
		b2 => sin,
		op_minus => '0',
		clk => clk,
		ce => ce,
		clr => clr,
		dout => dout_q
	);

--sincos : sin_cos_dds
--		port map (
--			clk => clk,
--			phase_in => phi_inv,
--			cosine => cos16,
--			sine => sin16
--			);

in_tdata <= "000000" & phi_inv;
cos16 <= out_tdata(15 downto 0);
sin16 <= out_tdata(31 downto 16);
			
sincos : sin_cos_dds
  PORT MAP (
    aclk => clk,
    s_axis_phase_tvalid => '1',
    s_axis_phase_tdata => in_tdata,
    m_axis_data_tvalid => open,
    m_axis_data_tdata => out_tdata
  );
  
i <= din_i(15) & din_i(15) & din_i(15 downto 0);
q <= din_q(15) & din_q(15) & din_q(15 downto 0);

sin <= sin16(15) & sin16 & '0';
cos <= cos16(15) & cos16 & '0';

proc: process(clk)
begin
	if rising_edge(clk) then
-- denormalize and invert angle	
		
--		m <= phi * ("01" & x"9220");
--		phi_denorm <= m(34 downto 17);
--		phi_inv <= -phi_denorm;
		phi_inv <= -phi;
	end if;
end process proc;


end Behavioral;

