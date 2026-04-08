----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.11.2022 15:34:11

----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity serializer is
    Generic(
        ACLK_FREQ : natural := 122880000
    );
    Port (
        aclk : in STD_LOGIC;
--        clk_ser : in STD_LOGIC;
--        locked : in STD_LOGIC;
        
        s_axis_wb_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_wb_tvalid : in STD_LOGIC;
        s_axis_ch2_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_ch2_tvalid : in STD_LOGIC;
        
        gpio_in : in STD_LOGIC_VECTOR (5 downto 0);
        
        RF_DATAOUT_N : out std_logic;
        RF_DATAOUT_P : out std_logic;  
        RF_CLOCKOUT_N : out std_logic;
        RF_CLOCKOUT_P : out std_logic  
    );
end serializer;

architecture Behavioral of serializer is

    type T_STATE is (S0, S1, S2, S3, S4, S5);
    signal state : T_STATE;
    
    type T_STATE_IN is (IDLE, S0);
    signal state_in : T_STATE_IN := IDLE;
    
    constant CLK_DIVIDER : integer := 5; -- out 10.240 MHz
    
    signal shift_reg : std_logic_vector(11 downto 0);
    signal data_ddr, ddr_d1, ddr_d2 : std_logic;
    signal sync_cnt : std_logic_vector(12 downto 0) := (others => '0');
    signal ser_init : std_logic := '1';
    signal ser_rfd : std_logic := '0';
    signal din : std_logic_vector(9 downto 0);
    signal spi0_cs : std_logic := '1';
    signal spi1_cs : std_logic := '1';    
    signal bit_cnt : std_logic_vector(7 downto 0);
    signal rx_data_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_rdy_r, rx_rdy_r1, data_fmt_nd, rx_rdy_toggle : std_logic := '0';
    signal clk_ser : std_logic := '0';
    signal clk_out : std_logic;
    signal clk_cnt : std_logic_vector(3 downto 0) := (others => '0');
    signal rx_data_0r, rx_data_1r : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_data_0, rx_data_1 : std_logic_vector(31 downto 0) := (others => '0');

begin
    
    din(0) <= spi0_cs;
    din(1) <= rx_data_0(31);
    din(2) <= spi1_cs;
    din(3) <= rx_data_1(31);
    din(9 downto 4) <= gpio_in;

    ddr_d1 <= not shift_reg(0);
    ddr_d2 <= not shift_reg(1);

out_ddr : ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE", 
      INIT => '0',   -- Initial value for Q port ('1' or '0')
      SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
   port map (
      Q => data_ddr,   -- 1-bit DDR output
      C => clk_ser,  -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D1 => ddr_d1,  -- 1-bit data input (positive edge)
      D2 => ddr_d2,  -- 1-bit data input (negative edge)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );

out_buf : OBUFDS
   port map (
      O => RF_DATAOUT_P,
      OB => RF_DATAOUT_N,
      I => data_ddr      -- Buffer input 
   );
 
-- 122.880 MHz   
out_clk : OBUFDS
   port map (
      O => RF_CLOCKOUT_P,
      OB => RF_CLOCKOUT_N,
      I => clk_out      -- Buffer input 
   );
   
process(aclk)
begin
    if rising_edge(aclk) then    
        if clk_cnt = CLK_DIVIDER then
            clk_cnt <= (others => '0');
            clk_out <= not clk_out;
        else
            clk_cnt <= clk_cnt + 1;
        end if;
    end if;
end process;

process(clk_ser)
begin
	if rising_edge(clk_ser) then
        case state is
        when S0 =>
             if ser_init = '0' then
                shift_reg <= '0' & din & '1';
             else
                shift_reg <= "000000000001";   
             end if;   
             ser_rfd <= '1';
             state <= S1;
        when S1 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            ser_rfd <= '0';
            state <= S2;
        when S2 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S3;
        when S3 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S4;
        when S4 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S5;
        when S5 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S0;
        end case;
    end if;
end process;

process(clk_ser)
begin
	if rising_edge(clk_ser) then
 
		case state_in is
		when IDLE =>
			if data_fmt_nd = '1' then
				rx_data_0 <= rx_data_0r;
				rx_data_1 <= rx_data_1r;
				spi0_cs <= '0';
				spi1_cs <= '0';
				bit_cnt <= (others => '0');
				state_in <= S0;
			else
				spi0_cs <= '1';
				spi1_cs <= '1';
			end if;
		when S0 =>
			if ser_rfd = '1' then
				rx_data_0(31 downto 1) <= rx_data_0(30 downto 0);
				rx_data_1(31 downto 1) <= rx_data_1(30 downto 0);
				if bit_cnt = 31 then
					state_in <= IDLE;
				else
					bit_cnt <= bit_cnt + 1;
				end if;
			end if;
		end case;
		
		-- Sync RX ready		
        rx_rdy_r <= rx_rdy_toggle;
        rx_rdy_r1 <= rx_rdy_r;
        if rx_rdy_r /= rx_rdy_r1 then
            data_fmt_nd <= '1';
        else
            data_fmt_nd <= '0';
        end if;	
				
	end if;
end process;	

process(aclk)
begin
	if rising_edge(aclk) then
	   clk_ser <= not clk_ser;
	   	if s_axis_wb_tvalid = '1' then 
	       rx_data_0r <= s_axis_wb_tdata;
	       rx_data_valid(0) <= '1';
	    end if;  
	    if s_axis_ch2_tvalid = '1' then 
	       rx_data_1r <= s_axis_ch2_tdata;
	       rx_data_valid(1) <= '1';
	    end if; 
	    
	    if rx_data_valid = "11" then
	       rx_rdy_toggle <= not rx_rdy_toggle;
	       rx_data_valid <= (others => '0');	
       end if;			
	end if;
end process;
		
end Behavioral;
