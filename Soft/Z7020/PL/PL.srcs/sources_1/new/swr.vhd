----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.05.2025 16:43:35
-- Design Name: 
-- Module Name: swr - Behavioral
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
use ieee.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity swr is
    Port ( 
        s_axis_data0_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_data0_tuser : in STD_LOGIC_VECTOR (0 downto 0);
        s_axis_data0_tvalid : in STD_LOGIC;
        s_axis_data1_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_data1_tuser : in STD_LOGIC_VECTOR (0 downto 0);
        s_axis_data1_tvalid : in STD_LOGIC;
        cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
		cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;                      
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end swr;

architecture Behavioral of swr is

    COMPONENT cordic_translate_24
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_cartesian_tvalid : IN STD_LOGIC;
        s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT cordic_translate_24;

    signal i_data0_in, q_data0_in, i_data1_in, q_data1_in : std_logic_vector(31 downto 0);
    signal i_add, i_sub, q_add, q_sub : std_logic_vector(31 downto 0);
    signal cordic_in_tdata_ch0, cordic_in_tdata_ch1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tdata_ch0, cordic_out_tdata_ch1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tvalid_ch0, cordic_out_tvalid_ch1 : STD_LOGIC;
    signal cordic_in_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal cordic_in_tvalid : STD_LOGIC := '0';
    signal cordic_in_tdata_0, cordic_in_tdata_1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tdata_0, cordic_out_tdata_1 : STD_LOGIC_VECTOR(47 DOWNTO 0);
    signal cordic_out_tvalid_0, cordic_out_tvalid_1 : STD_LOGIC;
    signal out_valid : STD_LOGIC_VECTOR(3 DOWNTO 0) := (others => '0');
    signal chan_tvalid : STD_LOGIC := '0';
    signal axis_magnitude_tdata : STD_LOGIC_VECTOR (31 downto 0);  -- 16 bit chan A & 16 bit chan B (absolute)
    signal axis_angle_tdata : STD_LOGIC_VECTOR (31 downto 0);      -- 16 bit chan A & 16 bit chan B (signed) 
    signal axis_swr_tdata : STD_LOGIC_VECTOR (31 downto 0);        -- 16 bit inc & 16 bit ref (absolute)

begin

    cfg_douta <= axis_magnitude_tdata when cfg_addra = x"01" else 
              axis_angle_tdata when cfg_addra = x"02" else 
              axis_swr_tdata;

    cordic_in_tdata_ch0 <= i_data0_in(31) & i_data0_in(31 downto 9) & q_data0_in(31) & q_data0_in(31 downto 9);
    cordic_in_tdata_ch1 <= i_data1_in(31) & i_data1_in(31 downto 9) & q_data1_in(31) & q_data1_in(31 downto 9);

cordic_0 : cordic_translate_24
    PORT MAP (
        aclk => aclk,
        s_axis_cartesian_tvalid => cordic_in_tvalid,
        s_axis_cartesian_tdata => cordic_in_tdata_ch0,
        m_axis_dout_tvalid => cordic_out_tvalid_ch0,
        m_axis_dout_tdata => cordic_out_tdata_ch0
    );
    
cordic_1 : cordic_translate_24
    PORT MAP (
        aclk => aclk,
        s_axis_cartesian_tvalid => cordic_in_tvalid,
        s_axis_cartesian_tdata => cordic_in_tdata_ch1,
        m_axis_dout_tvalid => cordic_out_tvalid_ch1,
        m_axis_dout_tdata => cordic_out_tdata_ch1
    );

    i_add <= i_data0_in + i_data1_in;
    i_sub <= i_data0_in - i_data1_in;
    q_add <= q_data0_in + q_data1_in;
    q_sub <= q_data0_in - q_data1_in;
    cordic_in_tdata_0 <= i_add(31) & i_add(31 downto 9) & q_add(31) & q_add(31 downto 9);
    cordic_in_tdata_1 <= i_sub(31) & i_sub(31 downto 9) & q_sub(31) & q_sub(31 downto 9);

process(aclk)
begin
	if rising_edge(aclk) then	
        if cordic_in_valid = "11" then
	       cordic_in_valid <= "00";
	       cordic_in_tvalid <= '1';
	    else
	       cordic_in_tvalid <= '0';   
	    end if;
	    	
		if s_axis_data0_tvalid = '1' then
		    if s_axis_data0_tuser = "0" then				   		
			    i_data0_in <= s_axis_data0_tdata(31) & s_axis_data0_tdata(31 downto 1);
			else
			    q_data0_in <= s_axis_data0_tdata(31) & s_axis_data0_tdata(31 downto 1);
			    cordic_in_valid(0) <= '1';
			end if;    	           
		end if; 
        if s_axis_data1_tvalid = '1' then
		    if s_axis_data1_tuser = "0" then				   		
			    i_data1_in <= s_axis_data1_tdata(31) & s_axis_data1_tdata(31 downto 1);
			else
			    q_data1_in <= s_axis_data1_tdata(31) & s_axis_data1_tdata(31 downto 1);
			    cordic_in_valid(1) <= '1';
			end if;    	           
		end if; 
	end if;
end process;

cordic_2 : cordic_translate_24
    PORT MAP (
        aclk => aclk,
        s_axis_cartesian_tvalid => cordic_in_tvalid,
        s_axis_cartesian_tdata => cordic_in_tdata_0,
        m_axis_dout_tvalid => cordic_out_tvalid_0,
        m_axis_dout_tdata => cordic_out_tdata_0
    );
    
cordic_3 : cordic_translate_24
    PORT MAP (
        aclk => aclk,
        s_axis_cartesian_tvalid => cordic_in_tvalid,
        s_axis_cartesian_tdata => cordic_in_tdata_1,
        m_axis_dout_tvalid => cordic_out_tvalid_1,
        m_axis_dout_tdata => cordic_out_tdata_1
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	    if out_valid = "1111" then
	       out_valid <= "0000";
	       chan_tvalid <= '1';
	    else
	       chan_tvalid <= '0';   
	    end if;
			
		if cordic_out_tvalid_ch0 = '1' then	
		    out_valid(0) <= '1';
            axis_magnitude_tdata <= cordic_out_tdata_ch0(22 downto 7) & cordic_out_tdata_ch1(22 downto 7);
        end if;  
        if cordic_out_tvalid_ch1 = '1' then	
            out_valid(1) <= '1';
            axis_angle_tdata <= cordic_out_tdata_ch0(46 downto 31) & cordic_out_tdata_ch1(46 downto 31);
        end if; 
        if cordic_out_tvalid_0 = '1' then	
            out_valid(2) <= '1';
            axis_swr_tdata(31 downto 16) <= cordic_out_tdata_0(22 downto 7);
        end if;
        if cordic_out_tvalid_1 = '1' then	
            out_valid(3) <= '1';
            axis_swr_tdata(15 downto 0) <= cordic_out_tdata_1(22 downto 7);
        end if;   
    end if;
end process;  


end Behavioral;
