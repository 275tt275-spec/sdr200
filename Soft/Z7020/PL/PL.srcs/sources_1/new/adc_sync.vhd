


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adc_sync is
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
end adc_sync;

architecture Behavioral of adc_sync is

    -- Сверхкороткие кольцевые буферы на 4 ячейки (синтезируются в LUT RAM)
    type t_mini_buffer is array (0 to 3) of std_logic_vector(15 downto 0);
    signal buf0 : t_mini_buffer := (others => (others => '0'));
    signal buf1 : t_mini_buffer := (others => (others => '0'));
    
    -- Указатели записи для каждого домена АЦП
    signal wr_ptr0 : unsigned(1 downto 0) := "00";
    signal wr_ptr1 : unsigned(1 downto 0) := "00";
    
    -- Общий указатель чтения в домене главного тактового сигнала
    signal rd_ptr  : unsigned(1 downto 0) := "00";

begin

    -------------------------------------------------------------------------
    -- 1. Запись данных: Канал ADC0 (на своем тактовом сигнале adc0_clk)
    -------------------------------------------------------------------------
    p_write_adc0 : process(adc0_clk)
    begin
        if rising_edge(adc0_clk) then
            if aresetn = '0' then
                wr_ptr0 <= "00";
            else
                buf0(to_integer(wr_ptr0)) <= adc0_data;
                wr_ptr0 <= wr_ptr0 + 1;
            end if;
        end if;
    end process p_write_adc0;

    -------------------------------------------------------------------------
    -- 2. Запись данных: Канал ADC1 (на своем тактовом сигнале adc1_clk)
    -------------------------------------------------------------------------
    p_write_adc1 : process(adc1_clk)
    begin
        if rising_edge(adc1_clk) then
            if aresetn = '0' then
                wr_ptr1 <= "00";
            else
                buf1(to_integer(wr_ptr1)) <= adc1_data;
                wr_ptr1 <= wr_ptr1 + 1;
            end if;
        end if;
    end process p_write_adc1;
    
    -------------------------------------------------------------------------
    -- 3. Синхронное чтение обоих каналов в целевом домене (aclk)
    -------------------------------------------------------------------------
    p_read_sync : process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                rd_ptr   <= "00";
                adc0_out <= (others => '0');
                adc1_out <= (others => '0');
            else
                -- Чтение происходит одновременно из фиксированных со смещением ячеек.
                -- Задержка от входа до выхода составляет всего 1-2 такта.
                adc0_out <= buf0(to_integer(rd_ptr));
                adc1_out <= buf1(to_integer(rd_ptr));
                rd_ptr   <= rd_ptr + 1;
            end if;
        end if;
    end process p_read_sync;


end Behavioral;
