----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.07.2026 12:21:05
-- Design Name: 
-- Module Name: swr_channel - Behavioral
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

entity swr_channel is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        m_iq_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_iq_tvalid : out STD_LOGIC;
        m_rssi_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_angle_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_tvalid : out STD_LOGIC;
        cic_gain : in  STD_LOGIC_VECTOR (1 downto 0)
    );
end swr_channel;

architecture Behavioral of swr_channel is

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

    COMPONENT cic_swr IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_swr;
    
    COMPONENT fir_swr_0 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_swr_0;
    
    COMPONENT fir_swr_1 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_swr_1;
    
    COMPONENT cordic_swr
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_cartesian_tvalid : IN STD_LOGIC;
        s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT cordic_swr;
    
    signal resetn_r : std_logic := '1';
    signal reset_cic : std_logic;
    signal mult_in : std_logic_vector(31 downto 0); 
    signal mult_out : std_logic_vector(47 downto 0);
    signal cic_out_data_0, cic_out_data_1 : std_logic_vector(23 downto 0);
    signal cic_out_valid_0, cic_out_valid_1 : std_logic;
    signal cic_out_0, cic_out_1 : std_logic_vector(23 downto 0) := (others => '0');
    signal cic_valid_0, cic_valid_1 : std_logic := '0';
    signal fir1_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir1_in_tvalid : STD_LOGIC := '0';
    signal fir1_in_tready : STD_LOGIC;
    signal fir1_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir2_in_tvalid : STD_LOGIC := '0';
    signal fir2_in_tready : STD_LOGIC;
    signal fir2_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2_out_tvalid : STD_LOGIC := '0';
    signal cordic_in_tvalid : STD_LOGIC := '0';
    signal cordic_in_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tdata : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tvalid : STD_LOGIC;

begin

    reset_cic <= aresetn and resetn_r;
    
process(aclk)
begin
	if rising_edge(aclk) then
	    resetn_r <= aresetn;	
	end if;
end process;

    mult_in <= s_axis_adc_tdata & s_axis_adc_tdata;

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
    
cic_0 : cic_swr
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => mult_out(23 downto 8),
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_0,
        m_axis_data_tvalid => cic_out_valid_0
    );
    
cic_1 : cic_swr
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => mult_out(47 downto 32),
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_1,
        m_axis_data_tvalid => cic_out_valid_1
    );
    
process(aclk)
begin
	if rising_edge(aclk) then	
		if cic_out_valid_0 = '1' then
            case cic_gain is
            when "01" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 1));
            when "10" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 2));
            when "11" => cic_out_0 <= std_logic_vector(shift_left(signed(cic_out_data_0), 3));
            when others => cic_out_0 <= cic_out_data_0;
		    end case;
		  cic_valid_0 <= '1';
		end if; 
		if cic_out_valid_1 = '1' then
            case cic_gain is
            when "01" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 1));
            when "10" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 2));
            when "11" => cic_out_1 <= std_logic_vector(shift_left(signed(cic_out_data_1), 3));
            when others => cic_out_1 <= cic_out_data_1;
		    end case;
		  cic_valid_1 <= '1';
		end if; 		
		fir1_in_tvalid <= '0';
		if cic_valid_0 = '1' and cic_valid_1 = '1' and fir1_in_tready = '1' then
		   cic_valid_0 <= '0';
		   cic_valid_1 <= '1';
		   fir1_in_tvalid <= '1';		   
		end if; 		
	end if;
end process;
    
    fir1_in_tdata <= cic_out_0 & cic_out_1;   
    
fir_0 : fir_swr_0
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir1_in_tvalid,
        s_axis_data_tready => fir1_in_tready,
        s_axis_data_tdata => fir1_in_tdata,
        m_axis_data_tvalid => fir2_in_tvalid,
        m_axis_data_tready => fir2_in_tready,
        m_axis_data_tdata => fir1_out_tdata
    );
    
fir_1 : fir_swr_1
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir2_in_tvalid,
        s_axis_data_tready => fir2_in_tready,
        s_axis_data_tdata => fir2_in_tdata,
        m_axis_data_tvalid => fir2_out_tvalid,
        m_axis_data_tdata => fir2_out_tdata
    );
    
    cordic_in_tdata <= fir2_out_tdata(63) & fir2_out_tdata(63 downto 41) & fir2_out_tdata(31) & fir2_out_tdata(31 downto 9);
    cordic_in_tvalid <= fir2_out_tvalid;
    
cordic_0 : cordic_swr
    PORT MAP (
        aclk => aclk,
        s_axis_cartesian_tvalid => cordic_in_tvalid,
        s_axis_cartesian_tdata => cordic_in_tdata,
        m_axis_dout_tvalid => cordic_out_tvalid,
        m_axis_dout_tdata => cordic_out_tdata
    );

    m_rssi_tdata <= cordic_out_tdata(22 downto 7);
    m_angle_tdata <= cordic_out_tdata(46 downto 31);
    m_tvalid <= cordic_out_tvalid;  
    m_iq_tdata <= fir2_out_tdata(63 downto 48) & fir2_out_tdata(31 downto 16);
    m_iq_tvalid <= fir2_out_tvalid;
    
end Behavioral;
