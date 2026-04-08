----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.09.2023 12:06:56
-- Design Name: 
-- Module Name: valid32Khz - Behavioral
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


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
-- use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity uart_packet is
    Port ( 
	    s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (3 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC; 
        rx_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        rx_enable : out STD_LOGIC;
        s_cfg_read : in STD_LOGIC;
        rx_data : in STD_LOGIC; 
        tx_data : out STD_LOGIC; 
        tx_progress : out STD_LOGIC; 
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end uart_packet;

architecture Behavioral of uart_packet is

    constant FPGA_CLOCK : integer := 122880000;
    constant BAUD_CODE : integer := FPGA_CLOCK / 115200 - 1;
    signal clr, we, start : std_logic := '0';
    signal addr : std_logic_vector (2 downto 0) := (others => '0');
    signal rdata : std_logic_vector (31 downto 0);
    signal frame_confirm : std_logic := '0';
    signal start_r, start_r1 : std_logic := '0';
    
    COMPONENT tx_packet_55
    generic (
        BAUD_CODE : natural
    );
    PORT (
        clk : in STD_LOGIC;
        clr : in STD_LOGIC;
        waddr : in std_logic_vector(2 downto 0);
        wdata : in std_logic_vector(31 downto 0);
        we : in std_logic;
        start : in std_logic;
        txd : out std_logic;
        rfd : out std_logic
    );
   END COMPONENT tx_packet_55; 
   
    COMPONENT rx_packet_55
    generic (
        BAUD_CODE : natural
    );
    PORT (
        clk : in  STD_LOGIC;
        clr : in  STD_LOGIC;
        rxd : in  STD_LOGIC;
        raddr : in  STD_LOGIC_VECTOR (2 downto 0);
        rdata : out  STD_LOGIC_VECTOR (31 downto 0);
        frame_rdy : out STD_LOGIC;
        frame_confirm : in STD_LOGIC
    );
   END COMPONENT rx_packet_55; 

begin

    clr <= not aresetn;
    we <= s_axis_cfg_tvalid when s_axis_cfg_tdest(3 downto 3) = "0";       -- x"0" - x"7"    
    frame_confirm <= s_cfg_read when s_axis_cfg_tdest = x"F" else '0';
    rx_tdata <= rdata(7 downto 0) & rdata(15 downto 8) & rdata(23 downto 16) & rdata(31 downto 24);
    
process(aclk)
begin
	if rising_edge(aclk) then
	    if s_axis_cfg_tvalid = '1' and s_axis_cfg_tdest = x"7" then
	       start_r <= '1';
	    else
	       start_r <= '0';  
	    end if;  		
		start_r1 <= start_r;	
		if start_r1 = '1' and start_r = '0'	then
		  start <= '1';
		else
		  start <= '0';
        end if;
	end if;
end process;

rx : rx_packet_55
    generic map(
        BAUD_CODE => BAUD_CODE
    )
    port map(
        clk => aclk,
        clr => clr,
        rxd => rx_data,
        raddr => s_axis_cfg_tdest(2 downto 0),
        rdata => rdata,
        frame_rdy => rx_enable,
        frame_confirm => frame_confirm
    );
    
tx : tx_packet_55
    generic map(
        BAUD_CODE => BAUD_CODE
    )
    port map(
        clk => aclk,
        clr => clr,
        waddr => s_axis_cfg_tdest(2 downto 0),
        wdata => s_axis_cfg_tdata,
        we => we,
        start => start,
        txd => tx_data,
        rfd => tx_progress
    );   


end Behavioral;
