----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.07.2026 19:48:14
-- Design Name: 
-- Module Name: adc_2ch - Behavioral
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

entity adc_2ch is
  Port ( 
        ADC0_CLK_N : in STD_LOGIC;
        ADC0_CLK_P : in STD_LOGIC;
        ADC0_OUT_N : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC0_OUT_P : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC1_CLK_N : in STD_LOGIC;
        ADC1_CLK_P : in STD_LOGIC;
        ADC1_OUT_N : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC1_OUT_P : in STD_LOGIC_VECTOR ( 15 downto 0 );
        adc0_out : out std_logic_vector(15 downto 0);
        adc1_out : out std_logic_vector(15 downto 0);
        rst_async : in STD_LOGIC;
        aresetn_out : out STD_LOGIC;
        aclk_out : out STD_LOGIC
   );
end adc_2ch;

architecture Behavioral of adc_2ch is

    component adc_input is
        port (
            clk_p : in STD_LOGIC;
            clk_n : in STD_LOGIC;
            din_p : in STD_LOGIC_VECTOR (15 downto 0);
            din_n : in STD_LOGIC_VECTOR (15 downto 0);
            m_axis_data_tdata : out STD_LOGIC_VECTOR (15 downto 0);
            adc_rand_en : in STD_LOGIC; 
            adc_max_value : out STD_LOGIC_VECTOR (15 downto 0);
            adc_max_rst : in STD_LOGIC;
            adc_clk_out : out STD_LOGIC
        );
    end component adc_input;

    COMPONENT adc_sync is
    Port (         
        adc0_data : in std_logic_vector(15 downto 0);
        adc0_clk : in STD_LOGIC;
        adc1_data : in std_logic_vector(15 downto 0);
        adc1_clk : in STD_LOGIC;
        adc0_out : out std_logic_vector(15 downto 0);
        adc1_out : out std_logic_vector(15 downto 0);
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end COMPONENT adc_sync;
    
    signal adc_data_in_0, adc_data_in_1 : STD_LOGIC_VECTOR (15 downto 0);
    signal aclk_0, aclk_1 : STD_LOGIC;
    signal aresetn : std_logic := '1';
    signal rst_sig : std_logic := '0';
    signal rst_shift : std_logic_vector(3 downto 0) := (others => '1');

begin

adc_input_0: component adc_input
    port map (
        clk_p => ADC0_CLK_P,
        clk_n => ADC0_CLK_N,
        din_p => ADC0_OUT_P,
        din_n => ADC0_OUT_N,
        m_axis_data_tdata => adc_data_in_0,
        adc_rand_en => '1',
        adc_max_value => open,
        adc_max_rst => '0',
        adc_clk_out => aclk_0
    );
    
adc_input_1: component adc_input
    port map (
        clk_p => ADC1_CLK_P,
        clk_n => ADC1_CLK_N,
        din_p => ADC1_OUT_P,
        din_n => ADC1_OUT_N,
        m_axis_data_tdata => adc_data_in_1,
        adc_rand_en => '1',
        adc_max_value => open,
        adc_max_rst => '0',
        adc_clk_out => aclk_1
    );  
    
adc_sync_0 : adc_sync
    Port map (         
        adc0_data => adc_data_in_0,
        adc0_clk => aclk_0,
        adc1_data => adc_data_in_1,
        adc1_clk => aclk_1,
        adc0_out => adc0_out,
        adc1_out => adc1_out,
        aresetn => aresetn,
        aclk => aclk_0
    );
    
p_synchronous_reset : process (aclk_0, rst_async) is
begin
    if rst_async = '1' then
        -- При асинхронном сбросе немедленно заполняем регистр единицами
        rst_shift <= (others => '1');
        aresetn   <= '0';
    elsif rising_edge(aclk_0) then
        -- Синхронно сдвигаем ноль в регистр, создавая задержку отпускания
        rst_shift <= rst_shift(2 downto 0) & '0';
        
        -- Снимаем сброс (переводим в '1') только когда весь регистр заполнится нулями
        if rst_shift(3) = '0' then
            aresetn <= '1';
        else
            aresetn <= '0';
        end if;
    end if;
end process p_synchronous_reset;

    aclk_out <= aclk_0;
    aresetn_out <= aresetn;


end Behavioral;
