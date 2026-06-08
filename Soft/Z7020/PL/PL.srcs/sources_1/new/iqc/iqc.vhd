----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.06.2026 14:33:50
-- Design Name: 
-- Module Name: iqc - Behavioral
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

entity iqc is
    Port (
        in_i : in  STD_LOGIC_VECTOR (17 downto 0);
        in_q : in  STD_LOGIC_VECTOR (17 downto 0);
        adc : in  STD_LOGIC_VECTOR (15 downto 0); 
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        outiq_0 : out  STD_LOGIC_VECTOR (31 downto 0);
        out_valid_0 : out STD_LOGIC;
        outiq_1 : out  STD_LOGIC_VECTOR (31 downto 0);
        out_valid_1 : out STD_LOGIC;
        aresetn : in std_logic;
        aclk : in std_logic
    );
end iqc;

architecture Behavioral of iqc is

    COMPONENT cmpy_16x16 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT cmpy_16x16;
    
    COMPONENT ddc is
    PORT ( 
        in_i : in  STD_LOGIC_VECTOR (17 downto 0);
        in_q : in  STD_LOGIC_VECTOR (17 downto 0);
        out_i : out  STD_LOGIC_VECTOR (23 downto 0);
        out_q : out  STD_LOGIC_VECTOR (23 downto 0);
        out_valid : out  STD_LOGIC;
        cic_gain : in  STD_LOGIC_VECTOR (1 downto 0);
        aresetn : in std_logic;
        aclk : in std_logic
    );
    END COMPONENT ddc;
    
    signal mult_in : std_logic_vector(31 downto 0); 
    signal mult_out : std_logic_vector(47 downto 0); 
    signal ddc0_i, ddc0_q : std_logic_vector(17 downto 0);  
    signal ddc1_i, ddc1_q : std_logic_vector(17 downto 0);  
    signal out_i_0, out_q_0 : std_logic_vector(23 downto 0);  
    signal out_i_1, out_q_1 : std_logic_vector(23 downto 0); 

begin

    mult_in <= adc & adc;

mult_0 : cmpy_16x16
    PORT MAP (
        aclk => aclk, 
        s_axis_a_tvalid => '1',
        s_axis_a_tdata => mult_in,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => s_axis_dds_tdata,
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => mult_out
    );
    
    ddc0_i <= mult_out(47 downto 30);
    ddc0_q <= mult_out(23 downto 6);
    ddc1_i <= in_i;
    ddc1_q <= in_q;

    
ddc_0 : ddc
    PORT MAP (
        in_i => ddc0_i,
        in_q => ddc0_q,
        out_i => out_i_0,
        out_q => out_q_0,
        out_valid => out_valid_0,
        cic_gain => "11",
        aresetn => aresetn,
        aclk => aclk
    );
    
ddc_1 : ddc
    PORT MAP (
        in_i => ddc1_i,
        in_q => ddc1_q,
        out_i => out_i_1,
        out_q => out_q_1,
        out_valid => out_valid_1,
        cic_gain => "00",
        aresetn => aresetn,
        aclk => aclk
    );
    
    outiq_0 <= out_i_0(21 downto 6) & out_q_0(21 downto 6);
    outiq_1 <= out_i_1(21 downto 6) & out_q_1(21 downto 6);

end Behavioral;
