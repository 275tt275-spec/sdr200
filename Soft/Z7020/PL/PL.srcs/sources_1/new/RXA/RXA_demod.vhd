----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.05.2025 16:52:12
-- Design Name: 
-- Module Name: RXA_demod - Behavioral
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
-- -- -- Select demodulator for RXA bits[0:3] 
-- -- -- 0 j3e 2400 yes offset 1850 Hz
-- -- -- 1 a3e
-- -- -- 2 a1a    
-- -- -- 3 f3e         
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RXA_demod is
Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0); 
       s_axis_tvalid : in STD_LOGIC;      
       m_axis_demod_tdata : out STD_LOGIC_VECTOR (23 downto 0); -- out in s24
       m_axis_demod_tvalid : out STD_LOGIC;
       m_axis_rssi_tdata : out STD_LOGIC_VECTOR (31 downto 0);  -- out in s32
       m_axis_rssi_tvalid : out STD_LOGIC;
       dds_config_16_data : in std_logic_vector(15 downto 0);
       dds_config_16_valid : in std_logic;
       modulation : in STD_LOGIC_VECTOR (1 downto 0);
       j3e_lsb : in STD_LOGIC
   );
end RXA_demod;

architecture Behavioral of RXA_demod is

    COMPONENT cordic_a3e
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_cartesian_tvalid : IN STD_LOGIC;
        s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT cordic_a3e;
    
    COMPONENT dds_16_24 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT dds_16_24;
    
    COMPONENT cmpy_32_24 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT cmpy_32_24;
  
    constant f3e_positive_threshold : integer := 536870912;
    constant f3e_negative_threshold : integer := -536870912;
    constant f3e_full_scale_value : integer := 1073741823;
    signal cordic_in_tdata : std_logic_vector(63 downto 0);
    signal cordic_in_tvalid : std_logic;
    signal dds_data : std_logic_vector(47 DOWNTO 0);
    signal config_tvalid : std_logic := '0';
    signal config_tdata : std_logic_vector(15 DOWNTO 0) := x"1799";
    signal j3e_in_tdata : std_logic_vector(63 downto 0);
    signal a3e_out_tdata : std_logic_vector(63 downto 0);
    signal a3e_out_tvalid : std_logic;
    signal j3e_out_tdata : std_logic_vector(63 downto 0);
    signal j3e_out_tvalid : std_logic;
    signal f3e_prv_tdata : std_logic_vector(31 downto 0); 
    signal f3e_cur_tdata : std_logic_vector(31 downto 0); 
    signal f3e_out_tdata : std_logic_vector(31 downto 0); 
    signal f3e_demod : std_logic_vector(31 downto 0);  
    signal demod_out_data : std_logic_vector(31 downto 0);   
    signal demod_out_en : std_logic := '0';

begin

process(aclk)
begin
	if rising_edge(aclk) then	
	    cordic_in_tvalid <= '0';	
		if s_axis_tvalid = '1' then
		    if s_axis_tuser = "0" then				   		
			    cordic_in_tdata(31 downto 0) <= s_axis_tdata(31) & s_axis_tdata(31 downto 1);
			    if j3e_lsb = '0' then
			         j3e_in_tdata(31 downto 0) <= s_axis_tdata;
			    else
			         j3e_in_tdata(63 downto 32) <= s_axis_tdata;
			    end if;     
			else
			    cordic_in_tdata(63 downto 32) <= s_axis_tdata(31) & s_axis_tdata(31 downto 1);
                if j3e_lsb = '1' then
			         j3e_in_tdata(31 downto 0) <= s_axis_tdata;
			    else
			         j3e_in_tdata(63 downto 32) <= s_axis_tdata;
			    end if;  
			    cordic_in_tvalid <= '1';
			end if;    	           
		end if;  
	end if;
end process;
    
dds_0 : dds_16_24
    PORT MAP (
        aclk => cordic_in_tvalid,
        s_axis_config_tvalid => config_tvalid,
        s_axis_config_tdata => config_tdata,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_data
    );    
    
cmply_0 : cmpy_32_24 
    PORT MAP (
        aclk => aclk,
        s_axis_a_tvalid => cordic_in_tvalid,
        s_axis_a_tdata => j3e_in_tdata,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => dds_data,
        m_axis_dout_tvalid => j3e_out_tvalid,
        m_axis_dout_tdata => j3e_out_tdata
    );
                    
a3e_cordic_0 : cordic_a3e
    PORT MAP (
      aclk => aclk,
      s_axis_cartesian_tvalid => cordic_in_tvalid,
      s_axis_cartesian_tdata => cordic_in_tdata,
      m_axis_dout_tvalid => a3e_out_tvalid,
      m_axis_dout_tdata => a3e_out_tdata
    );
        
process(aclk)
begin
	if rising_edge(aclk) then
	    demod_out_en <= '0';
	    if modulation = "01" then       -- a3e
	        if a3e_out_tvalid = '1' then
                demod_out_data <= a3e_out_tdata(31 downto 0);
                demod_out_en <= '1';
            end if;  
        elsif modulation = "11" then     -- f3e   
            if a3e_out_tvalid = '1' then
                f3e_cur_tdata <= a3e_out_tdata(63 downto 32);
                f3e_prv_tdata <= f3e_cur_tdata;
                f3e_out_tdata <= f3e_cur_tdata - f3e_prv_tdata;
                demod_out_data <= f3e_demod;
                demod_out_en <= '1';
            end if;
          else   -- j3e
	           demod_out_data <= j3e_out_tdata(31 downto 0) + j3e_out_tdata(63 downto 32);  
	           demod_out_en <= j3e_out_tvalid;     
          end if;      
		
		if demod_out_en = '1' then
		    config_tvalid <= '0';
		end if;    
		
		if dds_config_16_valid = '1' then
		    config_tdata <= dds_config_16_data;
		    config_tvalid <= '1';
		end if;

	end if;
end process;

    f3e_demod <= f3e_out_tdata - f3e_full_scale_value when (f3e_out_tdata > f3e_positive_threshold) else
                 f3e_out_tdata + f3e_full_scale_value when (f3e_out_tdata < f3e_negative_threshold) else
                 f3e_out_tdata;
    
    m_axis_demod_tdata <= demod_out_data(30 downto 7) when modulation = "11" else demod_out_data(30 downto 7);
    m_axis_demod_tvalid <= demod_out_en;
    m_axis_rssi_tdata <= std_logic_vector(abs(signed(a3e_out_tdata(31 downto 0)))); 
    m_axis_rssi_tvalid <=  a3e_out_tvalid;

end Behavioral;
