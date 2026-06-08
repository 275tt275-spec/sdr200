----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.06.2026 14:44:59
-- Design Name: 
-- Module Name: ddc - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ddc is
  Port ( 
    in_i : in  STD_LOGIC_VECTOR (17 downto 0);
    in_q : in  STD_LOGIC_VECTOR (17 downto 0);
    out_i : out  STD_LOGIC_VECTOR (23 downto 0);
    out_q : out  STD_LOGIC_VECTOR (23 downto 0);
    out_valid : out  STD_LOGIC;
    cic_gain : in  STD_LOGIC_VECTOR (1 downto 0);
    aresetn : in std_logic;
    aclk : in std_logic
  );
end ddc;

architecture Behavioral of ddc is
        
    COMPONENT cic_linear IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_linear;
    
    COMPONENT fir_linear_0 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_linear_0;
    
    COMPONENT fir_linear_1 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_linear_1;
    
    signal resetn_r : std_logic := '1';
    signal reset_cic : std_logic;
    signal cic_in_data_0, cic_in_data_1 : std_logic_vector(23 downto 0);
    signal cic_out_data_0, cic_out_data_1 : std_logic_vector(23 downto 0);
    signal cic_out_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal cic_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal cic_out_0, cic_out_1 : std_logic_vector(23 downto 0) := (others => '0');
    signal fir1_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir1_in_tvalid : STD_LOGIC := '0';
    signal fir1_in_tready : STD_LOGIC;
    signal fir1_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir2_in_tvalid : STD_LOGIC := '0';
    signal fir2_in_tready : STD_LOGIC;
    signal fir2_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2_out_tvalid : STD_LOGIC := '0';

begin

    reset_cic <= aresetn and resetn_r;
    
process(aclk)
begin
	if rising_edge(aclk) then
	    resetn_r <= aresetn;	
	end if;
end process;

    cic_in_data_0 <= std_logic_vector(resize(signed(in_i), 24));
    cic_in_data_1 <= std_logic_vector(resize(signed(in_q), 24));

cic_0 : cic_linear
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_0,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_0,
        m_axis_data_tvalid => cic_out_valid(0)
    );
    
cic_1 : cic_linear
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_1,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_1,
        m_axis_data_tvalid => cic_out_valid(1)
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	
		if cic_out_valid(0) = '1' then
            case cic_gain is
            when "01" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 1));
            when "10" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 2));
            when "11" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 3));
            when others => cic_out_0 <= cic_out_data_0;
		    end case;
		  cic_valid(0) <= '1';
		end if; 
		if cic_out_valid(1) = '1' then
            case cic_gain is
            when "01" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 1));
            when "10" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 2));
            when "11" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 3));
            when others => cic_out_1 <= cic_out_data_1;
		    end case;
		  cic_valid(1) <= '1';
		end if; 
		
		fir1_in_tvalid <= '0';
		if cic_valid = "11" and fir1_in_tready = '1' then
		   cic_valid <= (others => '0');
		   fir1_in_tvalid <= '1';		   
		end if; 
		
	end if;
end process;

    fir1_in_tdata <= cic_out_0 & cic_out_1;   
    
fir_0 : fir_linear_0
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir1_in_tvalid,
        s_axis_data_tready => fir1_in_tready,
        s_axis_data_tdata => fir1_in_tdata,
        m_axis_data_tvalid => fir2_in_tvalid,
        m_axis_data_tready => fir2_in_tready,
        m_axis_data_tdata => fir1_out_tdata
    );
    
    fir2_in_tdata <= fir1_out_tdata(63 downto 40) & fir1_out_tdata(31 downto 8);
    
fir_1 : fir_linear_1
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir2_in_tvalid,
        s_axis_data_tready => fir2_in_tready,
        s_axis_data_tdata => fir2_in_tdata,
        m_axis_data_tvalid => fir2_out_tvalid,
        m_axis_data_tdata => fir2_out_tdata
    );
    
    out_i <= fir2_out_tdata(63 downto 40);
    out_q <= fir2_out_tdata(31 downto 8);
    out_valid <= fir2_out_tvalid;

end Behavioral;
