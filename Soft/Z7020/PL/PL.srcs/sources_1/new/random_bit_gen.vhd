----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.01.2019 17:30:24
-- Design Name: 
-- Module Name: random_bit_gen - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lfsr_bit is
    Port ( resetn : in STD_LOGIC;
           lfsr_valid : in STD_LOGIC;
           rbit_out : out STD_LOGIC);
end lfsr_bit;

architecture rtl of lfsr_bit is
   signal lfsr     : std_logic_vector (15 downto 0) := x"ACE1"; -- Any nonzero start state will work.
   signal feedback : std_logic;

 begin

    feedback <= lfsr(3) xor lfsr(12) xor lfsr(14) xor lfsr(15);  -- Xilinx Taps for Maximum-Length LFSR Counters
--   feedback <= lfsr(10) xor lfsr(12) xor lfsr(13) xor lfsr(15);  -- x^{16}+x^{14}+x^{13}+x^{11}+1 Fibonacci LFSRs
    
   sr_pr : process (lfsr_valid) 
   begin
     if (rising_edge(lfsr_valid)) then
       if (resetn = '0') then
         lfsr <= x"ACE1";
       else
         lfsr <= lfsr(14 downto 0) & feedback;
       end if; 
     end if;
   end process sr_pr;

   rbit_out <= lfsr(0);
  
 end architecture;
