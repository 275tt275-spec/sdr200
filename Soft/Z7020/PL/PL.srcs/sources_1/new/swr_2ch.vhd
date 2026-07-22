----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.07.2026 11:41:48
-- Design Name: 
-- Module Name: swr_2ch - Behavioral
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

entity swr_2ch is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc0_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc0_tvalid : in STD_LOGIC;
        s_axis_adc1_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc1_tvalid : in STD_LOGIC
    );
end swr_2ch;

architecture Behavioral of swr_2ch is

begin


end Behavioral;
