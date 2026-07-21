----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.05.2025 11:56:55
-- Design Name: 
-- Module Name: TXA_channel - Behavioral
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
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;


entity TXA_channel is
    Port ( 
        m_daci_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_dacq_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        s_adc_data_rx0 : in std_logic_vector(15 downto 0);
        s_adc_data_rx1 : in std_logic_vector(15 downto 0);
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (7 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        cfg_data_out : out STD_LOGIC_VECTOR (31 downto 0);
        aresetn : in std_logic;
        aclk : in std_logic
    );
end TXA_channel;

architecture Behavioral of TXA_channel is

component floating_f2fix24 is
    port (
        aclk : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_a_tuser : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        m_axis_result_tvalid : OUT STD_LOGIC;
        m_axis_result_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_result_tuser : OUT STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    end component floating_f2fix24;

component axis_data_fifo_48 is
    port (
        s_axis_aresetn : IN STD_LOGIC;
        s_axis_aclk : IN STD_LOGIC;
        s_axis_tvalid : IN STD_LOGIC;
        s_axis_tready : OUT STD_LOGIC;
        s_axis_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_tvalid : OUT STD_LOGIC;
        m_axis_tready : IN STD_LOGIC;
        m_axis_tdata  : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
        prog_empty : OUT STD_LOGIC
    );
    end component axis_data_fifo_48;

component fir_audio_0 IS
    port (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
--        s_axis_config_tvalid : IN STD_LOGIC;
--        s_axis_config_tready : OUT STD_LOGIC;
--        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
    );
    end component fir_audio_0;
    
    component audio_proc is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (5 downto 0);
        aclk : in STD_LOGIC
    );
    end component audio_proc;

    component TXA_modulator is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (3 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        tx_on : in STD_LOGIC;
        audio_max_abs : out STD_LOGIC_VECTOR (24 downto 0);
        aclk : in STD_LOGIC
    );
    end component TXA_modulator;

    component TXA_resampler is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        s_axis_modulator_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_modulator_tready : out STD_LOGIC;
        s_axis_modulator_tvalid : in STD_LOGIC;
        gain : in STD_LOGIC_VECTOR (17 downto 0);              -- := "00" & x"7FFF";   100%
        out_over : out STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component TXA_resampler;
    
    component linear_dds_iq is
    Port (
        din1_i : in  STD_LOGIC_VECTOR (23 downto 0);
        din1_q : in  STD_LOGIC_VECTOR (23 downto 0);
        din2 : in  STD_LOGIC_VECTOR (15 downto 0);
        aclk : in  STD_LOGIC;
        ce : in  STD_LOGIC;
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (4 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        dout_i : out  STD_LOGIC_VECTOR (15 downto 0);
        dout_q : out  STD_LOGIC_VECTOR (15 downto 0);
        cfg_dout : out  STD_LOGIC_VECTOR (31 downto 0);
        m_ovf : out std_logic_vector(3 downto 0)
    );
    end component linear_dds_iq;

    component dds16a
        Port (
            aclk : IN STD_LOGIC;
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component dds16a;

--    component cmpy_24_24 IS
--    PORT (
--        aclk : IN STD_LOGIC;
--        aresetn : IN STD_LOGIC;
--        s_axis_a_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
--        s_axis_a_tvalid : IN STD_LOGIC;
--        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--        s_axis_b_tvalid : IN STD_LOGIC;
--        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0);
--        m_axis_dout_tvalid : OUT STD_LOGIC
--    );
--    end component cmpy_24_24;
    
    component cmpy_16x16r IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_ctrl_tvalid : IN STD_LOGIC;
        s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END component cmpy_16x16r;
 
    signal txa_on : std_logic := '0'; 
    signal modulator_select : STD_LOGIC_VECTOR ( 2 downto 0 ) := "001"; 
    signal audio_in_tdata : std_logic_vector(23 downto 0);
    signal audio_in_tvalid : std_logic;
    signal audio_out_tdata : std_logic_vector(23 downto 0);
    signal audio_out_tvalid : std_logic;
    signal speech_in_tdata : std_logic_vector(23 downto 0);
    signal speech_in_tvalid : std_logic; 
    signal speech_out_tdata : std_logic_vector(23 downto 0);
    signal speech_out_tvalid : std_logic; 
    signal modulator_in_tdata : std_logic_vector(23 downto 0);
    signal modulator_in_tvalid : std_logic;
    signal resampler_in_tdata : std_logic_vector(47 downto 0);
    signal resampler_in_tvalid, resampler_in_tready : std_logic;
    signal modulator_out_tdata: std_logic_vector(47 downto 0);
    signal modulator_out_tvalid : std_logic;
    signal gain : STD_LOGIC_VECTOR ( 17 downto 0 ) := "00" & x"7FFF";
    signal iq_tdata : std_logic_vector(47 downto 0);
    signal fb_forward : STD_LOGIC_VECTOR (16 downto 0);
    signal linear_din2 : STD_LOGIC_VECTOR (15 downto 0);
    signal linear_in_i, linear_in_q : std_logic_vector(23 downto 0);
    signal linear_out_i, linear_out_q : std_logic_vector(15 downto 0);
    signal linear_cfg_tvalid : STD_LOGIC;
    signal dds_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal dds_cfg_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
    signal dds_cfg_tvalid : std_logic := '0';
    signal mult_in_tdata, mult_out_tdata : std_logic_vector(31 downto 0);
    signal dac_tdata : STD_LOGIC_VECTOR (15 downto 0);
    signal lim_proc_cfg_tvalid : STD_LOGIC;
    signal modulator_cfg_tvalid : STD_LOGIC;
    signal resampler_cfg_tvalid : STD_LOGIC;
    signal lim_over : STD_LOGIC_VECTOR(5 DOWNTO 0) := (others => '0');
    signal cfg_addr : std_logic_vector(3 downto 0);
    signal cfg_wr : std_logic := '0';
    
    signal resampler_over : std_logic;
    signal linear_ovf : std_logic_vector(3 downto 0);
    signal ovf_out : std_logic_vector(31 downto 0) := (others => '0');
    signal audio_max_mod : std_logic_vector(24 downto 0);
    signal audio_max_mod_s : signed(24 downto 0);
    signal audio_max : signed(24 downto 0) := (others => '0');
    signal audio_max_rst : std_logic := '0';
    signal lin_din_max : signed(16 downto 0) := (others => '0');
    signal lin_din_abs : signed(16 downto 0); -- +1 бит для корректного abs
    signal lin_din_rst : std_logic := '0'; 
    signal dac_tdata_abs : signed(16 downto 0); -- +1 бит для корректного abs
    signal dac_tdata_max : signed(16 downto 0) := (others => '0');
    signal dac_tdata_rst : std_logic := '0'; 
    
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0) := (others => '0');

begin

    cfg_data_out <= std_logic_vector(resize(audio_max, 32)) when s_axis_cfg_tdest = x"01" else
               std_logic_vector(resize(lin_din_max, 32)) when s_axis_cfg_tdest = x"02" else
               std_logic_vector(resize(dac_tdata_max, 32)) when s_axis_cfg_tdest = x"03" else
               ovf_out;

    audio_in_tvalid <= s_axis_audio_tvalid;
    audio_in_tdata <= s_axis_audio_tdata;

audio_0 : fir_audio_0
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => audio_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => audio_in_tdata,
--        s_axis_config_tvalid => config_tvalid,
--        s_axis_config_tready => open,
--        s_axis_config_tdata => config_tdata,
        m_axis_data_tvalid => audio_out_tvalid,
        m_axis_data_tdata => audio_out_tdata
    );
    
    speech_in_tdata <= audio_out_tdata;
    speech_in_tvalid <= audio_out_tvalid;
    
   cfg_wr <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "000" else '0'; 
   lim_proc_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "001" else '0';
   modulator_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "010" else '0';
   resampler_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "011" else '0';
   linear_cfg_tvalid <=  s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 6) = "10" else '0';

   cfg_addr <= s_axis_cfg_tdest(3 downto 0);

cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        dds_cfg_tvalid <= '0'; 
        lin_din_rst <= '0';
        dac_tdata_rst <= '0';
        audio_max_rst <= '0';
        ovf_out <= std_logic_vector(resize(unsigned
                (resampler_over & lim_over & linear_ovf),
                 ovf_out'length));
--        config_tvalid <= '0';
        if cfg_wr = '1' then   
            if cfg_addr = x"0" then
                dds_cfg_tdata <= s_axis_cfg_tdata;
                dds_cfg_tvalid <= '1';  
            elsif cfg_addr = x"1" then
                txa_on <= s_axis_cfg_tdata(0);
--           elsif cfg_addr = x"2" then
--               config_tdata <= s_axis_cfg_tdata(7 DOWNTO 0);
--               config_tvalid <= '1';
            elsif cfg_addr = x"3" then
                gain <= s_axis_cfg_tdata( 17 downto 0 );
            elsif cfg_addr = x"4" then
                ovf_out <= (others => '0');
                lin_din_rst <= '1';
                dac_tdata_rst <= '1';
                audio_max_rst <= '1';   
            end if; 
        end if;
   end if;
end process cmd_process;

audio_proc_0 : audio_proc
    PORT MAP ( 
        m_axis_audio_tdata => speech_out_tdata,
        m_axis_audio_tvalid => speech_out_tvalid,
        s_axis_audio_tdata => speech_in_tdata,
        s_axis_audio_tvalid => speech_in_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(2 downto 0),
        s_axis_cfg_tvalid => lim_proc_cfg_tvalid,
        lim_over => lim_over,
        aclk => aclk
    );

--    ovf <= ext(lim_over & resampler_over & linear_ovf, 32);
    
    modulator_in_tdata <= speech_out_tdata;
    modulator_in_tvalid <= speech_out_tvalid;
    
--   modulator_in_tdata <= speech_in_tdata;
--   modulator_in_tvalid <= speech_in_tvalid;
    
modulator_0 : TXA_modulator
    PORT MAP ( 
        m_axis_iq_tdata => modulator_out_tdata,
        m_axis_iq_tvalid => modulator_out_tvalid,
        s_axis_audio_tdata => modulator_in_tdata,
        s_axis_audio_tvalid => modulator_in_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(3 downto 0),
        s_axis_cfg_tvalid => modulator_cfg_tvalid,
        tx_on => txa_on,
        audio_max_abs => audio_max_mod,
        aclk => aclk
    );
    
    audio_max_mod_s <= signed(audio_max_mod);
    
process(aclk)
begin
    if rising_edge(aclk) then
        if audio_max_rst = '1' then
            audio_max <= (others => '0');
        elsif audio_max_mod_s > audio_max then
            audio_max <= audio_max_mod_s;
        end if;
    end if;
end process;

    resampler_in_tvalid <= modulator_out_tvalid;
    resampler_in_tdata <= modulator_out_tdata;

resampler_0 : TXA_resampler
    PORT MAP  ( 
        m_axis_iq_tdata => iq_tdata,
        s_axis_modulator_tdata => resampler_in_tdata,
        s_axis_modulator_tvalid => resampler_in_tvalid,
        s_axis_modulator_tready => resampler_in_tready,
        gain => gain,
        out_over => resampler_over,
        aresetn => aresetn,
        aclk => aclk
    );
    
    linear_in_q <= iq_tdata(47 downto 24);
    linear_in_i <= iq_tdata(23 downto 0);   
    fb_forward <= std_logic_vector(resize(signed(s_adc_data_rx0), 17) - resize(signed(s_adc_data_rx1), 17)); -- Сигналы в противофазе
--    fb_forward <= s_adc_data_rx0 - s_adc_data_rx1; 
    linear_din2 <= fb_forward(16 downto 1); -- проверить там раньше было 14 бит  
           
linear_0 : linear_dds_iq
    PORT MAP  ( 
        din1_i => linear_in_i,
        din1_q => linear_in_q,
        din2 => linear_din2,
        aclk => aclk,
        ce => txa_on,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(4 downto 0),
        s_axis_cfg_tvalid => linear_cfg_tvalid,
        s_axis_dds_tdata => dds_tdata,
        dout_i => linear_out_i,
        dout_q => linear_out_q,
        m_ovf => linear_ovf
    );  

dds_0 : dds16a
  PORT MAP (
    aclk => aclk,
    s_axis_config_tvalid => dds_cfg_tvalid,
    s_axis_config_tdata => dds_cfg_tdata,
    m_axis_data_tvalid => open,
    m_axis_data_tdata => dds_tdata
  );
  
  mult_in_tdata <= linear_out_q & linear_out_i; 

--  mult_in_tdata <= linear_in_q & linear_in_i when test_reg(0) = '0' else
--                  test_data & test_data;

--cmply_0 : cmpy_24_24
--   PORT MAP (
--        aclk => aclk,
--        aresetn => aresetn,
--        s_axis_a_tdata => mult_in_tdata,
--        s_axis_a_tvalid => '1',
--        s_axis_b_tdata => dds_tdata,
--        s_axis_b_tvalid => '1',
--        m_axis_dout_tdata => mult_out_tdata,
--        m_axis_dout_tvalid => open
--    );
--    

process(aclk)
begin
    if rising_edge(aclk) then
        if txa_on = '1' then
            -- Классический полином LFSR x^16 + x^14 + x^13 + x^11 + 1
            lfsr_reg <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);
        end if;
    end if;
end process;

    ctrl_tdata(0) <= lfsr_reg(0); -- Подаем случайный бит в нулевой разряд
    ctrl_tdata(7 downto 1) <= (others => '0');

cmply_0 : cmpy_16x16r
   PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => '1',
        s_axis_a_tdata  => mult_in_tdata,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => dds_tdata,
        s_axis_ctrl_tvalid => '1',
        s_axis_ctrl_tdata => ctrl_tdata,
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => mult_out_tdata
    );   
    
    dac_tdata <= std_logic_vector(signed(mult_out_tdata(31 downto 16)) + signed(mult_out_tdata(15 downto 0))) when txa_on = '1' else (others => '0');   

process(aclk)
begin
    if rising_edge(aclk) then
        -- Шаг 1: Вычисляем абсолютное значение с расширением разрядности
        -- Это исключает ошибку переполнения для отрицательного максимума
        lin_din_abs <= abs(resize(signed(linear_din2), 17));
        dac_tdata_abs <= abs(resize(signed(dac_tdata), 17));
        -- Шаг 2: Сравнение и накопление максимума (Конвейерный регистр)
        if lin_din_rst = '1' then
            lin_din_max <= (others => '0');
        elsif lin_din_abs > lin_din_max then
            lin_din_max <= lin_din_abs;
        end if;
        
        if dac_tdata_rst = '1' then
            dac_tdata_max <= (others => '0');
        elsif dac_tdata_abs > dac_tdata_max then
            dac_tdata_max <= dac_tdata_abs;
        end if;
    end if;
end process;

    m_daci_tdata <= dac_tdata;  
    m_dacq_tdata <= dac_tdata; 


end Behavioral;
