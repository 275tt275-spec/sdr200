----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.06.2025 13:45:07
-- Design Name: 
-- Module Name: i2s - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity i2s is
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
end i2s;

architecture Behavioral of i2s is

    component ila_0 IS
    PORT (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        probe1 : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        probe3 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END component ila_0;
    
    component fifo_32x16 IS
    PORT (
        wr_clk : IN STD_LOGIC;
        rd_clk : IN STD_LOGIC;
        din : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        wr_en : IN STD_LOGIC;
        rd_en : IN STD_LOGIC;
        dout : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        full : OUT STD_LOGIC;
        empty : OUT STD_LOGIC
    );
    END component fifo_32x16;

    constant MCLK_DIVIDER : integer := 4;   -- 122.88 / 10 = 12.288
    constant BCLK_DIVIDER : integer := 5;   -- 0.016 * 32 * 2 MHz = 1.024 MHz
    constant WCLK_DIVIDER : integer := 383; -- 0.016 MHz
    signal mclk_cnt : std_logic_vector(4 downto 0) := (others => '0');
    signal bclk_cnt : std_logic_vector(3 downto 0) := (others => '0');
    signal mclk, bclk, wclk : std_logic := '0';
    signal din_shift, dout_shift : std_logic_vector (31 downto 0);
    signal dout_left, dout_right : std_logic_vector (23 downto 0);
    signal CLKFBIN : STD_LOGIC;
    signal rd_fifo : STD_LOGIC;
    signal bit_cnt : std_logic_vector(5 downto 0) := (others => '0');
    signal audio_valid, audio_valid_r : STD_LOGIC;
    signal d_audio_valid : STD_LOGIC;
    signal d_audio : std_logic_vector (23 downto 0);

begin

---- in 122.880 MHZ out 12.288 MHz
--MMCME2_BASE_inst : MMCME2_BASE
--generic map (
--   BANDWIDTH => "OPTIMIZED",  -- Jitter programming (OPTIMIZED, HIGH, LOW)
--   CLKFBOUT_MULT_F => 6.125,    -- Multiply value for all CLKOUT (2.000-64.000).
--   CLKFBOUT_PHASE => 0.0,     -- Phase offset in degrees of CLKFB (-360.000-360.000).
--   CLKIN1_PERIOD => 8.138,      -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
--   -- CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
--   CLKOUT1_DIVIDE => 1,
--   CLKOUT2_DIVIDE => 1,
--   CLKOUT3_DIVIDE => 1,
--   CLKOUT4_DIVIDE => 1,
--   CLKOUT5_DIVIDE => 1,
--   CLKOUT6_DIVIDE => 1,
--   CLKOUT0_DIVIDE_F => 61.25,   -- Divide amount for CLKOUT0 (1.000-128.000).
--   -- CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
--   CLKOUT0_DUTY_CYCLE => 0.5,
--   CLKOUT1_DUTY_CYCLE => 0.5,
--   CLKOUT2_DUTY_CYCLE => 0.5,
--   CLKOUT3_DUTY_CYCLE => 0.5,
--   CLKOUT4_DUTY_CYCLE => 0.5,
--   CLKOUT5_DUTY_CYCLE => 0.5,
--   CLKOUT6_DUTY_CYCLE => 0.5,
--   -- CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
--   CLKOUT0_PHASE => 0.0,
--   CLKOUT1_PHASE => 0.0,
--   CLKOUT2_PHASE => 0.0,
--   CLKOUT3_PHASE => 0.0,
--   CLKOUT4_PHASE => 0.0,
--   CLKOUT5_PHASE => 0.0,
--   CLKOUT6_PHASE => 0.0,
--   CLKOUT4_CASCADE => FALSE,  -- Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
--   DIVCLK_DIVIDE => 1,        -- Master division value (1-106)
--   REF_JITTER1 => 0.0,        -- Reference input jitter in UI (0.000-0.999).
--   STARTUP_WAIT => FALSE      -- Delays DONE until MMCM is locked (FALSE, TRUE)
--)
--port map (
--   -- Clock Outputs: 1-bit (each) output: User configurable clock outputs
--   CLKOUT0 => mclk,     -- 1-bit output: CLKOUT0
--   CLKOUT0B => open,   -- 1-bit output: Inverted CLKOUT0
--   CLKOUT1 => open,     -- 1-bit output: CLKOUT1
--   CLKOUT1B => open,   -- 1-bit output: Inverted CLKOUT1
--   CLKOUT2 => open,     -- 1-bit output: CLKOUT2
--   CLKOUT2B => open,   -- 1-bit output: Inverted CLKOUT2
--   CLKOUT3 => open,     -- 1-bit output: CLKOUT3
--   CLKOUT3B => open,   -- 1-bit output: Inverted CLKOUT3
--   CLKOUT4 => open,     -- 1-bit output: CLKOUT4
--   CLKOUT5 => open,     -- 1-bit output: CLKOUT5
--   CLKOUT6 => open,     -- 1-bit output: CLKOUT6
--   -- Feedback Clocks: 1-bit (each) output: Clock feedback ports
--   CLKFBOUT => CLKFBIN,   -- 1-bit output: Feedback clock
--   CLKFBOUTB => open, -- 1-bit output: Inverted CLKFBOUT
--   -- Status Ports: 1-bit (each) output: MMCM status ports
--   LOCKED => open,       -- 1-bit output: LOCK
--   -- Clock Inputs: 1-bit (each) input: Clock input
--   CLKIN1 => aclk,       -- 1-bit input: Clock
--   -- Control Ports: 1-bit (each) input: MMCM control ports
--   PWRDWN => '0',       -- 1-bit input: Power-down
--   RST => '0',             -- 1-bit input: Reset
--   -- Feedback Clocks: 1-bit (each) input: Clock feedback ports
--   CLKFBIN => CLKFBIN      -- 1-bit input: Feedback clock
--);

    i2s_mclk <= mclk;
    i2s_bclk <= bclk;
    
process(aclk)
begin
    if rising_edge(aclk) then    
        if mclk_cnt = MCLK_DIVIDER then
            mclk_cnt <= (others => '0');
            mclk <= not mclk;
        else
            mclk_cnt <= mclk_cnt + 1;
        end if;
    end if;
end process;
    
process(mclk)
begin
    if rising_edge(mclk) then    
        if bclk_cnt = BCLK_DIVIDER then
            bclk_cnt <= (others => '0');
            bclk <= not bclk;
        else
            bclk_cnt <= bclk_cnt + 1;
        end if;
    end if;
end process;

fifo_in_0 : fifo_32x16
    PORT MAP (
        wr_clk => aclk,
        rd_clk => bclk,
        din => s_axis_audioL_tdata,
        wr_en => s_axis_audio_tvalid,
        rd_en => rd_fifo,
        dout => dout_left,
        full => open,
        empty => open
    );
    
fifo_in_1 : fifo_32x16
    PORT MAP (
        wr_clk => aclk,
        rd_clk => bclk,
        din => s_axis_audioR_tdata,
        wr_en => s_axis_audio_tvalid,
        rd_en => rd_fifo,
        dout => dout_right,
        full => open,
        empty => open
    );
    
    i2s_wclk <= wclk;
    i2s_dout <= dout_shift(31);

process(bclk)
begin
    if falling_edge(bclk) then
        rd_fifo <= '0';
        dout_shift <= dout_shift(30 downto 0) & dout_shift(31);
        audio_valid <= '0';
        if bit_cnt = 63 then
            bit_cnt <= (others => '0');
            wclk <= '1';
            dout_shift <= dout_left(23) & dout_left(23) & dout_left(23) & dout_left(23) &
                                dout_left(23) & dout_left(23) & dout_left(23) & dout_left(23) &
                                dout_left; 
            m_axis_audioR_tdata <= din_shift(23 downto 0); 
            audio_valid <= '1';                                              
        else
            bit_cnt <= bit_cnt + 1;
            if bit_cnt = 31 then
                wclk <= '0';
                dout_shift <= dout_right(23) & dout_right(23) & dout_right(23) & dout_right(23) &
                                dout_right(23) & dout_right(23) & dout_right(23) & dout_right(23) &
                                dout_right; 
                m_axis_audioL_tdata <= din_shift(23 downto 0);
                d_audio <= din_shift(23 downto 0); 
            elsif bit_cnt = 30 then
                rd_fifo <= '1';
            end if;                        
        end if;
    end if;
    
    if rising_edge(bclk) then
        din_shift <= din_shift(30 downto 0) & i2s_din; 
    end if;
    
end process;   

process(aclk)
begin
    if rising_edge(aclk) then
        audio_valid_r <= audio_valid;
        m_axis_audio_tvalid <= '0';
        d_audio_valid <= '0';
        if audio_valid_r /= audio_valid and audio_valid = '1' then 
            m_axis_audio_tvalid <= '1';
            d_audio_valid <= '1';
        end if;
    end if;
end process;


--debug_0 : ila_0
--    PORT MAP (
--        clk => aclk,
--        probe0 => d_audio,
--        probe1 => bit_cnt,
--        probe2(0) => bclk,
--        probe3(0) => d_audio_valid
--    );

end Behavioral;

