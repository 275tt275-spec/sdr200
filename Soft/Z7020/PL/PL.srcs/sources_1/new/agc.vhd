----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.12.2025 11:02:28
-- Design Name: 
-- Module Name: agc - Behavioral
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
--use ieee.std_logic_signed.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity agc is
    Port (
        aclk : in STD_LOGIC;
        s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0);
        s_axis_tvalid : in std_logic;
        m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_tvalid : out std_logic;
        cfg_addra : in STD_LOGIC_VECTOR (2 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC
    );
end agc;

architecture Behavioral of agc is

    COMPONENT cordic_rssi IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
        );
    END COMPONENT cordic_rssi;
        
--COMPONENT ila_3 IS
--    PORT (
--    clk : IN STD_LOGIC;       
--    probe0 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--    probe1 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
--    probe3 : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
--    probe4 : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
--    probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
--    probe6 : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--    probe7 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
--);
--END COMPONENT ila_3;

    signal s_axis_cartesian_tvalid : STD_LOGIC;
    signal s_axis_cartesian_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal s_tuser_r : STD_LOGIC_VECTOR (0 downto 0);
    signal s_tvalid_r : std_logic;
    signal m_axis_dout_tvalid : STD_LOGIC;
    signal m_axis_dout_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axis_rssi_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal m_axis_rssi_tvalid : STD_LOGIC;
    signal gain_tdata : STD_LOGIC_VECTOR (31 downto 0);

    signal gain_data : STD_LOGIC_VECTOR (47 downto 0);
    signal rssi_max : STD_LOGIC_VECTOR (31 downto 0) := x"10000000";
    signal rssi_max_fast : STD_LOGIC_VECTOR (31 downto 0) := x"20000000";
    signal rssi_min : STD_LOGIC_VECTOR (31 downto 0) := x"10000000";
    signal rssi_min_fast : STD_LOGIC_VECTOR (31 downto 0) := x"20000000";
    signal wr_addr : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal rd_addr : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal rssi_rd : STD_LOGIC_VECTOR (31 downto 0);
    signal rssi_max_value : STD_LOGIC_VECTOR (31 downto 0);
    signal rssi_max_valid : STD_LOGIC := '1';
    signal agc_on : STD_LOGIC := '1';
    signal rf_gain : STD_LOGIC_VECTOR (15 downto 0) := x"0020";
    signal rf_gain_old : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    
    signal gain : signed (17 downto 0) := (others => '0');
    signal gain_inc : signed (15 downto 0) := x"0001";
    signal gain_dec : signed (15 downto 0) := x"0001";
    signal gain_inc_fast : signed (15 downto 0) := x"0002";
    signal gain_dec_fast : signed (15 downto 0) := x"0002";

begin

--    gain_data <= s_axis_tdata * gain(17 downto 2);     
    
--debug_agc : ila_3
--    PORT MAP (
--    clk => aclk,       
--    probe0 => s_axis_tdata,
--    probe1 => s_axis_tuser,
--    probe2(0) => s_axis_tvalid,
--    probe3 => gain_data,
--    probe4 => gain,
--    probe5 => rf_gain,
--    probe6 => m_axis_rssi_tdata,
--    probe7(0) => m_axis_dout_tvalid
--);
    
cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        if cfg_wr = '1' then 
            if cfg_addra = "000" then
                rf_gain <= cfg_dina(15 downto 0); 
            elsif cfg_addra = "001" then
                agc_on <= cfg_dina(0);    
            elsif cfg_addra = "010" then
                rssi_max <= cfg_dina;
            elsif cfg_addra = "011" then
                rssi_max_fast <= cfg_dina;      
            elsif cfg_addra = "100" then
                rssi_min <= cfg_dina;     
            elsif cfg_addra = "101" then
                rssi_min_fast <= cfg_dina; 
            elsif cfg_addra = "110" then
                gain_inc_fast <= signed(cfg_dina(31 downto 16)); 
                gain_inc <= signed(cfg_dina(15 downto 0)); 
            elsif cfg_addra = "111" then
                gain_dec_fast <= signed(cfg_dina(31 downto 16)); 
                gain_dec <= signed(cfg_dina(15 downto 0)); 
            end if; 
        end if;
   end if;
