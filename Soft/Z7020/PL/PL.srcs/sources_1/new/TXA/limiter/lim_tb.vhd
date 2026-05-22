--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:15:45 11/18/2022

--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

ENTITY lim_tb IS
END lim_tb;
 
ARCHITECTURE behavior OF lim_tb IS 
 
 COMPONENT lim_proc
 PORT(
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (3 downto 0);
        aclk : in STD_LOGIC
	  );
 END COMPONENT;
 
type inputFile_t is file of integer;
file integer_file: inputFile_t;
signal data : STD_LOGIC_VECTOR ( 31 downto 0 ) := (others => '0');
--Inputs
signal outdata: integer;

signal m_axis_audio_tdata : STD_LOGIC_VECTOR (23 downto 0);
signal m_axis_audio_tvalid : STD_LOGIC;
signal m_axis_iq_tdata : STD_LOGIC_VECTOR (47 downto 0);
signal m_axis_iq_tvalid : STD_LOGIC;
signal s_axis_audio_tdata : STD_LOGIC_VECTOR (23 downto 0) := (others => '0');
signal s_axis_audio_tvalid : STD_LOGIC := '0'; 
signal s_axis_cfg_tdata : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
signal s_axis_cfg_tdest : STD_LOGIC_VECTOR (2 downto 0) := (others => '0');
signal s_axis_cfg_tvalid : STD_LOGIC := '0';
signal lim_over : STD_LOGIC_VECTOR (3 downto 0);
signal aclk : STD_LOGIC;

-- Clock period definitions
constant FPGA_CLK_period : time := 500 ns;

BEGIN

-- Instantiate the Unit Under Test (UUT)
uut: lim_proc PORT MAP (
        m_axis_audio_tdata => m_axis_audio_tdata,
        m_axis_audio_tvalid => m_axis_audio_tvalid,
        m_axis_iq_tdata => m_axis_iq_tdata,
        m_axis_iq_tvalid => m_axis_iq_tvalid,
        s_axis_audio_tdata => s_axis_audio_tdata,
        s_axis_audio_tvalid => s_axis_audio_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest,
        s_axis_cfg_tvalid => s_axis_cfg_tvalid,
        lim_over => lim_over,
        aclk => aclk
    );

read_from_file: process
    variable indata: integer;
    file data_in: inputFile_t open read_mode is "E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\2700.raw";
    file data_out: inputFile_t open write_mode is "E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\audio_out.raw";
    begin        
        s_axis_audio_tvalid <= '0';
        wait for FPGA_CLK_period;
        read(data_in, indata);
        data <= std_logic_vector(to_signed(indata, 32));
        s_axis_audio_tdata <= data(31 downto 8);
  --     s_axis_audio_tdata <= x"000000";
        
        outdata <= to_integer(signed(m_axis_audio_tdata & x"00"));
        write(data_out, outdata);
        
        s_axis_audio_tvalid <= '1';
        wait for FPGA_CLK_period;
        s_axis_audio_tvalid <= '0';
        
        wait for FPGA_CLK_period * 123;
        if endfile(data_in) then
            report "end of file -- looping back to start of file";
            file_close(data_in);
            file_close(data_out);
            file_open(data_in,"E:\Projects\sdr200\Soft\Z7020\PL\PL.srcs\sources_1\new\TXA\limiter\300.raw");
        end if;
end process;

-- Clock process definitions
process
begin
loop_rxa: for i in 0 to 19 loop
    aclk <= '1';
	wait for FPGA_CLK_period/2;
	aclk <= '0';
	wait for FPGA_CLK_period/2;
end loop; 
	aclk <= '1';
	wait for FPGA_CLK_period/2;
	aclk <= '0';
	wait for FPGA_CLK_period/2;
end process;

-- command process
--cmd_proc: process
--begin	
--    s_axis_cfg_tvalid <= '0';
--    s_axis_cfg_tdest <= "000";
--    s_axis_cfg_tdata <= x"00000000";
--    
--    wait for FPGA_CLK_period;	
--    s_axis_cfg_tdest <= "000"; -- 0 lim_in_gain default "00" & x"3FFF"
--    s_axis_cfg_tdata <= x"00003FFF";
--    s_axis_cfg_tvalid <= '1';
--    wait for FPGA_CLK_period;
--    s_axis_cfg_tvalid <= '0';
--    	
--    wait for FPGA_CLK_period;	
--    s_axis_cfg_tdest <= "110"; -- CTRL bit 0 - enable
--    s_axis_cfg_tdata <= x"00000000";
--    s_axis_cfg_tvalid <= '1';
--    wait for FPGA_CLK_period;
--    s_axis_cfg_tvalid <= '0';
--     wait for FPGA_CLK_period;	
--    s_axis_cfg_tdest <= "000"; -- 0 lim_in_gain default "00" & x"3FFF"
--    s_axis_cfg_tdata <= x"000007FF";
--    s_axis_cfg_tvalid <= '1';	
--    
--	wait;
--end process;

-- load coeff
--load_coeff: process 
--    variable indata: integer;
--    variable ptr: integer := 0;
--    file data_in: inputFile_t open read_mode is "E:\Projects\StationVT\filters\txa_fos_1600.bin";
--    begin  
--        s_axis_cfg_tvalid <= '0';
--        s_axis_cfg_tdest <= "000";
--        s_axis_cfg_tdata <= x"00000000";
--        
--        wait for FPGA_CLK_period;	
--        s_axis_cfg_tdest <= "000"; -- 0 lim_in_gain default "00" & x"3FFF"
--        s_axis_cfg_tdata <= x"00003FFF";
--        s_axis_cfg_tvalid <= '1';
--        wait for FPGA_CLK_period;
--        s_axis_cfg_tvalid <= '0';
--            
--        wait for FPGA_CLK_period;	
--        s_axis_cfg_tdest <= "110"; -- CTRL bit 0 - enable
--        s_axis_cfg_tdata <= x"00000000";
--        s_axis_cfg_tvalid <= '1';
--        wait for FPGA_CLK_period;
--        s_axis_cfg_tvalid <= '0';
--         wait for FPGA_CLK_period;	
--        s_axis_cfg_tdest <= "000"; -- 0 lim_in_gain default "00" & x"3FFF"
--        s_axis_cfg_tdata <= x"000001FF";
--        s_axis_cfg_tvalid <= '1';
--        wait for FPGA_CLK_period;
--    
--        s_axis_cfg_tvalid <= '0';       
--        wait for 21 * FPGA_CLK_period;
--        
-- --       for k in 0 to 31 loop       -- 64 taps симметричная, поэтому грузим только половину
-- --           s_axis_cfg_tvalid <= '0'; 
-- --           wait for 4 * FPGA_CLK_period;
-- --           read(data_in, indata);
-- --           s_axis_cfg_tdata <= std_logic_vector(to_signed(indata, s_axis_cfg_tdata'length));
-- --           if endfile(data_in) then
-- --               report "end of file";
-- --               file_close(data_in);            
-- --               wait;                
-- --           end if;
-- --           
-- --           s_axis_cfg_tdest <= "101";
-- --           ptr := ptr + 1;
-- --           s_axis_cfg_tvalid <= '1';
-- --           wait for FPGA_CLK_period;
-- --       end loop;
-- --       s_axis_cfg_tvalid <= '0';
--        wait;
--end process;

END;
