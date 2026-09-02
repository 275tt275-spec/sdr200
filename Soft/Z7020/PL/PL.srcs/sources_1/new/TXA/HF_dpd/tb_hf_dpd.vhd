library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity tb_hf_dpd is
end tb_hf_dpd;

architecture Behavioral of tb_hf_dpd is
    signal aclk          : STD_LOGIC := '0';
    signal aresetn       : STD_LOGIC := '0';
    
    signal s_axis_iq_tdata  : STD_LOGIC_VECTOR(47 downto 0);
    signal s_axis_iq_tvalid : STD_LOGIC := '0';
    signal s_axis_iq_tready : STD_LOGIC;
    
    signal s_axis_adc_tdata  : STD_LOGIC_VECTOR(15 downto 0);
    signal s_axis_adc_tvalid : STD_LOGIC := '0';
    
    signal m_axis_iq_tdata   : STD_LOGIC_VECTOR(31 downto 0);
    signal m_axis_iq_tvalid  : STD_LOGIC;
    signal m_axis_iq_tready  : STD_LOGIC := '1';
    
    signal s_axis_cfg_tdata  : STD_LOGIC_VECTOR(31 downto 0);
    signal s_axis_cfg_tdest  : STD_LOGIC_VECTOR(4 downto 0);
    signal s_axis_cfg_tvalid : STD_LOGIC := '0';
    signal s_axis_cfg_tready : STD_LOGIC;
    
    signal s_axis_dds_tdata  : STD_LOGIC_VECTOR(31 downto 0) := x"08000000"; -- 10 МГц
    signal s_axis_dds_tvalid : STD_LOGIC := '1';
    
    signal m_cfg_dout        : STD_LOGIC_VECTOR(31 downto 0);
    signal m_cfg_dout_valid  : STD_LOGIC;
    signal m_ovf             : STD_LOGIC_VECTOR(1 downto 0);
    
    -- Симуляция PA (нелинейность)
    signal pa_input_i, pa_input_q : signed(15 downto 0);
    signal pa_output_i, pa_output_q : signed(15 downto 0);
    
    constant CLK_PERIOD : time := 8.138 ns; -- 122.88 MHz
    
begin
    -- ========================================================================
    -- 1. Генерация тактового сигнала
    -- ========================================================================
    process
    begin
        aclk <= '0';
        wait for CLK_PERIOD/2;
        aclk <= '1';
        wait for CLK_PERIOD/2;
    end process;
    
    -- ========================================================================
    -- 2. Тестируемый модуль
    -- ========================================================================
    DUT: entity work.hf_dpd
        Port map (
            aclk              => aclk,
            aresetn           => aresetn,
            s_axis_iq_tdata   => s_axis_iq_tdata,
            s_axis_iq_tvalid  => s_axis_iq_tvalid,
            s_axis_iq_tready  => s_axis_iq_tready,
            s_axis_adc_tdata  => s_axis_adc_tdata,
            s_axis_adc_tvalid => s_axis_adc_tvalid,
            m_axis_iq_tdata   => m_axis_iq_tdata,
            m_axis_iq_tvalid  => m_axis_iq_tvalid,
            m_axis_iq_tready  => m_axis_iq_tready,
            s_axis_cfg_tdata  => s_axis_cfg_tdata,
            s_axis_cfg_tdest  => s_axis_cfg_tdest,
            s_axis_cfg_tvalid => s_axis_cfg_tvalid,
            s_axis_cfg_tready => s_axis_cfg_tready,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            s_axis_dds_tvalid => s_axis_dds_tvalid,
            m_cfg_dout        => m_cfg_dout,
            m_cfg_dout_valid  => m_cfg_dout_valid,
            m_ovf             => m_ovf
        );
    
    -- ========================================================================
    -- 3. Модель усилителя мощности (нелинейный PA)
    -- ========================================================================
    process(aclk)
        variable amp : real;
        variable phase_shift : real;
        variable i_f, q_f : real;
        variable i_pa, q_pa : real;
    begin
        if rising_edge(aclk) then
            -- Чтение выходного сигнала DPD
            pa_input_i <= signed(m_axis_iq_tdata(15 downto 0));
            pa_input_q <= signed(m_axis_iq_tdata(31 downto 16));
            
            -- Модель PA: y = x * (A + B*|x|^2 + C*|x|^4)
            i_f := real(to_integer(pa_input_i)) / 32767.0;
            q_f := real(to_integer(pa_input_q)) / 32767.0;
            amp := sqrt(i_f*i_f + q_f*q_f);
            
            -- Коэффициенты PA (типичные для 200W)
            -- y = x * (1.0 - 0.3*amp^2 + 0.1*amp^4) * exp(j * 0.1*amp^2)
            i_pa := i_f * (1.0 - 0.3*amp*amp + 0.1*amp*amp*amp*amp);
            q_pa := q_f * (1.0 - 0.3*amp*amp + 0.1*amp*amp*amp*amp);
            
            -- Фазовая модуляция (AM-PM)
            phase_shift := 0.1 * amp * amp;
            pa_output_i <= to_signed(integer(round((i_pa*cos(phase_shift) - q_pa*sin(phase_shift)) * 32767.0)), 16);
            pa_output_q <= to_signed(integer(round((i_pa*sin(phase_shift) + q_pa*cos(phase_shift)) * 32767.0)), 16);
        end if;
    end process;
    
    -- Обратная связь с выхода PA
    s_axis_adc_tdata <= std_logic_vector(pa_output_i);
    s_axis_adc_tvalid <= '1';
    
    -- ========================================================================
    -- 4. Тестовые сигналы
    -- ========================================================================
    process
        variable i_test, q_test : integer;
    begin
        -- Сброс
        aresetn <= '0';
        wait for 100 ns;
        aresetn <= '1';
        wait for 100 ns;
        
        -- Включение режима обучения
        s_axis_cfg_tdata <= x"00000001";
        s_axis_cfg_tdest <= "00000";
        s_axis_cfg_tvalid <= '1';
        wait for CLK_PERIOD;
        s_axis_cfg_tvalid <= '0';
        wait for CLK_PERIOD;
        
        -- Генерация тестового сигнала (двухтоновый сигнал)
        for i in 0 to 1000000 loop
            -- Сигнал с двумя тонами (для теста IMD)
            i_test := integer(round(20000.0 * sin(2.0 * MATH_PI * 0.01 * real(i))));
            q_test := integer(round(20000.0 * cos(2.0 * MATH_PI * 0.01 * real(i))));
            
            s_axis_iq_tdata(23 downto 0)  <= std_logic_vector(to_signed(i_test, 24));
            s_axis_iq_tdata(47 downto 24) <= std_logic_vector(to_signed(q_test, 24));
            s_axis_iq_tvalid <= '1';
            
            wait for CLK_PERIOD;
        end loop;
        
        s_axis_iq_tvalid <= '0';
        wait;
    end process;
    
end Behavioral;