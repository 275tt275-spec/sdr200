----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.05.2025 11:57:31
-- Design Name: 
-- Module Name: RXA_channel - Behavioral
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
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RXA_channel is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end RXA_channel;

architecture Behavioral of RXA_channel is

    signal resetn_r : std_logic := '1';
    signal reset_cic : std_logic;
    signal dds_out : std_logic_vector(31 downto 0);  
    signal mult_in : std_logic_vector(31 downto 0); 
    signal mult_out : std_logic_vector(47 downto 0);  
    signal cic_in_data_0, cic_in_data_1 : std_logic_vector(23 downto 0);
    signal cic_out_data_0, cic_out_data_1 : std_logic_vector(39 downto 0);
    signal cic_out_0, cic_out_1 : std_logic_vector(39 downto 0);
    signal cic_out : std_logic_vector(36 downto 0);
    signal cic_out_valid_0, cic_out_valid_1 : std_logic;
    signal cic_valid : std_logic_vector(1 downto 0) := (others => '0');
    
    signal fir1_in_tdata : std_logic_vector(31 DOWNTO 0);
    signal fir1_in_tuser : std_logic_vector(0 DOWNTO 0) := "1";
    signal fir1_in_tvalid : std_logic := '0';
    signal fir1_in_tready : std_logic;
    signal fir1_out_tdata : std_logic_vector(39 downto 0);
    signal fir1_out_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir1_out_tvalid : std_logic := '0';
    
    signal fir2_in_tdata : std_logic_vector(31 DOWNTO 0);
    signal fir2_in_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir2_in_tvalid : std_logic := '0';
    signal fir2_in_tready : std_logic;
    signal fir2_out_tdata : std_logic_vector(39 downto 0);
    signal fir2_out_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir2_out_tvalid : std_logic := '0';
        
    component dds16a
    Port (
        aclk : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    end component dds16a;
    
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
    
    COMPONENT cic_nb IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_nb;
    
    COMPONENT round39to32 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(38 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT round39to32;
    
    COMPONENT round38to32 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(37 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT round38to32;
    
    COMPONENT round37to32 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(36 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT round37to32;
    
    COMPONENT fir_ddc_0
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
        event_s_data_chanid_incorrect : OUT STD_LOGIC
    );
    END COMPONENT fir_ddc_0;
    
    COMPONENT fir_ddc_1
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0);
        event_s_data_chanid_incorrect : OUT STD_LOGIC
    );
    END COMPONENT fir_ddc_1;

begin

    reset_cic <= aresetn and resetn_r;

process(aclk)
begin
	if rising_edge(aclk) then
	    resetn_r <= aresetn;	
	end if;
end process;
    
dds_0 : dds16a
    PORT MAP (
      aclk => aclk, 
        s_axis_config_tvalid => dds_valid,
        s_axis_config_tdata => dds_value,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_out
    );
    
    mult_in <= s_axis_signal_tdata & s_axis_signal_tdata;
    
mult_0 : cmpy_16x16
    PORT MAP (
      aclk => aclk, 
        s_axis_a_tvalid => '1',
        s_axis_a_tdata => mult_in,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => dds_out,
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => mult_out
    );
    
    cic_in_data_0 <= mult_out(47 downto 24);
    cic_in_data_1 <= mult_out(23 downto 0);
    
cic_0 : cic_nb
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_0,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_0,
        m_axis_data_tvalid => cic_out_valid_0
    );
    
cic_1 : cic_nb
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_1,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_data_1,
        m_axis_data_tvalid => cic_out_valid_1
    );

process(aclk)
begin
	if rising_edge(aclk) then
	
		if cic_out_valid_0 = '1' then
		  cic_out_0 <= cic_out_data_0;
		  cic_valid(0) <= '1';
		end if; 
		if cic_out_valid_1 = '1' then
		  cic_out_1 <= cic_out_data_1;
		  cic_valid(1) <= '1';
		end if; 
		
		fir1_in_tvalid <= '0'; 		
		if fir1_in_tready = '1' then		
		  if cic_valid = "11" then 		
		      cic_valid <= "00";      		   
		      fir1_in_tuser <= "0";
		      fir1_in_tvalid <= '1';
		  elsif fir1_in_tuser = "0" then
		      fir1_in_tuser <= "1";
		      fir1_in_tvalid <= '1';   
		  end if; 		  
		end if;
		
	end if;
end process; 
    
    cic_out <= cic_out_0(38 downto 2) when fir1_in_tuser = "0" else cic_out_1(38 downto 2);
    
round_cic_0 : round37to32
    PORT MAP (
       i_data => cic_out,
       o_data => fir1_in_tdata(31 downto 0)
    ); 
	
fir1 : fir_ddc_0
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir1_in_tvalid,
        s_axis_data_tready => fir1_in_tready,
        s_axis_data_tuser => fir1_in_tuser,
        s_axis_data_tdata => fir1_in_tdata,
        m_axis_data_tvalid => fir1_out_tvalid,
        m_axis_data_tready => fir2_in_tready,
        m_axis_data_tuser => fir1_out_tuser,
        m_axis_data_tdata => fir1_out_tdata,
        event_s_data_chanid_incorrect => open
    );
         
round_fir1_0 : round39to32
    PORT MAP (
       i_data => fir1_out_tdata(38 downto 0),
       o_data => fir2_in_tdata(31 downto 0)
    );
    
    fir2_in_tuser <= fir1_out_tuser;
    fir2_in_tvalid <= fir1_out_tvalid;
    
fir2 : fir_ddc_1
    PORT MAP  (    
        aclk => aclk,
        s_axis_data_tvalid => fir2_in_tvalid,
        s_axis_data_tready => fir2_in_tready,
        s_axis_data_tuser => fir2_in_tuser,
        s_axis_data_tdata => fir2_in_tdata,
        m_axis_data_tvalid => fir2_out_tvalid,
        m_axis_data_tuser => fir2_out_tuser,
        m_axis_data_tdata => fir2_out_tdata,
        event_s_data_chanid_incorrect => open
    );      
     
round_fir2_0 : round38to32
    PORT MAP (
       i_data => fir2_out_tdata(37 downto 0),
       o_data => m_axis_data_tdata(31 downto 0)
    ); 
    
    m_axis_data_tuser <= fir2_out_tuser;
    m_axis_data_tvalid <= fir2_out_tvalid; 
    
end Behavioral;
