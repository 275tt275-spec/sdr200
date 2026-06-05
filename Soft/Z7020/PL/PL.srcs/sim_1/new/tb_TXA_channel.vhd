library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_TXA_channel is
-- Тестбенч не имеет портов
end tb_TXA_channel;

architecture Behavioral of tb_TXA_channel is

    -- 1. Объявление компонента (UUT - Unit Under Test)
    component TXA_channel
        Port (
            m_daci_tdata        : out STD_LOGIC_VECTOR (15 downto 0);
            m_dacq_tdata        : out STD_LOGIC_VECTOR (15 downto 0);
            s_axis_audio_tdata  : in  STD_LOGIC_VECTOR (23 downto 0);
            s_axis_audio_tvalid : in  STD_LOGIC;
            s_adc_data_rx0      : in  STD_LOGIC_VECTOR (15 downto 0);
            s_adc_data_rx1      : in  STD_LOGIC_VECTOR (15 downto 0);
            s_axis_cfg_tdata    : in  STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdest    : in  STD_LOGIC_VECTOR (7 downto 0);
            s_axis_cfg_tvalid   : in  STD_LOGIC;
            cfg_data_out        : out STD_LOGIC_VECTOR (31 downto 0);
            aresetn             : in  STD_LOGIC;
            aclk                : in  STD_LOGIC
        );
    end component;

    -- 2. Внутренние сигналы для подключения к UUT
    signal aclk                : std_logic := '0';
    signal aresetn             : std_logic := '0';
    signal m_daci_tdata        : std_logic_vector(15 downto 0);
    signal m_dacq_tdata        : std_logic_vector(15 downto 0);
    signal s_axis_audio_tdata  : std_logic_vector(23 downto 0) := (others => '0');
    signal s_axis_audio_tvalid : std_logic := '0';
    signal s_adc_data_rx0      : std_logic_vector(15 downto 0) := (others => '0');
    signal s_adc_data_rx1      : std_logic_vector(15 downto 0) := (others => '0');
    signal s_axis_cfg_tdata    : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest    : std_logic_vector(7 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid   : std_logic := '0';
    signal cfg_data_out        : std_logic_vector(31 downto 0);

    -- Константа периода тактового сигнала (например, 100 МГц)
    constant CLK_PERIOD : time := 10 ns;
    
    type inputFile_t is file of integer;
    signal data : STD_LOGIC_VECTOR ( 31 downto 0 ) := (others => '0');
    

begin

    -- 3. Инициализация проверяемого модуля
    uut: TXA_channel
        port map (
            m_daci_tdata        => m_daci_tdata,
            m_dacq_tdata        => m_dacq_tdata,
            s_axis_audio_tdata  => s_axis_audio_tdata,
            s_axis_audio_tvalid => s_axis_audio_tvalid,
            s_adc_data_rx0      => s_adc_data_rx0,
            s_adc_data_rx1      => s_adc_data_rx1,
            s_axis_cfg_tdata    => s_axis_cfg_tdata,
            s_axis_cfg_tdest    => s_axis_cfg_tdest,
            s_axis_cfg_tvalid   => s_axis_cfg_tvalid,
            cfg_data_out        => cfg_data_out,
            aresetn             => aresetn,
            aclk                => aclk
        );

    -- 4. Генерация тактового сигнала
    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- 5. Основной процесс стимулов
    stim_proc: process
    variable indata: integer;
    file data_in: inputFile_t open read_mode is "E:\Projects\wdsp 1.29\out_wdsp.bin";
    begin		
        -- Сброс
        aresetn <= '0';
        wait for 100 ns;
        aresetn <= '1';
        wait for CLK_PERIOD*10;

        -- ПРИМЕР 1: Включение передачи через шину конфигурации
        -- В коде: cfg_addr = x"1" (s_axis_cfg_tdest(3 downto 0))
        -- txa_on <= s_axis_cfg_tdata(0)
        s_axis_cfg_tdest <= x"01"; 
        s_axis_cfg_tdata <= x"80000001"; -- txa_on = 1
        s_axis_cfg_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_cfg_tvalid <= '0';
   
   while not endfile(data_in) loop  
   
        -- ЦИКЛ НА 16 ТРАНЗАКЦИЙ (16 пар I и Q)
        for trans_cnt in 1 to 32 loop
       
            wait until rising_edge(aclk);
            read(data_in, indata);
            data <= std_logic_vector(to_signed(indata, 32));
            s_axis_cfg_tdata <= data;
            s_axis_cfg_tdest <= x"0E";
            s_axis_cfg_tvalid <= '1';
            wait until rising_edge(aclk);
            s_axis_cfg_tvalid <= '0';      
            
            wait for 10 * CLK_PERIOD;
            wait until rising_edge(aclk);
            
            read(data_in, indata);
            data <= std_logic_vector(to_signed(indata, 32));
            s_axis_cfg_tdata <= data;
            s_axis_cfg_tdest <= x"0F";
            s_axis_cfg_tvalid <= '1';
            wait until rising_edge(aclk);
            s_axis_cfg_tvalid <= '0'; 
            
            wait for 10 * CLK_PERIOD;
            wait until rising_edge(aclk);
            
       end loop;     
       
       wait for 1996 us; -- Длительность паузы (настройте под себя) 
        
    end loop;


        -- Ждем завершения
        wait for 1 us;
        assert false report "Simulation Finished" severity note;
        wait;
    end process;

end Behavioral;