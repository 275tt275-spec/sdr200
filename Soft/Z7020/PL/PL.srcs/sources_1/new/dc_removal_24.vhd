----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.04.2023 18:40:02
-- Design Name: 
-- Module Name: dc_removal - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dc_removal_24 is
    generic(
        ALPHA_WIDTH : natural := 8
    );
    port(
        -- The clock domain used for all interfaces.
        clk : in std_logic;

        -- synchronous reset
        rst : in std_logic;

        -- enable automatic removal
        enable : in std_logic;

        -- input bus interface
        in_tdata : in std_logic_vector(23 downto 0);
        in_tvalid : in std_logic;
        in_tready : out std_logic;

        -- output bus interface
        out_tdata : out std_logic_vector(23 downto 0);
        out_tvalid : out std_logic;
        out_tready : in std_logic
    );
end dc_removal_24;

architecture Behavioral of dc_removal_24 is

    constant DATA_WIDTH : positive := in_tdata'length;
    constant NUM_WIDTH : positive := DATA_WIDTH + ALPHA_WIDTH;

    signal out_num : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal last_avg : signed(NUM_WIDTH-1 downto 0) := (others => '0');
    signal next_avg : signed(NUM_WIDTH-1 downto 0) := (others => '0');
    
begin

--    out_tvalid <= in_tvalid;
    in_tready <= out_tready;
    out_tdata <= std_logic_vector(out_num) when (enable = '1') else in_tdata;

    --integration equation
    next_avg <= out_num + last_avg;

    process (clk) begin
        if (rising_edge(clk)) then            
            if (rst = '1') then
                last_avg <= to_signed(0, NUM_WIDTH);
                out_num <= to_signed(0, DATA_WIDTH);
            elsif (in_tvalid = '1' and out_tready = '1') then
                out_tvalid <= in_tvalid;
                last_avg <= next_avg;
                out_num <= signed(in_tdata) - last_avg(NUM_WIDTH-1 downto NUM_WIDTH-DATA_WIDTH);
            end if;
        end if;
    end process;


end Behavioral;
