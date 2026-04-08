-- UART Transmitter with integral 1024 byte FIFO buffer
--
-- 26-May-2010			Ver. 2

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
------------------------------------------------------------------------------------
--
-- Main Entity for UART_TX
--
entity uart_tx_min is
    Port (
        data_in : in std_logic_vector(7 downto 0);
        nd : in std_logic;
        ncts : in std_logic;
        baud : in std_logic_vector(15 downto 0);
        serial_out : out std_logic;
        tx_on : out std_logic;
        rfd : out std_logic;
        clk : in std_logic
    );
end uart_tx_min;

architecture behav of uart_tx_min is

------------
-- TYPES
------------
type TX_STATE is (IDLE, TX_DATA); 
------------------------------------------------------------------------------------
-- Signals u
------------------------------------------------------------------------------------
--
signal shift_reg       : std_logic_vector(8 downto 0);
signal tick_cnt		 : std_logic_vector(15 downto 0);	
signal bit_cnt		 : std_logic_vector(3 downto 0);	
signal serial_out_int, rfd_i : std_logic := '1'; 
signal state : TX_STATE := IDLE;

------------------------------------------------------------------------------------
-- Start of UART_TX circuit description
------------------------------------------------------------------------------------
--	
begin

serial_out <= serial_out_int;
rfd <= rfd_i;

tx_proc : process(clk)
begin
	if rising_edge(clk) then
		case state IS
		when IDLE =>
			serial_out_int <= '1';
			if ncts = '1' then
				rfd_i <= '0';
			elsif nd = '1' then
				rfd_i <= '0';
				shift_reg <= '1' & data_in;
				tick_cnt <= baud;
				serial_out_int <= '0';	-- start-bit
				bit_cnt <= "1010";		-- +stop-bit
				tx_on <= '1';
				state <= TX_DATA;
			else
				rfd_i <= '1';
				tx_on <= '0';
			end if;	
		when TX_DATA =>
			if tick_cnt = 0 then
				bit_cnt <= bit_cnt - 1; 
				if bit_cnt = 0 then
					state <= IDLE;
				else
					tick_cnt <= baud;
					serial_out_int <= shift_reg(0);
					shift_reg <= '1' & shift_reg(8 downto 1);
				end if;
			else
				tick_cnt <= tick_cnt - 1;
			end if;
		end case;
	end if;
end process tx_proc;	

end behav;


