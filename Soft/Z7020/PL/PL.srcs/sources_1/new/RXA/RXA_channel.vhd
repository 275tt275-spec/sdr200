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
    signal mult_out : std_logic_vector(79 downto 0);  
    signal cic_in_data_0, cic_in_data_1 : std_logic_vector(23 downto 0);
    signal cic_out_data_0, cic_out_data_1 : std_logic_vector(87 downto 0);
    signal cic_round_0, cic_round_1 : std_logic_vector(31 downto 0) := (others => '0');
    signal cic_round_valid_0, cic_round_valid_1 : std_logic;
    signal cic_out_0, cic_out_1 : std_logic_vector(31 downto 0);
    signal cic_out_valid_0, cic_out_valid_1 : std_logic;
    signal cic_valid : std_logic_vector(1 downto 0) := (others => '0');
    
    signal fir1_in_tdata : std_logic_vector(31 DOWNTO 0);
    signal fir1_in_tuser : std_logic_vector(0 DOWNTO 0) := "1";
    signal fir1_in_tvalid : std_logic := '0';
    signal fir1_in_tready : std_logic;
    signal fir1_out_tdata : std_logic_vector(55 downto 0);
    signal fir1_out_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir1_out_tvalid : std_logic := '0';
    signal fir1_a_tvalid, fir1_b_tvalid : std_logic := '0';
    signal fir1_round_0, fir1_round_1 : std_logic_vector(31 downto 0) := (others => '0');
    signal fir1_round_valid_0, fir1_round_valid_1 : std_logic;
    signal fir1_out_0, fir1_out_1 : std_logic_vector(31 downto 0) := (others => '0');
    signal fir1_round_valid : std_logic_vector(1 DOWNTO 0) := (others => '0');
    
    signal fir2_in_tdata : std_logic_vector(31 DOWNTO 0);
    signal fir2_in_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir2_in_tvalid : std_logic := '0';
    signal fir2_in_tready : std_logic;
    signal fir2_out_tdata : std_logic_vector(55 downto 0);
    signal fir2_out_tuser : std_logic_vector(0 DOWNTO 0);
    signal fir2_out_tvalid : std_logic := '0';
    
    constant MULT_SHIFT : integer := 8;
    constant CIC_SHIFT : integer := 2;
    constant FIR1_SHIFT : integer := 3; 
    constant OUT_SHIFT : integer := 5;    
    signal out_a_valid, out_b_valid : std_logic := '0';  
    signal outo_a_valid, outo_b_valid : std_logic;  
    signal out_a_data, out_b_data : std_logic_vector(31 DOWNTO 0);
    signal out_valid : std_logic_vector(1 DOWNTO 0) := (others => '0');
    signal out_a_data_r, out_b_data_r : std_logic_vector(31 DOWNTO 0);
    signal m_tvalid_reg : std_logic := '0';  
    signal m_tuser_reg : std_logic_vector(0 DOWNTO 0) := (others => '0');
    signal m_tdata_reg : std_logic_vector(31 DOWNTO 0) := (others => '0');
        
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
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(79 DOWNTO 0)
    );
    END COMPONENT cmpy_16x16;
    
    COMPONENT cic_nb IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(87 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_nb;
    
    COMPONENT signed_round_sat is
    generic (
        IWID       : integer := 37; -- Исходная разрядность данных
        OWID       : integer := 24; -- Выходная разрядность после округления
        SHIFT_LEFT : integer := 0   -- Параметр сдвига данных вверх перед округлением (0, 1, 2 и т.д.)
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;
        i_data  : in  std_logic_vector(IWID-1 downto 0);
        i_valid : in  std_logic;
        o_data  : out std_logic_vector(OWID-1 downto 0);
        o_valid : out std_logic;
        ovf     : out std_logic -- Флаг фиксации переполнения (сатурации)
    );
    END COMPONENT  signed_round_sat;
        
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
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
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
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
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

signed_round_sat_mult_a : signed_round_sat
    generic map(
        IWID       => 40,
        OWID       => 24,
        SHIFT_LEFT => MULT_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => aresetn,
        i_data  => mult_out(39 downto 0),
        i_valid => '1',
        o_data  => cic_in_data_0,
        o_valid => open,
        ovf     => open
    ); 
    
    signed_round_sat_mult_b : signed_round_sat
    generic map(
        IWID       => 40,
        OWID       => 24,
        SHIFT_LEFT => MULT_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => aresetn,
        i_data  => mult_out(79 downto 40),
        i_valid => '1',
        o_data  => cic_in_data_1,
        o_valid => open,
        ovf     => open
    );       
    
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
    
    signed_round_sat_cic_a : signed_round_sat
    generic map(
        IWID       => 88,
        OWID       => 32,
        SHIFT_LEFT => CIC_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => reset_cic,
        i_data  => cic_out_data_0,
        i_valid => cic_out_valid_0,
        o_data  => cic_round_0,
        o_valid => cic_round_valid_0,
        ovf     => open
    ); 
    
    signed_round_sat_cic_b : signed_round_sat
    generic map(
        IWID       => 88,
        OWID       => 32,
        SHIFT_LEFT => CIC_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => reset_cic,
        i_data  => cic_out_data_1,
        i_valid => cic_out_valid_1,
        o_data  => cic_round_1,
        o_valid => cic_round_valid_1,
        ovf     => open
    ); 

process(aclk)
begin
	if rising_edge(aclk) then
	
		if cic_round_valid_0 = '1' then
		  cic_out_0 <= cic_round_0;
		  cic_valid(0) <= '1';
		end if; 
		if cic_round_valid_1 = '1' then
		  cic_out_1 <= cic_round_1;
		  cic_valid(1) <= '1';
		end if; 
		
		fir1_in_tvalid <= '0'; 		
		if fir1_in_tready = '1' then		
		  if cic_valid = "11" then 		
		      cic_valid <= "00"; 
		      fir1_in_tdata <= cic_out_0;    		   
		      fir1_in_tuser <= "0";
		      fir1_in_tvalid <= '1';
		  elsif fir1_in_tuser = "0" then
		      fir1_in_tdata <= cic_out_1;  
		      fir1_in_tuser <= "1";
		      fir1_in_tvalid <= '1';   
		  end if; 		  
		end if;
		
	end if;
end process; 

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
    
    fir1_a_tvalid <= fir1_out_tvalid when fir1_out_tuser = "0" else '0';
    fir1_b_tvalid <= fir1_out_tvalid when fir1_out_tuser = "1" else '0';
    
    signed_round_sat_fir1_a : signed_round_sat
    generic map(
        IWID       => 56,
        OWID       => 32,
        SHIFT_LEFT => FIR1_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir1_out_tdata,
        i_valid => fir1_a_tvalid,
        o_data  => fir1_round_0,
        o_valid => fir1_round_valid_0,
        ovf     => open
    ); 
    
    signed_round_sat_fir1_b : signed_round_sat
    generic map(
        IWID       => 56,
        OWID       => 32,
        SHIFT_LEFT => FIR1_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir1_out_tdata,
        i_valid => fir1_b_tvalid,
        o_data  => fir1_round_1,
        o_valid => fir1_round_valid_1,
        ovf     => open
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	
		if fir1_round_valid_0 = '1' then
		  fir1_out_0 <= fir1_round_0;
		  fir1_round_valid(0) <= '1';
		end if; 
		if fir1_round_valid_1 = '1' then
		  fir1_out_1 <= fir1_round_1;
		  fir1_round_valid(1) <= '1';
		end if; 
		
		fir2_in_tvalid <= '0'; 		
		if fir2_in_tready = '1' then		
		  if fir1_round_valid = "11" then 		
		      fir1_round_valid <= "00"; 
		      fir2_in_tdata <= fir1_out_0;    		   
		      fir2_in_tuser <= "0";
		      fir2_in_tvalid <= '1';
		  elsif fir2_in_tuser = "0" then
		      fir2_in_tdata <= fir1_out_1;    		   
		      fir2_in_tuser <= "1";
		      fir2_in_tvalid <= '1'; 
		  end if; 		  
		end if;
		
	end if;
end process; 
    
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
    
    out_a_valid <= fir2_out_tvalid when fir2_out_tuser = "0" else '0';
    out_b_valid <= fir2_out_tvalid when fir2_out_tuser = "1" else '0';
    
signed_round_sat_out_a : signed_round_sat
    generic map(
        IWID       => 56,
        OWID       => 32,
        SHIFT_LEFT => OUT_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir2_out_tdata,
        i_valid => out_a_valid,
        o_data  => out_a_data,
        o_valid => outo_a_valid,
        ovf     => open
    ); 
    
signed_round_sat_out_b : signed_round_sat
    generic map(
        IWID       => 56,
        OWID       => 32,
        SHIFT_LEFT => OUT_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir2_out_tdata,
        i_valid => out_b_valid,
        o_data  => out_b_data,
        o_valid => outo_b_valid,
        ovf     => open
    );
    
process(aclk)
begin
	if rising_edge(aclk) then	    
	    if out_valid = "11" then
	       out_valid <= "00";
	       m_tuser_reg <= "0";
	       m_tdata_reg <= out_a_data_r;
	       m_tvalid_reg <= '1';
	    elsif m_tvalid_reg = '1' and  m_tuser_reg = "0" then
	       m_tdata_reg <= out_b_data_r;
	       m_tuser_reg <= "1";
	       m_tvalid_reg <= '1';
	    else
	       m_tvalid_reg <= '0';   
	    end if;
	    if outo_a_valid = '1' then
	       out_a_data_r <= out_a_data;
	       out_valid(0) <= '1';
	    end if;
        if outo_b_valid = '1' then
	       out_b_data_r <= out_b_data;
	       out_valid(1) <= '1';
	    end if;
	end if;
end process;

m_axis_data_tvalid <= m_tvalid_reg;
m_axis_data_tuser <= m_tuser_reg;
m_axis_data_tdata <= m_tdata_reg;
    
end Behavioral;
