----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.10.2025 18:18:44
-- Design Name: 
-- Module Name: rxa_wb_tb - Behavioral
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
use IEEE.STD_LOGIC_arith.ALL;
use IEEE.STD_LOGIC_signed.ALL;


entity txa_i2s_tb is
--  Port ( );
end txa_i2s_tb;

architecture Behavioral of txa_i2s_tb is

 COMPONENT i2s is
     Port ( 
        aclk : in STD_LOGIC;
        s_axis_audioL_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audioR_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        m_axis_audioL_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audioR_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        i2s_mclk : out STD_LOGIC;
        i2s_bclk : out STD_LOGIC;
        i2s_wclk : out STD_LOGIC;
        i2s_dout : out STD_LOGIC;
        i2s_din : in STD_LOGIC
    );
 END COMPONENT i2s;
 
 COMPONENT dds_test_0 IS
  PORT (
    aclk : IN STD_LOGIC;
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_phase_tvalid : OUT STD_LOGIC;
    m_axis_phase_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT dds_test_0;

	signal aclk : STD_LOGIC;
    signal s_axis_audioL_tdata : STD_LOGIC_VECTOR (23 downto 0) := (others => '0');
    signal s_axis_audioR_tdata : STD_LOGIC_VECTOR (23 downto 0) := (others => '0');
    signal s_axis_audio_tvalid : STD_LOGIC := '0';
    signal m_axis_audioL_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal m_axis_audioR_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal m_axis_audio_tvalid : STD_LOGIC;
    signal i2s_mclk : STD_LOGIC;
    signal i2s_bclk : STD_LOGIC;
    signal i2s_wclk, i2s_wclk_r : STD_LOGIC;
    signal i2s_dout : STD_LOGIC;
    signal i2s_din : STD_LOGIC := '0';
    signal i2s_shift : STD_LOGIC_VECTOR (63 downto 0); 
    signal dds_data : STD_LOGIC_VECTOR (47 downto 0);
    signal bit_cnt : std_logic_vector(5 downto 0) := (others => '0');
    
    constant FPGA_CLK_period : time := 8.138 ns;

begin

uut: i2s PORT MAP (
        aclk => aclk,
        s_axis_audioL_tdata => s_axis_audioL_tdata,
        s_axis_audioR_tdata => s_axis_audioR_tdata,
        s_axis_audio_tvalid => s_axis_audio_tvalid,
        m_axis_audioL_tdata => m_axis_audioL_tdata,
        m_axis_audioR_tdata => m_axis_audioR_tdata,
        m_axis_audio_tvalid => m_axis_audio_tvalid,
        i2s_mclk => i2s_mclk,
        i2s_bclk => i2s_bclk,
        i2s_wclk => i2s_wclk,
        i2s_dout => i2s_dout,
        i2s_din => i2s_din
    );
    
dds: dds_test_0 PORT MAP (
        aclk => i2s_wclk,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_data,
        m_axis_phase_tvalid => open,
        m_axis_phase_tdata => open
    );
    
process
begin
	aclk <= '1';
	wait for FPGA_CLK_period/2;
	aclk <= '0';
	wait for FPGA_CLK_period/2;
end process;

process (i2s_bclk)
begin
    if falling_edge(i2s_bclk) then
        i2s_din <= i2s_shift(63);
        i2s_shift <= i2s_shift(62 downto 0) & "0";
        i2s_wclk_r <= i2s_wclk;
        if (i2s_wclk_r /= i2s_wclk) and (i2s_wclk = '1') then
            bit_cnt <= (others => '0');   
            
        else
            bit_cnt <= bit_cnt + 1;
            if bit_cnt = 61 then
                i2s_shift <= x"00" & dds_data(23 downto 0) & x"00" & dds_data(23 downto 0);
            end if;
        end if;
        
    end if;
end process;


end Behavioral;
