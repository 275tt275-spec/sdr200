----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:58:42 11/24/2023 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

entity rx_packet_55 is
    generic (
        BAUD_CODE : natural
    );
    Port (
       clk : in  STD_LOGIC;
       clr : in  STD_LOGIC;
       rxd : in  STD_LOGIC;
       raddr : in  STD_LOGIC_VECTOR (2 downto 0);
       rdata : out  STD_LOGIC_VECTOR (31 downto 0);
       frame_rdy : out  STD_LOGIC;
       frame_confirm : in  STD_LOGIC
     );
end rx_packet_55;

architecture Behavioral of rx_packet_55 is

constant BAUD_CODE_IN : integer := BAUD_CODE;

component uart_rx_min
    Port (          serial_in : in std_logic;
                     data_out : out std_logic_vector(7 downto 0);
                         baud : in std_logic_vector(15 downto 0);
								  rdy : out std_logic;
					  stop_bit_err : out std_logic;
                          clk : in std_logic);
    end component;

signal rdy : std_logic := '0';
signal rx_data : std_logic_vector(7 downto 0);
signal data_reg : std_logic_vector(255 downto 0);
signal byte_cnt : std_logic_vector(5 downto 0);
signal rx_rdy : std_logic;
    
begin

frame_rdy <= rdy;

rdata <= data_reg( 31 downto  0)  when raddr = 0 else
			data_reg( 63 downto 32)  when raddr = 1 else
			data_reg( 95 downto 64)  when raddr = 2 else
			data_reg(127 downto 96)  when raddr = 3 else
			data_reg(159 downto 128) when raddr = 4 else
			data_reg(191 downto 160) when raddr = 5 else
			data_reg(223 downto 192) when raddr = 6 else
			data_reg(255 downto 224);

uart : uart_rx_min port map(
	clk => clk,
	serial_in => rxd,
	data_out => rx_data,
	baud => conv_std_logic_vector(BAUD_CODE_IN, 16),
	rdy => rx_rdy
);
	
process(clk)
begin
	if rising_edge(clk) then
		if clr = '1' then
			rdy <= '0';
		else
			if rdy = '0' then		-- receiving enabled	
				if rx_rdy = '1' then
				    if byte_cnt = "000000" then
				        if rx_data = x"55" then 
				           byte_cnt <= "000001";
				        end if;
				    else
				        byte_cnt <= byte_cnt + 1; 
				    end if;     
				    data_reg <= rx_data & data_reg(255 downto 8);   
				end if;
				if byte_cnt = 32 then
					rdy <= '1';
				end if;	
			elsif frame_confirm = '1' then
				byte_cnt <= (others => '0');
				rdy <= '0';
			end if;
		end if;	
	end if;
end process;
						
end Behavioral;

