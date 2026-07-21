----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.05.2025 12:51:47
-- Design Name: 
-- Module Name: RXA_wide - Behavioral
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
USE ieee.std_logic_unsigned.all;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RXA_wide is
     Port ( 
        m_axis_wb_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end RXA_wide;

architecture Behavioral of RXA_wide is

    component dds16a
    Port (
        aclk : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    end component dds16a;
    
--    COMPONENT cmpy_16x16 IS
--    PORT (
--        aclk : IN STD_LOGIC;
--        s_axis_a_tvalid : IN STD_LOGIC;
--        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        s_axis_b_tvalid : IN STD_LOGIC;
--        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        m_axis_dout_tvalid : OUT STD_LOGIC;
--        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
--    );
--    END COMPONENT cmpy_16x16;
    
    component cmpy_16x16r24 IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_ctrl_tvalid : IN STD_LOGIC;
        s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END component cmpy_16x16r24;
    
    COMPONENT round31to24 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(30 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
    );
    END COMPONENT round31to24;
    
    COMPONENT cic_wide IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_wide;
    
    COMPONENT  fir_wide_1 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_wide_1;
    
    COMPONENT  fir_wide_2 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT fir_wide_2;
    
    signal resetn_r : std_logic := '1';
    signal reset_cic : std_logic;
    signal dds_out : std_logic_vector(31 downto 0);  
    signal mult_in : std_logic_vector(31 downto 0); 
    signal mult_out : std_logic_vector(47 downto 0);  
    signal cic_in_data_0, cic_in_data_1 : std_logic_vector(23 downto 0);   
    signal wb_cic_out_0, wb_cic_out_1 : std_logic_vector(23 downto 0);
    signal cic_out_0, cic_out_1 : std_logic_vector(23 downto 0) := (others => '0');
    signal cic_out_valid : std_logic_vector(1 downto 0);
    signal outwb_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal fir1wb_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir1wb_in_tvalid : STD_LOGIC := '0';
    signal fir1wb_in_tready : STD_LOGIC;
    signal fir1wb_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2wb_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir2wb_in_tready : STD_LOGIC;
    signal fir2wb_in_tvalid : STD_LOGIC;
    signal fir2wb_out_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0) := (others => '0');

begin

dds_0 : dds16a
    PORT MAP (
        aclk => aclk, 
        s_axis_config_tvalid => dds_valid,
        s_axis_config_tdata => dds_value,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_out
    );
    
    mult_in <= s_axis_signal_tdata & s_axis_signal_tdata;
    
process(aclk)
begin
    if rising_edge(aclk) then
        -- Классический полином LFSR x^16 + x^14 + x^13 + x^11 + 1
        lfsr_reg <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);
    end if;
end process;

    ctrl_tdata(0) <= lfsr_reg(0); -- Подаем случайный бит в нулевой разряд
    ctrl_tdata(7 downto 1) <= (others => '0');
    
mult_0 : cmpy_16x16r24
    PORT MAP (
        aclk => aclk, 
        aresetn => aresetn,
        s_axis_a_tvalid => '1',
        s_axis_a_tdata => mult_in,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => dds_out,
        s_axis_ctrl_tvalid => '1',
        s_axis_ctrl_tdata => ctrl_tdata,
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => mult_out
    );
    
    cic_in_data_0 <= mult_out(47 downto 24);
    cic_in_data_1 <= mult_out(23 downto 0);
    reset_cic <= aresetn and resetn_r;
    
process(aclk)
begin
	if rising_edge(aclk) then		
		resetn_r <= aresetn;  
	end if;
end process;

wb_cic_0 : cic_wide
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_0,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => wb_cic_out_0,
        m_axis_data_tvalid => cic_out_valid(0)
    );

wb_cic_1 : cic_wide
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_1,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => wb_cic_out_1,
        m_axis_data_tvalid => cic_out_valid(1)
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	
		if cic_out_valid(0) = '1' then
		  cic_out_0 <= wb_cic_out_0;
		  outwb_valid(0) <= '1';
		end if; 
		if cic_out_valid(1) = '1' then
		  cic_out_1 <= wb_cic_out_1;
		  outwb_valid(1) <= '1';
		end if; 
		
		fir1wb_in_tvalid <= '0';
		if outwb_valid = "11" and fir1wb_in_tready = '1' then
		   outwb_valid <= (others => '0');
		   fir1wb_in_tvalid <= '1';		   
		end if; 
		
	end if;
end process;

    fir1wb_in_tdata <= cic_out_0 & cic_out_1;

wb_fir_1 : fir_wide_1
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir1wb_in_tvalid,
        s_axis_data_tready => fir1wb_in_tready,
        s_axis_data_tdata => fir1wb_in_tdata,
        m_axis_data_tvalid => fir2wb_in_tvalid,
        m_axis_data_tready => fir2wb_in_tready,
        m_axis_data_tdata => fir1wb_out_tdata
    );
    
    fir2wb_in_tdata <= fir1wb_out_tdata(63 downto 40) & fir1wb_out_tdata(31 downto 8);
    
wb_fir_2 : fir_wide_2
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir2wb_in_tvalid,
        s_axis_data_tready => fir2wb_in_tready,
        s_axis_data_tdata => fir2wb_in_tdata,
        m_axis_data_tvalid => m_axis_wb_tvalid,
        m_axis_data_tready => m_axis_wb_tready,
        m_axis_data_tdata => fir2wb_out_tdata
    );
    
    m_axis_wb_tdata <= fir2wb_out_tdata(42 downto 27) & fir2wb_out_tdata(18 downto 3);

end Behavioral;
