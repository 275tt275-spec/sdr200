


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

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

    COMPONENT async_fifo_16 IS
    PORT (
        wr_rst_busy : OUT STD_LOGIC;
        rd_rst_busy : OUT STD_LOGIC;
        m_aclk : IN STD_LOGIC;
        s_aclk : IN STD_LOGIC;
        s_aresetn : IN STD_LOGIC;
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC;
        m_axis_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        axis_prog_empty : OUT STD_LOGIC
    );
    END COMPONENT async_fifo_16;
    
    signal axis_adc0_tdata : std_logic_vector(15 downto 0);
    signal axis_adc1_tdata : std_logic_vector(15 downto 0);

    -- Сигналы состояния FIFO для автомата выравнивания
    signal fifo0_prog_empty : std_logic;
    signal fifo1_prog_empty : std_logic;
    signal fifo0_empty      : std_logic;
    signal fifo1_empty      : std_logic;
    signal sync_read_en     : std_logic := '0';
    
    -- Состояния конечного автомата (FSM)
    type t_sync_state is (IDLE, WAIT_FOR_DATA, RUN);
    signal sync_state : t_sync_state := IDLE;

begin

-- Автомат выравнивания отсчетов АЦП0 и АЦП1
p_fifo_sync_align : process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            sync_read_en <= '0';
            sync_state   <= IDLE;
        else
            case sync_state is
                when IDLE =>
                    sync_read_en <= '0';
                    sync_state   <= WAIT_FOR_DATA;
                    
                when WAIT_FOR_DATA =>
                    -- Когда ОБА FIFO накопили по 4 отсчета, их prog_empty падают в '0'
                    if (fifo0_prog_empty = '0') and (fifo1_prog_empty = '0') then
                        sync_read_en <= '1'; -- Синхронный старт чтения в один и тот же такт
                        sync_state   <= RUN;
                    else
                        sync_read_en <= '0';
                    end if;
                    
                when RUN =>
                    -- Защита от сбоя: если хотя бы одно FIFO полностью опустеет
                    if (fifo0_empty = '1') or (fifo1_empty = '1') then
                        sync_read_en <= '0';
                        sync_state   <= IDLE; -- Перезапуск и повторное выравнивание
                    else
                        sync_read_en <= '1'; -- Непрерывное чтение
                    end if;
                    
                when others =>
                    sync_state <= IDLE;
            end case;
        end if;
    end if;
end process p_fifo_sync_align;

-- FIFO для канала ADC0 (Синхронное, так как запись и чтение на клоке aclk)
fifo_adc0_inst : component async_fifo_16  -- Замените на имя вашего IP-компонента
port map (
        wr_rst_busy => open,
        rd_rst_busy => open,
        m_aclk => aclk,
        s_aclk => adc0_clk,
        s_aresetn => aresetn,
        s_axis_tvalid => '1',
        s_axis_tready => open,
        s_axis_tdata => adc0_data,
        m_axis_tvalid => open,
        m_axis_tready => sync_read_en,
        m_axis_tdata => axis_adc0_tdata,
        axis_prog_empty => fifo0_prog_empty
);

-- FIFO для канала ADC1 (Асинхронное, CDC переход с клока aclk1 на клок aclk)
fifo_adc1_inst : component async_fifo_16  -- Замените на имя вашего IP-компонента
port map (
        wr_rst_busy => open,
        rd_rst_busy => open,
        m_aclk => aclk,
        s_aclk => adc1_clk,
        s_aresetn => aresetn,
        s_axis_tvalid => '1',
        s_axis_tready => open,
        s_axis_tdata => adc1_data,
        m_axis_tvalid => open,
        m_axis_tready => sync_read_en,
        m_axis_tdata => axis_adc1_tdata,
        axis_prog_empty => fifo1_prog_empty
);


end Behavioral;
