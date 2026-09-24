
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity TXA_channel16 is
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
end TXA_channel16;

architecture Behavioral of TXA_channel16 is

    component ila_0 IS
    Port (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    end component ila_0;
    
    component ila_2 IS
    Port (
        clk : IN STD_LOGIC;
        probe0 : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
        probe1 : IN STD_LOGIC_VECTOR(17 DOWNTO 0);
        probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        probe4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
    end component ila_2;

    component audio_input16 is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (23 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (15 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_cfg_tvalid : in STD_LOGIC;
       overflow : out STD_LOGIC
    );
    end component audio_input16;
    
    component audio_proc16 is
    Port ( 
        m_axis_audio_tdata : out STD_LOGIC_VECTOR (15 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (2 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        lim_over : out STD_LOGIC_VECTOR (6 downto 0);
        aclk : in STD_LOGIC
    );
    end component audio_proc16;

    component TXA_modulator16 is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (3 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        tx_on : in STD_LOGIC;
        ovr : out STD_LOGIC_VECTOR (2 downto 0);
        aclk : in STD_LOGIC
    );
    end component TXA_modulator16;

    component TXA_resampler16 is
    Port ( 
        m_i_data : out STD_LOGIC_VECTOR (17 downto 0);
        m_q_data : out STD_LOGIC_VECTOR (17 downto 0);
        s_axis_modulator_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_modulator_tready : out STD_LOGIC;
        s_axis_modulator_tvalid : in STD_LOGIC;
        gain : in STD_LOGIC_VECTOR (17 downto 0);              -- := "00" & x"7FFF";   100%
        out_over : out STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component TXA_resampler16;
    
    component linear_18 is
    Port (
        din1_i : in  STD_LOGIC_VECTOR (17 downto 0);
        din1_q : in  STD_LOGIC_VECTOR (17 downto 0);
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
    end component linear_18;
    
    component hf_dpd is
    Port ( 
        -- AXI Stream вход (I/Q данные)
        s_axis_iq_tdata   : in  STD_LOGIC_VECTOR (47 downto 0);
        -- Вход с АЦП (обратная связь)
        s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        -- Выход I/Q после линеаризации
        m_axis_iq_tdata   : out STD_LOGIC_VECTOR (31 downto 0);
        
        -- Управление через конфигурационный интерфейс
        s_axis_cfg_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest  : in  STD_LOGIC_VECTOR (4 downto 0);
        s_axis_cfg_tvalid : in  STD_LOGIC;
        txa_on            : in  STD_LOGIC;
        
        -- DDS для DDC
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        
        -- Выход конфигурации
        m_cfg_dout        : out STD_LOGIC_VECTOR (31 downto 0);
       
        -- Тактирование и сброс
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC
    );
    end component hf_dpd;
    
    component conv16x24 is
    port (
        aclk            : in  std_logic;
        aresetn         : in  std_logic;
        out_en          : in  std_logic;
        mult_in_tdata   : in  std_logic_vector(31 downto 0);
        dds_cfg_tdata   : in  std_logic_vector(31 downto 0);
        dds_cfg_tvalid  : in std_logic;
        dds_out_tdata   : out  std_logic_vector(47 downto 0);
        dac_tdata       : out std_logic_vector(15 downto 0)
    );
    end component conv16x24;

    component dds16a
        Port (
            aclk : IN STD_LOGIC;
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component dds16a;
         
    signal txa_on : std_logic := '0'; 
    signal audio_filtered_tdata : std_logic_vector(15 downto 0);
    signal audio_filtered_tvalid : std_logic;
    signal speech_in_tdata : std_logic_vector(15 downto 0);
    signal speech_in_tvalid : std_logic; 
    signal speech_out_tdata : std_logic_vector(15 downto 0);
    signal speech_out_tvalid : std_logic; 
    signal modulator_in_tdata : std_logic_vector(15 downto 0);
    signal modulator_in_tvalid : std_logic;
    signal resampler_in_tdata : std_logic_vector(31 downto 0);
    signal resampler_in_tvalid, resampler_in_tready : std_logic;
    signal modulator_out_tdata: std_logic_vector(31 downto 0);
    signal modulator_out_tvalid : std_logic;
    signal gain : STD_LOGIC_VECTOR ( 17 downto 0 ) := "00" & x"7FFF";
    signal fb_forward : STD_LOGIC_VECTOR (16 downto 0);
    signal linear_din2 : STD_LOGIC_VECTOR (15 downto 0);
    signal linear_out_i, linear_out_q : std_logic_vector(15 downto 0);
    signal linear_cfg_tvalid : STD_LOGIC;
    signal dds_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal dds_cfg_tdata : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
    signal dds_cfg_tvalid : std_logic := '0';
    signal mult_in_tdata : std_logic_vector(31 downto 0);
    signal dac_tdata : STD_LOGIC_VECTOR (15 downto 0);
    signal lim_proc_cfg_tvalid : STD_LOGIC;
    signal modulator_cfg_tvalid : STD_LOGIC;
    signal resampler_cfg_tvalid : STD_LOGIC;
    signal lim_over : STD_LOGIC_VECTOR(6 DOWNTO 0) := (others => '0');
    signal cfg_addr : std_logic_vector(3 downto 0);
    signal cfg_wr : std_logic := '0';    
    signal resampler_i, resampler_q : STD_LOGIC_VECTOR (17 downto 0);        
    signal resampler_over : std_logic;
    signal linear_ovf : std_logic_vector(3 downto 0);
    signal ovr_mod : std_logic_vector(2 downto 0);
    signal overflow_reg : std_logic_vector(31 downto 0) := (others => '0');

begin

    cfg_data_out <= overflow_reg;
    
    debug_0 : ila_0
    PORT MAP (
        clk => aclk,
        probe0 => overflow_reg(15 DOWNTO 0)
    );
    
u_audio_input : audio_input16
     Port map ( 
       aclk => aclk,   
       s_axis_tdata => s_axis_audio_tdata,
       s_axis_tvalid => s_axis_audio_tvalid,
       m_axis_tdata => audio_filtered_tdata,
       m_axis_tvalid => audio_filtered_tvalid,
       s_axis_cfg_tdata => s_axis_cfg_tdata,
       s_axis_cfg_tdest => s_axis_cfg_tdest(0 downto 0),
       s_axis_cfg_tvalid => '0',
       overflow => open
    );
    
    speech_in_tdata <= audio_filtered_tdata;
    speech_in_tvalid <= audio_filtered_tvalid;
    
   cfg_wr <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "000" else '0'; 
   lim_proc_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "001" else '0';
   modulator_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "010" else '0';
   resampler_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 5) = "011" else '0';
   linear_cfg_tvalid <=  s_axis_cfg_tvalid when s_axis_cfg_tdest(7 downto 6) = "10" else '0';

   cfg_addr <= s_axis_cfg_tdest(3 downto 0);

cmd_process : process (aclk) is
    -- Временный вектор для удобства сборки флагов переполнения
    variable current_overflows : std_logic_vector(overflow_reg'range);
begin 
   if rising_edge(aclk) then
        dds_cfg_tvalid <= '0'; 
        -- 1. Формируем вектор текущих переполнений (выравниваем по длине)
        current_overflows := std_logic_vector(resize(unsigned
                (ovr_mod & resampler_over & lim_over & linear_ovf),
                 overflow_reg'length));
        overflow_reg <= current_overflows;
        if aresetn = '0' then 
            txa_on <= '0';
            overflow_reg <= (others => '0');
        else         
            -- 2. Защелкиваем: если пришла '1', она останется в регистре
            overflow_reg <= overflow_reg or current_overflows;        
            if cfg_wr = '1' then   
                if cfg_addr = x"0" then
                    dds_cfg_tdata <= s_axis_cfg_tdata;
                    dds_cfg_tvalid <= '1';  
                elsif cfg_addr = x"1" then
                    txa_on <= s_axis_cfg_tdata(0);
                elsif cfg_addr = x"3" then
                    gain <= s_axis_cfg_tdata( 17 downto 0 );
                elsif cfg_addr = x"4" then
                    overflow_reg <= (others => '0');
                end if; 
            end if;
        end if;    
   end if;
end process cmd_process;

u_audio_proc : audio_proc16
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
 
   modulator_in_tdata <= speech_out_tdata;
   modulator_in_tvalid <= speech_out_tvalid;
    
u_modulator : TXA_modulator16
    PORT MAP ( 
        m_axis_iq_tdata => modulator_out_tdata,
        m_axis_iq_tvalid => modulator_out_tvalid,
        s_axis_audio_tdata => modulator_in_tdata,
        s_axis_audio_tvalid => modulator_in_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(3 downto 0),
        s_axis_cfg_tvalid => modulator_cfg_tvalid,
        tx_on => txa_on,
        ovr => ovr_mod,
        aclk => aclk
    );

    resampler_in_tvalid <= modulator_out_tvalid;
    resampler_in_tdata <= modulator_out_tdata;

u_resampler : TXA_resampler16
    PORT MAP  ( 
        m_i_data => resampler_i,
        m_q_data => resampler_q,
        s_axis_modulator_tdata => resampler_in_tdata,
        s_axis_modulator_tvalid => resampler_in_tvalid,
        s_axis_modulator_tready => resampler_in_tready,
        gain => gain,
        out_over => resampler_over,
        aresetn => aresetn,
        aclk => aclk
    );
    
    fb_forward <= std_logic_vector(resize(signed(s_adc_data_rx0), 17) + resize(signed(s_adc_data_rx1), 17));
    linear_din2 <= fb_forward(16 downto 1); -- проверить там раньше было 14 бит  
           
u_linear : linear_18
    PORT MAP  ( 
        din1_i => resampler_i,
        din1_q => resampler_q,
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
    
--u_hf_dpd: hf_dpd
--    Port map ( 
--        s_axis_iq_tdata   => iq_tdata,
--        s_axis_adc_tdata  => linear_din2,
--        m_axis_iq_tdata   => mult_in_tdata,
--        s_axis_cfg_tdata  => s_axis_cfg_tdata,
--        s_axis_cfg_tdest  => s_axis_cfg_tdest(4 downto 0),
--        s_axis_cfg_tvalid => linear_cfg_tvalid,
--        txa_on            => txa_on,
--        s_axis_dds_tdata  => dds_tdata,
--        m_cfg_dout        => open,
--        aclk              => aclk,
--        aresetn           => aresetn 
--    );

dds_0 : dds16a
  PORT MAP (
    aclk => aclk,
    s_axis_config_tvalid => dds_cfg_tvalid,
    s_axis_config_tdata => dds_cfg_tdata,
    m_axis_data_tvalid => open,
    m_axis_data_tdata => dds_tdata
  );
  
--  m_dds_tdata <= dds_tdata;
    mult_in_tdata <= linear_out_q & linear_out_i; 

mux_0 : conv16x24
    port map (
        aclk            => aclk,
        aresetn         => aresetn,
        out_en          => txa_on,
        mult_in_tdata   => mult_in_tdata,
        dds_cfg_tdata   => dds_cfg_tdata,
        dds_cfg_tvalid  => dds_cfg_tvalid,
        dds_out_tdata   => open,
        dac_tdata       => dac_tdata
    );

    m_daci_tdata <= dac_tdata;  
    m_dacq_tdata <= dac_tdata; 
    
debug_1 : ila_2
    Port map (
        clk     => aclk,
        probe0  => resampler_i,
        probe1  => resampler_q,
        probe2  => linear_out_i,
        probe3  => linear_out_q,
        probe4  => dac_tdata
    );

end Behavioral;
