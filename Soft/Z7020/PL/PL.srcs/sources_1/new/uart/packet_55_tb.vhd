----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.11.2023 13:51:11

----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity packet_55_tb is
end packet_55_tb;

architecture Behavioral of packet_55_tb is

component tx_packet_55  
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
end component;

component rx_packet_55 
	Port ( 
   	clk : in  STD_LOGIC;
		clr : in  STD_LOGIC;
		rxd : in  STD_LOGIC;
		raddr : in  STD_LOGIC_VECTOR (2 downto 0);
		rdata : out  STD_LOGIC_VECTOR (31 downto 0);
		frame_rdy : out  STD_LOGIC;
		frame_confirm : in  STD_LOGIC
	);
end component;

signal clk, clr, serial, frame_rdy, tx_rfd : std_logic;
signal we, start, frame_confirm : std_logic := '0';
signal raddr, waddr : std_logic_vector(2 downto 0);
signal rdata, wdata : std_logic_vector(31 downto 0);

constant clk_period : time := 10 ns;

begin

tx : tx_packet_55 port map (
	clk => clk,
	clr => clr,
	waddr => waddr,
	wdata => wdata,
	we => we,
	start => start,
	txd => serial,
	rfd => tx_rfd
);

uut1: rx_packet_55 PORT MAP(
		clk => clk,
		clr => clr,
		rxd => serial,
		raddr => raddr,
		rdata => rdata,
		frame_rdy => frame_rdy,
		frame_confirm => frame_confirm
	);

clk_process :process
begin
	clk <= '0';
	wait for clk_period/2;
	clk <= '1';
	wait for clk_period/2;
end process;

process
begin
	clr <= '1';		-- reset isn't mandatory
	wait for 100 ns;
	clr <= '0';
-- load tx
	waddr <= "000";
	wdata <= x"04030255";
	we <= '1';
	wait for clk_period;
	waddr <= "001";
	wdata <= x"08070605";
	wait for clk_period;
	waddr <= "010";
	wdata <= x"09080706";
	we <= '1';
	wait for clk_period;
	waddr <= "011";
	wdata <= x"0d0c0b0a";
	we <= '1';
	wait for clk_period;
	waddr <= "100";
	wdata <= x"11100f0e";
	we <= '1';
	wait for clk_period;
	waddr <= "101";
	wdata <= x"15141312";
	we <= '1';
	wait for clk_period;
	waddr <= "110";
	wdata <= x"19181716";
	we <= '1';
	wait for clk_period;
	waddr <= "111";
	wdata <= x"1d1c1b1a";
	wait for clk_period;
	we <= '0';
-- start tx	
	if tx_rfd = '1' then
		start <= '1';
	end if;
	wait for clk_period;
	start <= '0';
	
	wait for 3 ms;
	
	if frame_rdy = '1' then
-- read data from RX
		raddr <= "000";
		wait for clk_period;
		raddr <= "001";
		wait for clk_period;
		raddr <= "010";
		wait for clk_period;
		raddr <= "011";
		wait for clk_period;
		raddr <= "100";
		wait for clk_period;
		raddr <= "101";
		wait for clk_period;
		raddr <= "110";
		wait for clk_period;
		raddr <= "111";
		wait for clk_period;
-- confirm frame			 
		frame_confirm <= '1';
		wait for clk_period;
		frame_confirm <= '0';
	end if;
		
	wait;
	
end process;
		
end Behavioral;
