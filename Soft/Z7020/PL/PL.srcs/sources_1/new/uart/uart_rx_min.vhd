--
------------------------------------------------------------------------------------
--
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

------------------------------------------------------------------------------------
--
entity uart_rx_min is
    Port (          serial_in : in std_logic;
                     data_out : out std_logic_vector(7 downto 0);
                         baud : in std_logic_vector(15 downto 0);
								  rdy : out std_logic;
					  stop_bit_err : out std_logic;
                          clk : in std_logic);
    end uart_rx_min;
--
------------------------------------------------------------------------------------
--

architecture behav of uart_rx_min is

------------
-- TYPES
------------
type TX_STATE is (IDLE, RX_START, RX_DATA, RX_STOP); 
------------------------------------------------------------------------------------
-- Signals u
------------------------------------------------------------------------------------
--
signal shift_reg      : std_logic_vector(7 downto 0);
signal s1, s2, s3	 : std_logic := '1';

signal tick_cnt		 : std_logic_vector(15 downto 0);	
signal bit_cnt	   	 : std_logic_vector(3 downto 0);	

signal state : TX_STATE := IDLE;

------------------------------------------------------------------------------------
-- Start of UART_TX circuit description
------------------------------------------------------------------------------------
--	
begin

rx_proc : process(clk)
begin
	if rising_edge(clk) then
		
		s1 <= serial_in;
		s2 <= s1;
		s3 <= s2;
		case state IS
		when IDLE =>
			stop_bit_err <= '0';
			rdy <= '0';
			if s2 = '0' AND s3 = '1' then
				shift_reg <= (OTHERS => '0');
				tick_cnt <= '0' & baud(15 downto 1); --x"51";
				bit_cnt <= "1000";
				state <= RX_START;
			end if;
		when RX_START =>
			if tick_cnt = 0 then
				if s2 = '0' and s3 = '0' then 
					state <= RX_DATA;
					tick_cnt <= baud;
				else
					state <= IDLE;
				end if;
			else
				tick_cnt <= tick_cnt - 1;
			end if;
		when RX_DATA =>
			if	tick_cnt = 0 then
				shift_reg <= s2 & shift_reg(7 downto 1); 
				bit_cnt <= bit_cnt - 1;
				tick_cnt <= baud;
			else
				tick_cnt <= tick_cnt - 1; 
			end if;
			if bit_cnt = 0 then
				state <= RX_STOP;
			end if;
		when RX_STOP =>
			if	tick_cnt = 0 then
				if s2 = '1' then
					data_out <= shift_reg;
					rdy <= '1';
				else
					stop_bit_err <= '1';
				end if;	
				state <= IDLE;
			else
				tick_cnt <= tick_cnt - 1;
			end if;
		end case;
	end if;
end process rx_proc;	

end behav;