end process cmd_process;

process(aclk)
begin
	if rising_edge(aclk) then	
	    s_tvalid_r <= s_axis_tvalid;
        s_tuser_r <= s_axis_tuser;
		if s_axis_tvalid = '1' then
		    gain_data <= std_logic_vector(signed(s_axis_tdata) * signed(gain(17 downto 2)));          
		end if;  
	end if;
end process;

process(aclk)
begin
	if rising_edge(aclk) then	
	    s_axis_cartesian_tvalid <= '0';	
		if s_tvalid_r = '1' then
		    if s_tuser_r = "0" then				   		
			    s_axis_cartesian_tdata(31 downto 0) <= gain_tdata(31) & gain_tdata(31 downto 1);  
			else
			    s_axis_cartesian_tdata(63 downto 32) <= gain_tdata(31) & gain_tdata(31 downto 1);
			    s_axis_cartesian_tvalid <= '1';
			end if;    	           
		end if;  
	end if;
end process;

rssi_0 : cordic_rssi
    PORT MAP(
        aclk => aclk,
        s_axis_cartesian_tvalid => s_axis_cartesian_tvalid,
        s_axis_cartesian_tdata => s_axis_cartesian_tdata,
        m_axis_dout_tvalid => m_axis_dout_tvalid,
        m_axis_dout_tdata => m_axis_dout_tdata
    );
    
process(aclk)
begin
	if rising_edge(aclk) then	
		if m_axis_dout_tvalid = '1' then
		    m_axis_rssi_tdata <= std_logic_vector(abs(signed(m_axis_dout_tdata(31 downto 0)))); 
		    m_axis_rssi_tvalid <= '1';     
		else
		   m_axis_rssi_tvalid <= '0';            
		end if;  
	end if;
end process;
    
--    m_axis_rssi_tdata <= std_logic_vector(abs(signed(m_axis_dout_tdata(31 downto 0)))); 
    m_axis_tdata <= gain_tdata;
        
agc_process : process (aclk) is
begin 
   if rising_edge(aclk) then
       m_axis_tvalid <= s_tvalid_r;
       m_axis_tuser <= s_tuser_r;
       if s_tvalid_r = '1' then
           if gain_data(47 downto 34) = "11111111111111" or gain_data(47 downto 34) = "00000000000000" then
               gain_tdata <= gain_data(35 downto 4); -- Cordic in demodulator
               if agc_on = '0' then
                   if rf_gain_old /= rf_gain then
                       gain <= signed(rf_gain & "00");
                       rf_gain_old <= rf_gain;
                   end if;  
               elsif s_tuser_r = "1" then         
                    rf_gain_old <= (others => '0');  
                    if (m_axis_rssi_tdata > rssi_max_fast) and (gain >= gain_dec_fast) then
                        gain <= gain - gain_dec_fast;
                    elsif (m_axis_rssi_tdata > rssi_max) and (gain >= gain_dec) then
                        gain <= gain - gain_dec;
                    elsif rssi_max_valid = '1' then   
                        if (rssi_max_value < rssi_min_fast) and (gain < ("01" & x"FFFF" - gain_inc_fast)) then
                            gain <= gain + gain_inc_fast;
                         elsif (rssi_max_value < rssi_min) and (gain < ("01" & x"FFFF" - gain_inc)) then
                            gain <= gain + gain_inc;     
                        end if;   
                    end if;
               end if;
           else 
                gain <= "000" & gain(16 downto 2);   
