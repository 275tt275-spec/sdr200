----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.04.2026 13:28:49
-- Design Name: 
-- Module Name: system_gpio - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity system_gpio is
    Port (
        gpio_o : in STD_LOGIC_VECTOR ( 19 downto 0 );
        gpio_i : out STD_LOGIC_VECTOR ( 19 downto 0 );
        gpio_t : in STD_LOGIC_VECTOR ( 19 downto 0 ); 
        vga_de : inout STD_LOGIC;
        vga_mode : inout STD_LOGIC;
        vga_ud : inout STD_LOGIC;
        vga_dithb : inout STD_LOGIC;
        vga_rst : inout STD_LOGIC;
        vga_lr : inout STD_LOGIC;
        btn_lsb : inout STD_LOGIC;
        btn_usb : inout STD_LOGIC;
        btn_am: inout STD_LOGIC;
        btn_fm : inout STD_LOGIC;
        btn_dig : inout STD_LOGIC;
        btn_cw : inout STD_LOGIC;
        btn_tune : inout STD_LOGIC;
        btn_band2 : inout STD_LOGIC;
        btn_band3 : inout STD_LOGIC;
        btn_band4 : inout STD_LOGIC;
        btn_band5 : inout STD_LOGIC;
        btn_band6 : inout STD_LOGIC;
        btn_band7 : inout STD_LOGIC;
        btn_band8 : inout STD_LOGIC
    );
end system_gpio;

architecture Behavioral of system_gpio is

  ATTRIBUTE X_INTERFACE_INFO : STRING;
  ATTRIBUTE X_INTERFACE_INFO of gpio_o: SIGNAL is "xilinx.com:interface:gpio_rtl:1.0 GPIO TRI_O";
  ATTRIBUTE X_INTERFACE_INFO of gpio_i: SIGNAL is "xilinx.com:interface:gpio_rtl:1.0 GPIO TRI_I";
  ATTRIBUTE X_INTERFACE_INFO of gpio_t: SIGNAL is "xilinx.com:interface:gpio_rtl:1.0 GPIO TRI_T";

begin

i_vga_de : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(0),     
       IO => vga_de,  
       I => gpio_o(0),   
       T => gpio_t(0)  
    );
    
i_vga_mode : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(1),     
       IO => vga_mode,  
       I => gpio_o(1),   
       T => gpio_t(1)  
    );
    
i_vga_ud : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(2),     
       IO => vga_ud,  
       I => gpio_o(2),   
       T => gpio_t(2)  
    );
    
i_vga_dithb : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(3),     
       IO => vga_dithb,  
       I => gpio_o(3),   
       T => gpio_t(3)  
    );
    
i_vga_rst : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(4),     
       IO => vga_rst,  
       I => gpio_o(4),   
       T => gpio_t(4)  
    );
    
i_vga_lr : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS33",
       SLEW => "SLOW")
    port map (
       O => gpio_i(5),     
       IO => vga_lr,  
       I => gpio_o(5),   
       T => gpio_t(5)  
    );
    
i_btn_lsb : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(6),     
       IO => btn_lsb,  
       I => gpio_o(6),   
       T => gpio_t(6)  
    );      
    
i_btn_usb : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(7),     
       IO => btn_usb,  
       I => gpio_o(7),   
       T => gpio_t(7)  
    );
    
i_btn_am : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(8),     
       IO => btn_am,  
       I => gpio_o(8),   
       T => gpio_t(8)  
    );
    
i_btn_fm : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(9),     
       IO => btn_fm,  
       I => gpio_o(9),   
       T => gpio_t(9)  
    );
    
i_btn_dig : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(10),     
       IO => btn_dig,  
       I => gpio_o(10),   
       T => gpio_t(10)  
    );
    
i_btn_cw : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(11),     
       IO => btn_cw,  
       I => gpio_o(11),   
       T => gpio_t(11)  
    );
    
i_btn_tune : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(12),     
       IO => btn_tune,  
       I => gpio_o(12),   
       T => gpio_t(12)  
    );
    
i_btn_band2 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(13),     
       IO => btn_band2,  
       I => gpio_o(13),   
       T => gpio_t(13)  
    );
    
i_btn_band3 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(14),     
       IO => btn_band3,  
       I => gpio_o(14),   
       T => gpio_t(14)  
    );
    
i_btn_band4 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(15),     
       IO => btn_band4,  
       I => gpio_o(15),   
       T => gpio_t(15)  
    );
    
i_btn_band5 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(16),     
       IO => btn_band5,  
       I => gpio_o(16),   
       T => gpio_t(16)  
    );
    
i_btn_band6 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(17),     
       IO => btn_band6,  
       I => gpio_o(17),   
       T => gpio_t(17)  
    );
    
i_btn_band7 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(18),     
       IO => btn_band7,  
       I => gpio_o(18),   
       T => gpio_t(18)  
    );
    
i_btn_band8 : IOBUF
    generic map (
       DRIVE => 4,
       IOSTANDARD => "LVCMOS25",
       SLEW => "SLOW")
    port map (
       O => gpio_i(19),     
       IO => btn_band8,  
       I => gpio_o(19),   
       T => gpio_t(19)  
    );
     
end Behavioral;
