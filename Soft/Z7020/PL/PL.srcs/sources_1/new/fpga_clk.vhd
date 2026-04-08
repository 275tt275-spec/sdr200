----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.09.2023 15:13:09
-- Design Name: 
-- Module Name: fpga_clk - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

entity fpga_clk is
    Port ( 
        FPGA_CLK_P : in std_logic; 
        FPGA_CLK_N : in std_logic;
        aclk : out std_logic 
    );
end fpga_clk;

architecture Behavioral of fpga_clk is

    signal fpga_clk : std_logic;
   
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of aclk: SIGNAL is "xilinx.com:signal:clock:1.0 aclk CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of aclk: SIGNAL is "FREQ_HZ 122880000"; 

begin

aclk_bufg : BUFG
    port map (
       O => aclk, -- 1-bit output: Clock output
       I => fpga_clk  -- 1-bit input: Clock input
    );

fpga_clk_ibuf : IBUFDS
    generic map (
        DIFF_TERM => FALSE, -- Differential Termination 
        IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT")
    port map (
        O => fpga_clk,
        I => FPGA_CLK_P,
        IB => FPGA_CLK_N
    );

end Behavioral;
