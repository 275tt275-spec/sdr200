----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.07.2026 11:05:52
-- Design Name: 
-- Module Name: conv16x24 - Behavioral
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
--library UNISIM;
--use UNISIM.VComponents.all;

entity conv16x24 is
    port (
        aclk            : in  std_logic;
        aresetn         : in  std_logic;
        out_en          : in  std_logic;
        mult_in_tdata   : in  std_logic_vector(31 downto 0);
        dds_cfg_tdata   : in  std_logic_vector(31 downto 0);
        dds_cfg_tvalid  : in std_logic;
        dds_out_tdata   : out  std_logic_vector(47 downto 0);
        dac_tdata       : out std_logic_vector(15 downto 0)
    );
end conv16x24;

architecture Behavioral of conv16x24 is

    component mult16x16 is
        port (
            aclk            : in  std_logic;
            aresetn         : in  std_logic;
            txa_on          : in  std_logic;
            mult_in_tdata   : in  std_logic_vector(31 downto 0);
            dds_in_tdata    : in  std_logic_vector(47 downto 0);
            dac_tdata       : out std_logic_vector(15 downto 0)
        );
    end component mult16x16;
    
    component dds_24_unit is
        port (
            aclk : IN STD_LOGIC;
            aclken : IN STD_LOGIC;
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
        );
    end component dds_24_unit;
    
    signal dds_data   : std_logic_vector(47 downto 0);

begin

    dds_out_tdata <= dds_data;
    
dds_0 : dds_24_unit        
    port map(
        aclk                    => aclk,
        aclken                  => '1',
        s_axis_config_tvalid    => dds_cfg_tvalid,
        s_axis_config_tdata     => dds_cfg_tdata,
        m_axis_data_tvalid      => open,
        m_axis_data_tdata       => dds_data
    );

mult_0 : mult16x16
    port map (
        aclk            => aclk,
        aresetn         => aresetn,
        txa_on          => out_en,
        mult_in_tdata   => mult_in_tdata,
        dds_in_tdata    => dds_data,
        dac_tdata       => dac_tdata
    );


end Behavioral;