--              if gain_data(47 downto 35) = "1111111111111" or gain_data(47 downto 35) = "0000000000000" then  
--                  gain <= "00" & gain(17 downto 2);
--              elsif gain_data(47 downto 36) = "111111111111" or gain_data(47 downto 36) = "000000000000" then  
--                  gain <= "000" & gain(17 downto 3);
--              elsif gain_data(47 downto 37) = "11111111111" or gain_data(47 downto 37) = "00000000000" then  
--                  gain <= "0000" & gain(17 downto 4);  
--              elsif gain_data(47 downto 38) = "1111111111" or gain_data(47 downto 38) = "0000000000" then  
--                  gain <= "00000" & gain(17 downto 5); 
--              elsif gain_data(47 downto 39) = "111111111" or gain_data(47 downto 39) = "000000000" then  
--                  gain <= "000000" & gain(17 downto 6);      
--              elsif gain_data(47 downto 40) = "11111111" or gain_data(47 downto 40) = "00000000" then  
--                  gain <= "0000000" & gain(17 downto 7); 
--              elsif gain_data(47 downto 41) = "1111111" or gain_data(47 downto 41) = "0000000" then  
--                  gain <= "00000000" & gain(17 downto 8);  
--              elsif gain_data(47 downto 42) = "111111" or gain_data(47 downto 42) = "000000" then  
--                  gain <= "000000000" & gain(17 downto 9);  
--              elsif gain_data(47 downto 43) = "11111" or gain_data(47 downto 43) = "00000" then  
--                  gain <= "0000000000" & gain(17 downto 10); 
--              else
--                  gain <= "00000000000" & gain(17 downto 11);                    
--               end if;     
               if gain_data(47) = '0' then  
                   gain_tdata <= x"7FFFFFFF";
               else
                   gain_tdata <= x"80000000";
               end if;    
           end if;           
        end if;          
   end if;
end process agc_process;

max_fifo_gen : for k in 0 to 31 generate	
    RAM64X1D_inst : RAM64X1D
    generic map (
        INIT => X"0000000000000000", -- Initial contents of RAM
        IS_WCLK_INVERTED => '0') -- Specifies active high/low WCLK
    port map (
        DPO => rssi_rd(k), -- Read-only 1-bit data output
        SPO => open, -- R/W 1-bit data output
        A0 => wr_addr(0), -- R/W address[0] input bit
        A1 => wr_addr(1), -- R/W address[1] input bit
        A2 => wr_addr(2), -- R/W address[2] input bit
        A3 => wr_addr(3), -- R/W address[3] input bit
        A4 => wr_addr(4), -- R/W address[4] input bit
        A5 => wr_addr(5), -- R/W address[4] input bit
        D => m_axis_rssi_tdata(k), -- Write 1-bit data input
        DPRA0 => rd_addr(0), -- Read-only address[0] input bit
        DPRA1 => rd_addr(1), -- Read-only address[1] input bit
        DPRA2 => rd_addr(2), -- Read-only address[2] input bit
        DPRA3 => rd_addr(3), -- Read-only address[3] input bit
        DPRA4 => rd_addr(4), -- Read-only address[4] input bit
        DPRA5 => rd_addr(5), -- Read-only address[4] input bit
        WCLK => aclk,               -- Write clock input
        WE => m_axis_rssi_tvalid    -- Write enable input
    );
end generate ;

-- Calculate max value form 64 vector	
process(aclk)
begin 
   if rising_edge(aclk) then
        if m_axis_rssi_tvalid = '1' then
            wr_addr <= std_logic_vector(signed(wr_addr) + 1);
            rssi_max_value <= rssi_rd;
            rd_addr <= (others => '0');
            rssi_max_valid <= '0';
        end if;
        if rssi_max_valid = '0' and rd_addr /= "111111" then
            rd_addr <= std_logic_vector(signed(rd_addr) + 1);
            if rssi_max_value < rssi_rd then
                rssi_max_value <= rssi_rd;
            end if; 
        else
            rssi_max_valid <= '1';   
            rd_addr <= (others => '0');    
        end if;              
   end if;
end process;

end Behavioral;
