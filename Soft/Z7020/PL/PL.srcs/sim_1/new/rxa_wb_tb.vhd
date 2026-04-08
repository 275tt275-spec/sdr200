----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.10.2025 18:18:44
-- Design Name: 
-- Module Name: rxa_wb_tb - Behavioral
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

entity rxa_wb_tb is
--  Port ( );
end rxa_wb_tb;

architecture Behavioral of rxa_wb_tb is

 COMPONENT RXA_wide is
     Port ( 
        m_axis_wb_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
 END COMPONENT RXA_wide;
 
 COMPONENT dds_compiler_0 IS
  PORT (
    aclk : IN STD_LOGIC;
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    m_axis_phase_tvalid : OUT STD_LOGIC;
    m_axis_phase_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT dds_compiler_0;
 
    signal m_axis_wb_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal m_axis_wb_tvalid : STD_LOGIC;
    signal s_axis_signal_tdata : STD_LOGIC_VECTOR (15 downto 0);
    signal dds_value : STD_LOGIC_VECTOR (31 downto 0);
    signal dds_valid : STD_LOGIC := '0';
    signal aresetn : STD_LOGIC;
    signal aclk : STD_LOGIC;
    
    constant FPGA_CLK_period : time := 10 ns;

begin

uut: RXA_wide PORT MAP (
        m_axis_wb_tdata => m_axis_wb_tdata,
        m_axis_wb_tvalid => m_axis_wb_tvalid,
        s_axis_signal_tdata => s_axis_signal_tdata,
        dds_value => dds_value,
        dds_valid => dds_valid,
        aresetn => aresetn,
        aclk => aclk
    );
    
dds: dds_compiler_0 PORT MAP (
        aclk => aclk,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => s_axis_signal_tdata,
        m_axis_phase_tvalid => open,
        m_axis_phase_tdata => open
    );
    
process
begin
	aclk <= '1';
	wait for FPGA_CLK_period/2;
	aclk <= '0';
	wait for FPGA_CLK_period/2;
end process;

	dds_value <= x"19999999";

process
begin
	aresetn <= '0';
	wait for 4 * FPGA_CLK_period;
	aresetn <= '1';
	wait for 2 * FPGA_CLK_period;
	dds_valid <= '1';
	wait for FPGA_CLK_period;
	dds_valid <= '0';
	wait;
end process;


end Behavioral;
