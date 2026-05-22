----------------------------------------------------------------------------------
-- Overshoot controller
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim_overshoot is
Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_data_tvalid : in STD_LOGIC; 
        limit : in STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata : in STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : in STD_LOGIC;
        fir_reload_tlast : in STD_LOGIC;
        fir_config_tdata : in STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : in STD_LOGIC;
        over : out STD_LOGIC;
        denom_dbg : out std_logic_vector(15 downto 0); 
        aclk : in STD_LOGIC
    );
end lim_overshoot;

architecture Behavioral of lim_overshoot is

component lim_translate_cordic
        port (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component lim_translate_cordic;
    
    component blk_mem_32
        port (
            clka : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            clkb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
        );
    end component blk_mem_32;    
    
    COMPONENT lim_lpf_fir IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_data_tvalid : IN STD_LOGIC;
            s_axis_data_tready : OUT STD_LOGIC;
            s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tready : OUT STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_reload_tvalid : IN STD_LOGIC;
            s_axis_reload_tready : OUT STD_LOGIC;
            s_axis_reload_tlast : IN STD_LOGIC;
            s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim_lpf_fir;

--    component div_24_16 is
--        port (
--            s_axis_divisor_tvalid : IN STD_LOGIC;
--            s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--            s_axis_dividend_tvalid : IN STD_LOGIC;
--            s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
--            m_axis_dout_tvalid : OUT STD_LOGIC;
--            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(39 DOWNTO 0)
--        );
--    end component div_24_16;

    component lim_div is
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component lim_div;
    
    signal delay_out_0, delay_out_1 : std_logic_vector(47 downto 0) := (others => '0');        
    signal cordic_in: std_logic_vector(47 downto 0);
    signal cordic_out: std_logic_vector(31 downto 0);
    signal cordic_tvalid : std_logic;
    signal magnitude, magnitude1, magnitude2, magnitude3, magnitude4 : std_logic_vector(15 downto 0)  := (others => '0');  
--    signal max, max1, max2, max3 : std_logic_vector(15 downto 0); 
    signal max : std_logic_vector(15 downto 0) := (others => '0');
    signal corr, corr1, denom : std_logic_vector(15 downto 0) := x"0001";
    signal divout_0, divout_1 : std_logic_vector(23 downto 0); 
    signal divout_valid_0, divout_valid_1 : std_logic;
    signal div_over_0, div_over_1 : std_logic;
    signal fir_in_tdata : std_logic_vector(47 downto 0);
    signal fir_in_tvalid : std_logic;
    signal fir_out_tdata : std_logic_vector(63 downto 0);
    type T_STATE is (IDLE, S0, S1, S2, S3, S4, S5);
    signal state : T_STATE := IDLE;
    signal delay_tvalid : std_logic := '0';

begin

    denom_dbg <= denom;
    cordic_in <= s_axis_data_tdata(47) & s_axis_data_tdata(47 downto 25) & s_axis_data_tdata(23) & s_axis_data_tdata(23 downto 1);

mag_cordic_0 : lim_translate_cordic
    PORT MAP (
      aclk => aclk,
      s_axis_cartesian_tvalid => s_axis_data_tvalid,
      s_axis_cartesian_tdata => cordic_in, 
      m_axis_dout_tvalid => cordic_tvalid,
      m_axis_dout_tdata => cordic_out
    );

    magnitude <= std_logic_vector(abs(signed(cordic_out(15 downto 0))));  
    
process(aclk)
begin
	if rising_edge(aclk) then  
	   if cordic_tvalid = '1' then
	       magnitude1 <= magnitude;
	       magnitude2 <= magnitude1;
	       magnitude3 <= magnitude2;
	       magnitude4 <= magnitude3;
	       delay_out_0 <= s_axis_data_tdata;
	       delay_out_1 <= delay_out_0;
	   end if;    
	end if;
end process;

process(aclk)
begin
	if rising_edge(aclk) then  
	   delay_tvalid <= '0';
	   if cordic_tvalid = '1' then
	       state <= S0;
           if magnitude4 < magnitude3 then
               max <= magnitude3;
           else
               max <= magnitude4; 
           end if;    
       end if;    
       if state = S0 then    
           state <= S1;       
           if max < magnitude2 then
               max <= magnitude2;
           end if;
       end if;
       if state = S1 then    
           state <= S2;      
           if max < magnitude1 then
               max <= magnitude1;
           end if; 
       end if;
       if state = S2 then    
           state <= S3;  
           if max < magnitude then
               max <= magnitude;
          end if;     
       end if; 
       if state = S3 then    
           state <= S4;  
           if max < limit then
               corr <= x"0000";
           else
               corr <= max - limit; 
           end if; 
       end if; 
       if state = S4 then    
           state <= S5; 
           corr1 <= corr(15 downto 1) & '0';                       -- gain 2
       end if;  
       if state = S5 then    
           state <= IDLE;  
           denom <= corr1 + limit; 
           delay_tvalid <= '1';
       end if;                         
	end if;
end process;

--    max3 <= magnitude3 when magnitude4 < magnitude3 else magnitude4;
--    max2 <= magnitude2 when max3 < magnitude2 else max3;
--    max1 <= magnitude1 when max2 < magnitude1 else max2;
--    max <= magnitude when max1 < magnitude else max1;
--    corr <= x"0000" when max < limit else ( max - limit);
--    corr1 <= corr(15 downto 1) & '0';                       -- gain 2
--    denom <= corr1 + limit;
    
--div_0 : div_24_16
--    PORT MAP (
--        s_axis_divisor_tvalid => '1',
--        s_axis_divisor_tdata => denom,
--        s_axis_dividend_tvalid => cordic_tvalid,
--        s_axis_dividend_tdata => delay_out_1(47 downto 24),
--        m_axis_dout_tvalid => divout_valid_0,
--        m_axis_dout_tdata => divout_0
--    );
--    
--div_1 : div_24_16 
--    PORT MAP (
--        s_axis_divisor_tvalid => '1',
--        s_axis_divisor_tdata => denom,
--        s_axis_dividend_tvalid => cordic_tvalid,
--        s_axis_dividend_tdata => delay_out_1(23 downto 0),
--        m_axis_dout_tvalid => divout_valid_1,
--        m_axis_dout_tdata => divout_1
--    );
--    
--    divo_0 <= '1' & (-1 - divout_0(38 downto 16)) & divout_0(14 downto 0) when divout_0(39) = '0' and divout_0(15) = '1' else
--              divout_0(39 downto 16) & (-1 - divout_0(14 downto 0)) when divout_0(39) = '1' and divout_0(15) = '0' else
--              (divout_0(39 downto 16) & divout_0(14 downto 0) - 32768) when divout_0(39) = '1' and divout_0(15) = '1' else
--              divout_0(39 downto 16) & divout_0(14 downto 0);  
--              
--    divo_1 <= '1' & (-1 - divout_1(38 downto 16)) & divout_1(14 downto 0) when divout_1(39) = '0' and divout_1(15) = '1' else
--              divout_1(39 downto 16) & (-1 - divout_1(14 downto 0)) when divout_1(39) = '1' and divout_1(15) = '0' else
--              (divout_1(39 downto 16) & divout_1(14 downto 0) - 32768) when divout_1(39) = '1' and divout_1(15) = '1' else
--              divout_1(39 downto 16) & divout_1(14 downto 0);  
--
--    fir_in_tdata <= divo_0(27 downto 4) & divo_1(27 downto 4);
    
div_0 : lim_div
    PORT MAP (
        s_axis_divisor_tvalid => '1',
        s_axis_divisor_tdata => denom,
--        s_axis_dividend_tvalid => cordic_tvalid,
        s_axis_dividend_tvalid => delay_tvalid,
        s_axis_dividend_tdata => delay_out_1(47 downto 24),
        m_axis_dout_tvalid => divout_valid_0,
        m_axis_dout_tdata => divout_0,
        out_over => div_over_0,
        aclk => aclk
    );
    
div_1 : lim_div
    PORT MAP (
        s_axis_divisor_tvalid => '1',
        s_axis_divisor_tdata => denom,
--        s_axis_dividend_tvalid => cordic_tvalid,
        s_axis_dividend_tvalid => delay_tvalid,
        s_axis_dividend_tdata => delay_out_1(23 downto 0),
        m_axis_dout_tvalid => divout_valid_1,
        m_axis_dout_tdata => divout_1,
        out_over => div_over_1,
        aclk => aclk
    );

    fir_in_tdata <= divout_0 & divout_1;
    fir_in_tvalid <= divout_valid_0;
    over <= div_over_0 or div_over_1;
     
fir_0 : lim_lpf_fir
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => fir_in_tdata,
        s_axis_config_tvalid => fir_config_tvalid,
        s_axis_config_tready => open,
        s_axis_config_tdata => fir_config_tdata,
        s_axis_reload_tvalid => fir_reload_tvalid,
        s_axis_reload_tready => open,
        s_axis_reload_tlast => fir_reload_tlast,
        s_axis_reload_tdata => fir_reload_tdata,
        m_axis_data_tvalid => m_axis_data_tvalid,
        m_axis_data_tdata => fir_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
    m_axis_data_tdata <= fir_out_tdata(63) & fir_out_tdata(54 downto 32) & fir_out_tdata(31) & fir_out_tdata(22 downto 0);

end Behavioral;
