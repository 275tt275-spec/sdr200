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
    signal dco, dco_clk, dac_resetn : std_logic;
    signal dout_i, dout_q : STD_LOGIC_VECTOR (15 downto 0);
    signal dout : STD_LOGIC_VECTOR (15 downto 0);
    signal dint_in, dint_out: STD_LOGIC_VECTOR (31 downto 0);
    signal sync_reset_reg : std_logic_vector(1 downto 0) := "11";
    attribute ASYNC_REG : string;
    attribute ASYNC_REG of sync_reset_reg : signal is "TRUE";
    
begin

--    nclk <= not dco_clk;
    dint_in <= s_daci_tdata & s_dacq_tdata;    
    dout_i <= dint_out(31 downto 16); 
    dout_q <= dint_out(15 downto 0);  
    
clock_converter_0: clock_converter_32_0
    port map (
        m_axis_aclk => dco_clk,
        m_axis_aresetn => dac_resetn,
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
    
process(dco_clk)
begin
    if rising_edge(dco_clk) then
        sync_reset_reg(0) <= aresetn;
        sync_reset_reg(1) <= sync_reset_reg(0);
    end if;
end process;

    dac_resetn <= sync_reset_reg(1);

-- Дифференциальный входной буфер для такта ЦАП
dco_ibufds : IBUFDS
    generic map (
        DIFF_TERM    => TRUE,                       -- Дифференциальное согласование
        IBUF_LOW_PWR => FALSE,                      -- Режим производительности
        IOSTANDARD   => "DEFAULT"                   -- Стандарт ввода/вывода
    )
    port map (
        O  => dco,
        I  => s_dco_p,
        IB => s_dco_n
    );

-- Буфер тактового сигнала для распределения по региону
BUFR_inst : BUFR
    generic map (
        BUFR_DIVIDE => "BYPASS",                    -- Без деления
        SIM_DEVICE  => "7SERIES"                    -- Для 7-й серии (Zynq)
    )
    port map (
        O   => dco_clk,                             -- Выход такта
        CE  => '1',                                 -- Разрешение
        CLR => '0',                                 -- Сброс
        I   => dco                                  -- Вход от IBUFDS
    );

-- Генерация 16 дифференциальных линий данных
data_gen : for k in 0 to 15 generate
begin
    -- ODDR с SAME_EDGE для передачи данных
    -- SAME_EDGE: оба бита (D1 и D2) защелкиваются по одному фронту
    data_oddr : ODDR
        generic map(
            DDR_CLK_EDGE => "SAME_EDGE",            -- Оба бита по одному фронту
            INIT         => '0',                    -- Начальное состояние
            SRTYPE       => "SYNC"                  -- Синхронный сброс/установка
        )
        port map (
            Q  => dout(k),                          -- Выход
            C  => dco_clk,                          -- Такт
            CE => '1',                              -- Разрешение
            D1 => dout_i(k),                        -- Данные для нечетного бита
            D2 => dout_q(k),                        -- Данные для четного бита
            R  => '0',                              -- Сброс
            S  => '0'                               -- Установка
        );
    
    -- Дифференциальный выходной буфер
    data_obufds : OBUFDS
        generic map (
            IOSTANDARD => "DEFAULT",                -- Стандарт ввода/вывода
            SLEW       => "FAST"                    -- Скорость нарастания
        )
        port map (
            O  => m_dout_p(k),                      -- Дифференциальный плюс
            OB => m_dout_n(k),                      -- Дифференциальный минус
            I  => dout(k)                           -- Вход
        );
end generate;

-- Генерация тактового сигнала данных (DCI)
dci_oddr : ODDR
    generic map(
        DDR_CLK_EDGE => "SAME_EDGE",                -- Оба бита по одному фронту
        INIT         => '0',                        -- Начальное состояние
        SRTYPE       => "SYNC"                      -- Синхронный сброс/установка
    )
    port map (
        Q  => dci,                                  -- Выход
        C  => dco_clk,                              -- Такт
        CE => '1',                                  -- Разрешение
        D1 => '1',                                  -- Данные для нечетного бита
        D2 => '0',                                  -- Данные для четного бита
        R  => '0',                                  -- Сброс
        S  => '0'                                   -- Установка
    );

-- Дифференциальный выходной буфер для такта
dci_obufds : OBUFDS
    generic map (
        IOSTANDARD => "DEFAULT",                    -- Стандарт ввода/вывода
        SLEW       => "FAST"                        -- Скорость нарастания
    )
    port map (
        O  => m_dci_p,                              -- Дифференциальный плюс
        OB => m_dci_n,                              -- Дифференциальный минус
        I  => dci                                   -- Вход
    );

end Behavioral;
