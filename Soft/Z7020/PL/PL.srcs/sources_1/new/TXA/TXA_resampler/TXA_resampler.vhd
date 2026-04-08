----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 24.12.2023 11:54:58
-- Design Name: 
-- Module Name: TXA_resampler - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TXA_resampler is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        s_axis_modulator_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_modulator_tvalid : in STD_LOGIC;
        gain : in STD_LOGIC_VECTOR (17 downto 0);              -- := "00" & x"7FFF";   100%
        out_over : out STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end TXA_resampler;

architecture Behavioral of TXA_resampler is

   component fir_duc_inter5 is
        port (
            aclk : in STD_LOGIC;
            s_axis_data_tvalid : in STD_LOGIC;
            s_axis_data_tready : out STD_LOGIC;
            s_axis_data_tdata : in STD_LOGIC_VECTOR ( 47 downto 0 );
            m_axis_data_tvalid : out STD_LOGIC;
            m_axis_data_tdata : out STD_LOGIC_VECTOR ( 47 downto 0 )
        );
    end component fir_duc_inter5;
    
   component fir_duc_ciccomp is
        port (
            aclk : in STD_LOGIC;
            s_axis_data_tvalid : in STD_LOGIC;
            s_axis_data_tready : out STD_LOGIC;
            s_axis_data_tdata : in STD_LOGIC_VECTOR ( 47 downto 0);
            m_axis_data_tvalid : out STD_LOGIC;
            m_axis_data_tdata : out STD_LOGIC_VECTOR ( 47 downto 0 )
        );
    end component fir_duc_ciccomp;
    
    component cic_txa IS
    port (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    end component cic_txa;
    
    component dsp_24m18_1 is
        port (
            CLK : in STD_LOGIC;
            A : in STD_LOGIC_VECTOR ( 23 downto 0 );
            B : in STD_LOGIC_VECTOR ( 17 downto 0 );
            P : out STD_LOGIC_VECTOR ( 41 downto 0 )
        );
    end component dsp_24m18_1;
    
    COMPONENT round37to24 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(36 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
    );
    END COMPONENT round37to24;
    
    COMPONENT round31to24 IS
    PORT (
        i_data : IN STD_LOGIC_VECTOR(32 DOWNTO 0);
        o_data : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
    );
    END COMPONENT round31to24;
    
    signal interpolator_tdata : std_logic_vector(47 downto 0);
    signal interpolator_tvalid : std_logic;
    signal cic_in_tdata : std_logic_vector(47 downto 0);
    signal cic_in_tvalid : std_logic;
    signal cic_out_tdata_0, cic_out_tdata_1 : std_logic_vector(23 downto 0);
    signal cic_out_tvalid_0, cic_out_tvalid_1 : std_logic;
    signal out_tdata42_0, out_tdata42_1 : std_logic_vector(41 downto 0);
    signal out_tdata24_0, out_tdata24_1 : std_logic_vector(23 downto 0);

begin
    
fir_interpolator: component fir_duc_inter5
    port map (
        aclk => aclk,
        m_axis_data_tdata => interpolator_tdata,
        m_axis_data_tvalid => interpolator_tvalid,
        s_axis_data_tdata => s_axis_modulator_tdata,
        s_axis_data_tready => open,
        s_axis_data_tvalid => s_axis_modulator_tvalid
    );
    
fir_ciccomp: component fir_duc_ciccomp
    port map (
        aclk => aclk,
        m_axis_data_tdata => cic_in_tdata,
        m_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tdata => interpolator_tdata,
        s_axis_data_tready => open,
        s_axis_data_tvalid => interpolator_tvalid
    );
    
txa_cic_0 : cic_txa
    PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_data_tdata => cic_in_tdata(23 downto 0),
        s_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_tdata_0,
        m_axis_data_tvalid => cic_out_tvalid_0
    );
    
txa_cic_1 : cic_txa
    PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_data_tdata => cic_in_tdata(47 downto 24),
        s_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_tdata_1,
        m_axis_data_tvalid => cic_out_tvalid_1
    );
    
--mult_0: component dsp_24m18_1
--    port map (
--        CLK => aclk,
--        A => cic_out_tdata_0,
--        B => gain,
--        P => out_tdata42_0
--    );
--    
--mult_1: component dsp_24m18_1
--    port map (
--        CLK => aclk,
--        A => cic_out_tdata_1,
--        B => gain,
--        P => out_tdata42_1
--    );
 
process(aclk)
begin
	if rising_edge(aclk) then   
        out_tdata42_0 <= cic_out_tdata_0 * gain;
        out_tdata42_1 <= cic_out_tdata_1 * gain;
    end if;
end process;
    
round_0 : round37to24
    PORT MAP (
       i_data => out_tdata42_0(36 downto 0),
       o_data => out_tdata24_0
    );
    
round_1 : round37to24
    PORT MAP (
       i_data => out_tdata42_1(36 downto 0),
       o_data => out_tdata24_1
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	   out_over <= '0';   
	   if out_tdata42_0(41 downto 36) = "111111" or out_tdata42_0(41 downto 36) = "000000" then
	       m_axis_iq_tdata(23 downto 0) <= out_tdata24_0;
	   elsif  out_tdata42_0(41) = '0' then  
	       out_over <= '1';
	       m_axis_iq_tdata(23 downto 0) <= x"7FFFFF";
	   else
	       out_over <= '1';
	       m_axis_iq_tdata(23 downto 0) <= x"800000";
	   end if;  
	   if out_tdata42_1(41 downto 36) = "111111" or out_tdata42_1(41 downto 36) = "000000" then
	       m_axis_iq_tdata(47 downto 24) <= out_tdata24_1;
	   elsif  out_tdata42_1(41) = '0' then  
	       out_over <= '1';
	       m_axis_iq_tdata(47 downto 24) <= x"7FFFFF";
	   else
	       out_over <= '1';       
	       m_axis_iq_tdata(47 downto 24) <= x"800000";
	   end if;   
	end if;
end process;

end Behavioral;
