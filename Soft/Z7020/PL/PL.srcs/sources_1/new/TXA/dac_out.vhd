----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.10.2023 20:16:52
-- Design Name: 
-- Module Name: dac_out - Behavioral
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

entity dac_out is
    Port ( aclk : in STD_LOGIC;
           aresetn : in STD_LOGIC;
           s_daci_tdata : in STD_LOGIC_VECTOR (15 downto 0);
           s_dacq_tdata : in STD_LOGIC_VECTOR (15 downto 0);
           m_dout_p : out STD_LOGIC_VECTOR (15 downto 0);
           m_dout_n : out STD_LOGIC_VECTOR (15 downto 0);
           m_dci_p : out STD_LOGIC;
           m_dci_n : out STD_LOGIC;
           s_dco_p : in STD_LOGIC;
           s_dco_n : in STD_LOGIC
           );
end dac_out;

architecture Behavioral of dac_out is

    COMPONENT clock_converter_32_0 is
        Port (
            s_axis_aresetn : in STD_LOGIC;
            m_axis_aresetn : in STD_LOGIC;
            s_axis_aclken : in STD_LOGIC;
            m_axis_aclken : in STD_LOGIC;
            s_axis_aclk : in STD_LOGIC;
            s_axis_tvalid : in STD_LOGIC;
            s_axis_tready : out STD_LOGIC;
            s_axis_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
            m_axis_aclk : in STD_LOGIC;
            m_axis_tvalid : out STD_LOGIC;
            m_axis_tready : in STD_LOGIC;
            m_axis_tdata : out STD_LOGIC_VECTOR ( 31 downto 0 )
        );
    END COMPONENT clock_converter_32_0;

    signal nclk : std_logic;
    signal dci : std_logic;
    signal dco, dco_clk, dac_retsetn : std_logic;
    signal dout_i, dout_q : STD_LOGIC_VECTOR (15 downto 0);
    signal dout : STD_LOGIC_VECTOR (15 downto 0);
    signal dint_in, dint_out: STD_LOGIC_VECTOR (31 downto 0);
    
begin

    nclk <= not dco_clk;
    dint_in <= s_daci_tdata & s_dacq_tdata;    
    dout_i <= dint_out(31 downto 16); 
    dout_q <= dint_out(15 downto 0);  
    
clock_converter_0: clock_converter_32_0
    port map (
        m_axis_aclk => dco_clk,
        m_axis_aresetn => dac_retsetn,
        s_axis_aclken => '1',
        m_axis_aclken => '1',
        m_axis_tdata => dint_out,
        m_axis_tready => '1',
        m_axis_tvalid => open,
        s_axis_aclk => aclk,
        s_axis_aresetn => aresetn,
        s_axis_tdata => dint_in,
        s_axis_tready => open,
        s_axis_tvalid => '1'
    );
    
FDRE_inst : FDRE
generic map (
   INIT => '1') -- Initial value of register ('0' or '1')
port map (
   Q => dac_retsetn,   -- Data output
   C => dco_clk,       -- Clock input
   CE => '1',          -- Clock enable input
   R => '0',           -- Synchronous reset input
   D => aresetn        -- Data input
);
     
dco_ibufds : IBUFDS
    generic map (
        DIFF_TERM => TRUE, -- Differential Termination 
        IBUF_LOW_PWR => FALSE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
        IOSTANDARD => "DEFAULT")
    port map (
        O => dco,
        I => s_dco_p,
        IB => s_dco_n
    ); 
    
BUFR_inst : BUFR
generic map (
   BUFR_DIVIDE => "BYPASS",   -- Values: "BYPASS, 1, 2, 3, 4, 5, 6, 7, 8"
   SIM_DEVICE => "7SERIES"  -- Must be set to "7SERIES"
)
port map (
   O => dco_clk,     -- 1-bit output: Clock output port
   CE => '1',   -- 1-bit input: Active high, clock enable (Divided modes only)
   CLR => '0', -- 1-bit input: Active high, asynchronous clear (Divided modes only)
   I => dco      -- 1-bit input: Clock buffer input driven by an IBUF, MMCM or local interconnect
);
    
--dco_clk_bufio : BUFIO
--    port map (
--       O => dco_clk, -- 1-bit output: Clock output
--       I => dco  -- 1-bit input: Clock input
--    );
    
lbl : for k in 0 to 15 generate
begin
 data_oddr : ODDR2
   generic map(
      DDR_ALIGNMENT => "C1", -- Sets output alignment to "NONE", "C0", "C1" 
      INIT => '0', -- Sets initial state of the Q output to '0' or '1'
      SRTYPE => "ASYNC") -- Specifies "SYNC" or "ASYNC" set/reset
   port map (
      Q => dout(k), -- 1-bit output data
      C0 => dco_clk, -- 1-bit clock input
      C1 => nclk, -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D0 => dout_i(k),   -- 1-bit data input (associated with C0)
      D1 => dout_q(k),   -- 1-bit data input (associated with C1)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );
data_obufdf : OBUFDS
generic map (
   IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
   SLEW => "SLOW")          -- Specify the output slew rate
port map (
   O => m_dout_p(k),     -- Diff_p output (connect directly to top-level port)
   OB => m_dout_n(k),   -- Diff_n output (connect directly to top-level port)
   I => dout(k)      -- Buffer input
);
end generate;

dci_oddr : ODDR2
   generic map(
      DDR_ALIGNMENT => "C1", -- Sets output alignment to "NONE", "C0", "C1" 
      INIT => '0', -- Sets initial state of the Q output to '0' or '1'
      SRTYPE => "ASYNC") -- Specifies "SYNC" or "ASYNC" set/reset
   port map (
      Q => dci, -- 1-bit output data
      C0 => dco_clk, -- 1-bit clock input
      C1 => nclk, -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D0 => '1',   -- 1-bit data input (associated with C0)
      D1 => '0',   -- 1-bit data input (associated with C1)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );
   
dci_obufdf : OBUFDS
generic map (
   IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
   SLEW => "SLOW")          -- Specify the output slew rate
port map (
   O => m_dci_p,     -- Diff_p output (connect directly to top-level port)
   OB => m_dci_n,   -- Diff_n output (connect directly to top-level port)
   I => dci      -- Buffer input
);

end Behavioral;
