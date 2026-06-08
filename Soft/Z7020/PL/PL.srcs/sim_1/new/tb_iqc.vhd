library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_iqc is
-- Тестбенч не имеет портов
end tb_iqc;

architecture Behavioral of tb_iqc is

    -- Компонент UUT (Unit Under Test)
    component iqc
        Port (
            in_i : in  STD_LOGIC_VECTOR (17 downto 0);
            in_q : in  STD_LOGIC_VECTOR (17 downto 0);
            adc  : in  STD_LOGIC_VECTOR (15 downto 0); 
            s_axis_dds_tdata  : in STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdata  : in STD_LOGIC_VECTOR (31 downto 0);
            s_axis_cfg_tdest  : in STD_LOGIC_VECTOR (4 downto 0);
            s_axis_cfg_tvalid : in STD_LOGIC;
            outiq_0     : out  STD_LOGIC_VECTOR (31 downto 0);
            out_valid_0 : out STD_LOGIC;
            outiq_1     : out  STD_LOGIC_VECTOR (31 downto 0);
            out_valid_1 : out STD_LOGIC;
            aresetn     : in std_logic;
            aclk        : in std_logic
        );
    end component;
    
    component dds_signal_tb IS
    PORT (
        aclk : IN STD_LOGIC;
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END component dds_signal_tb;
    
    component dds_adc_tb IS
    PORT (
        aclk : IN STD_LOGIC;
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    END component dds_adc_tb;
    
    component dds_vfo_tb IS
    PORT (
        aclk : IN STD_LOGIC;
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END component dds_vfo_tb;
    

    -- Сигналы для подключения к UUT
    signal in_i   : std_logic_vector(17 downto 0) := (others => '0');
    signal in_q   : std_logic_vector(17 downto 0) := (others => '0');
    signal adc    : std_logic_vector(15 downto 0) := (others => '0');
    signal s_axis_dds_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdata  : std_logic_vector(31 downto 0) := (others => '0');
    signal s_axis_cfg_tdest  : std_logic_vector(4 downto 0)  := (others => '0');
    signal s_axis_cfg_tvalid : std_logic := '0';
    signal aresetn : std_logic := '0';
    signal aclk    : std_logic := '0';

    -- Выходные сигналы
    signal outiq_0, outiq_1 : std_logic_vector(31 downto 0);
    signal out_valid_0, out_valid_1 : std_logic;

    -- Параметры тактового сигнала (100 МГц)
    constant CLK_PERIOD : time := 10 ns;
    
     signal signal_tvalid    : std_logic := '0';
     signal signal_tdata  : std_logic_vector(31 downto 0) := (others => '0');
     signal adc_tvalid    : std_logic := '0';
     signal adc_tdata  : std_logic_vector(15 downto 0) := (others => '0');
     signal dds_tvalid    : std_logic := '0';
     signal dds_tdata  : std_logic_vector(31 downto 0) := (others => '0');

begin

    signal_0: dds_signal_tb
    PORT MAP(
        aclk => aclk,
        m_axis_data_tvalid => signal_tvalid,
        m_axis_data_tdata => signal_tdata
    );
    
    adc_0: dds_adc_tb
    PORT MAP(
        aclk => aclk,
        m_axis_data_tvalid => adc_tvalid,
        m_axis_data_tdata => adc_tdata
    );
    
    dds_0: dds_vfo_tb
    PORT MAP(
        aclk => aclk,
        m_axis_data_tvalid => dds_tvalid,
        m_axis_data_tdata => dds_tdata
    );
    
    in_i <= signal_tdata(31 downto 16) & "00";
    in_q <= signal_tdata(15 downto 0) & "00";
    adc <= adc_tdata;
    s_axis_dds_tdata <= dds_tdata;

    -- Инстанцирование модуля
    uut: iqc
        port map (
            in_i => in_i,
            in_q => in_q,
            adc  => adc,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            outiq_0     => outiq_0,
            out_valid_0 => out_valid_0,
            outiq_1     => outiq_1,
            out_valid_1 => out_valid_1,
            aresetn     => aresetn,
            aclk        => aclk
        );

    -- Генерация тактового сигнала
    clk_process : process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Основной процесс стимуляции
    stim_proc: process
    begin
        -- Сброс
        aresetn <= '0';
        wait for 100 ns;
        aresetn <= '1';
        wait for 20 ns;

        wait;
    end process;

end Behavioral;