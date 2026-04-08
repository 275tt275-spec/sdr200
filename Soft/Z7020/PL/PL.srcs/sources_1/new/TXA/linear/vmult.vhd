----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:29:04 03/12/2025 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_signed.ALL;

entity vmult is
	generic(
		A_SIZE : integer := 8;
		B_SIZE : integer := 8
	);
	Port (
		clk : in  STD_LOGIC;
      a_i : in  STD_LOGIC_VECTOR (A_SIZE-1 downto 0);
      a_q : in  STD_LOGIC_VECTOR (A_SIZE-1 downto 0);
      b_i : in  STD_LOGIC_VECTOR (B_SIZE-1 downto 0);
      b_q : in  STD_LOGIC_VECTOR (B_SIZE-1 downto 0);
      dout_i : out  STD_LOGIC_VECTOR (A_SIZE+B_SIZE-1 downto 0);
      dout_q : out  STD_LOGIC_VECTOR (A_SIZE+B_SIZE-1 downto 0)
	);
end vmult;

architecture Behavioral of vmult is

signal a_ir, a_qr : STD_LOGIC_VECTOR (A_SIZE-1 downto 0);
signal b_ir, b_qr : STD_LOGIC_VECTOR (B_SIZE-1 downto 0);
signal m_aibi, m_aibq, m_aqbi, m_aqbq : STD_LOGIC_VECTOR (A_SIZE+B_SIZE-1 downto 0);

begin

process(clk)
begin
	if rising_edge(clk) then
		a_ir <= a_i;
		a_qr <= a_q;
		b_ir <= b_i;
		b_qr <= b_q;
		m_aibi <= a_ir * b_ir;
		m_aibq <= a_ir * b_qr;
		m_aqbi <= a_qr * b_ir;
		m_aqbq <= a_qr * b_qr;
		dout_i <= m_aibi - m_aqbq;
		dout_q <= m_aibq + m_aqbi;
	end if;
end process;	

end Behavioral;

