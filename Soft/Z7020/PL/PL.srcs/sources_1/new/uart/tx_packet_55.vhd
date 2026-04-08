----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.11.2023 13:08:09
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity tx_packet_55 is  
    generic (
        BAUD_CODE : natural
    );
    Port ( 
        clk : in STD_LOGIC;
        clr : in STD_LOGIC;
        waddr : in std_logic_vector(2 downto 0);
        wdata : in std_logic_vector(31 downto 0);
        we : in std_logic;
        start : in std_logic;
        txd : out std_logic;
        rfd : out std_logic
  );
end tx_packet_55;

architecture Behavioral of tx_packet_55 is

constant BAUD_CODE_IN : integer := BAUD_CODE;

component uart_tx_min 
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
end component;

type T_STATE is (IDLE, TX, DUMMY);
signal state : T_STATE := IDLE;

signal uart_data : std_logic_vector(7 downto 0);
signal data_reg : std_logic_vector(255 downto 0);
signal uart_we : std_logic := '0';
signal uart_rfd : std_logic;
signal byte_cnt : std_logic_vector(5 downto 0);

begin

uart_tx : uart_tx_min PORT MAP(
	data_in => uart_data,
	nd => uart_we,
	ncts => '0',
	baud =>  conv_std_logic_vector(BAUD_CODE_IN, 16),
	serial_out => txd,
	rfd => uart_rfd,
	clk => clk
);

process(clk) 
begin
	if rising_edge(clk) then
		if we = '1' then
			if waddr = 0 then
				data_reg(31 downto 0) <= wdata; 
			elsif waddr = 1 then
				data_reg(63 downto 32) <= wdata; 
			elsif waddr = 2 then
				data_reg(95 downto 64) <= wdata; 
			elsif waddr = 3 then
				data_reg(127 downto 96) <= wdata; 
			elsif waddr = 4 then
				data_reg(159 downto 128) <= wdata; 
			elsif waddr = 5 then
				data_reg(191 downto 160) <= wdata; 
			elsif waddr = 6 then
				data_reg(223 downto 192) <= wdata; 
			elsif waddr = 7 then
				data_reg(255 downto 224) <= wdata;
			end if;
		end if;
		
		if clr = '1' then 
			state <= IDLE;
		else
			case state is
			when IDLE =>
				if start = '1' then
					byte_cnt <= (others => '0');
					rfd <= '1';
					state <= TX;
				else
					rfd <= '0';
				end if;	
			when TX =>	
				if uart_rfd = '1' then
					uart_we <= '1';
					uart_data <= data_reg(7 downto 0);
					data_reg(247 downto 0) <= data_reg(255 downto 8);
					byte_cnt <= byte_cnt + 1;
					state <= DUMMY;
				end if;
			when DUMMY =>
				uart_we <= '0';
				if byte_cnt = 32 then
					state <= IDLE;		
				else
					state <= TX;
				end if;
			end case;
		end if;
	end if;
end process;
							 

end Behavioral;
