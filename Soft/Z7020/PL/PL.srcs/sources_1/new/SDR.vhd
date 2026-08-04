----------------------------------------------------------------------------------
-- ADDR 10 bits * 4
-- write
-- 0x00__   HW
-- 0x0000  Global Reset
-- 0x01__   RXA
-- 0x0100  DDS NR
-- 0x0101  MODULATION
-- 0x0102  J3E LSB
-- 0x0103  FOS COEFF 64
-- 0x0104  FOS GAIN CORRECT
-- 0x0105  A1A TONE
-- 0x0106  DDS WB
-- 0x0107  RF GAIN (0 - 32768, gain 1.0 = 256)
-- 0x0108  AGC TYPE
-- 0x0109  AGC LEVEL
-- 0x010A  AGC UP DOWN STEP
-- 0x010B  AFC FAST
-- 0x010E  AUDIO LP FILTER
-- 0x010F  AUDIO HP FILTER
-- 0x0110  AUDIO FILTER GAIN
-- 0x0120-0x012F  AGC

-- 0x02__   TXA
-- 0x0200  DDS 
-- 0x0201  ctrl reg
--         txa on(0)  
--         txa on hwr(1) 
--         adc1 inversion (2) 
--         iq data select(31) 
-- 0x0202  audio_in select
-- 0x0203  txa resampler out gain
-- 0x0204  /* reset max values */
-- 0x020e  data in i
-- 0x020f  data in q
-- 0x022_  limiter
-- 0x024_  modulator
-- 0x0240  MODULATION
-- 0x0241  J3E LSB
-- 0x0242  AUDIO GAIN
-- 0x0243  CARRIER LEVEL (A3E)
-- 0x0244  PHASE STEP (J3E)
-- 0x0248  FOS COEFF 64 
-- 0x0249  FOS GAIN CORRECT
-- 0x024F  TEST_REG
-- 0x026_  resampler
-- 0x028_  linear cmd
-- 0x02A_  linear phase block

-- 0x0300  write cic shift to swr

-- read
-- 0x00__  HW_ctrl
-- 0x0200  over bits ( ovf_out)
-- 0x0201  audio_max
-- 0x0202  lin_din_max
-- 0x0203  dac_tdata_max
-- 0x0204  float_out_max
-- 0x03__   SWR
-- 0x0301  magnitude 16 bit chan A & 16 bit chan B (absolute)
-- 0x0300  angle 16 bit chan A & 16 bit chan B (signed) 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;
use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity SDR is
  Port ( 
        ADC0_CLK_N : in STD_LOGIC;
        ADC0_CLK_P : in STD_LOGIC;
        ADC0_OUT_N : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC0_OUT_P : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC1_OUT_N : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC1_OUT_P : in STD_LOGIC_VECTOR ( 15 downto 0 );
        ADC1_CLK_N : in STD_LOGIC;
        ADC1_CLK_P : in STD_LOGIC;
        DAC_DCI_N : out STD_LOGIC;
        DAC_DCI_P : out STD_LOGIC;
        DAC_DCO_P : in STD_LOGIC;
        DAC_DCO_N : in STD_LOGIC;
        DAC_D_N : out STD_LOGIC_VECTOR ( 15 downto 0 );
        DAC_D_P : out STD_LOGIC_VECTOR ( 15 downto 0 );
		bram_addra : in STD_LOGIC_VECTOR (12 downto 0);
        bram_clka : in STD_LOGIC;
        bram_dina : in STD_LOGIC_VECTOR (31 downto 0);
		bram_douta : out STD_LOGIC_VECTOR (31 downto 0);
        bram_ena : in STD_LOGIC;
		bram_rsta : in STD_LOGIC;
		bram_wea : in STD_LOGIC_VECTOR (3 downto 0);
		m_axis_wb_tdata :out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tlast : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        i2s_mclk : out STD_LOGIC;
        i2s_bclk : out STD_LOGIC;
        i2s_wclk : out STD_LOGIC;
        i2s_dout : out STD_LOGIC;
        i2s_din : in STD_LOGIC;
        PTT : in STD_LOGIC;
        CW_KEY : in STD_LOGIC;
        CAT_DTR : in STD_LOGIC;
        CAT_RTC : in STD_LOGIC;
        m_axis_ser0_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_ser0_tvalid : out STD_LOGIC;
        m_axis_ser0_tlast : out STD_LOGIC;
        m_axis_ser1_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_ser1_tvalid : out STD_LOGIC;    
        m_axis_ser1_tlast : out STD_LOGIC; 
        TX_ON : out std_logic;
        TX_FAIL : in std_logic;
		aclk_122 : out std_logic
  );
end SDR;

architecture Behavioral of SDR is
      
    COMPONENT adc_2ch is
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
        adc1_inv: in STD_LOGIC;
        aresetn_out : out STD_LOGIC;
        aclk_out : out STD_LOGIC
    );
    end COMPONENT adc_2ch;
    
    component RXA is
    Port ( 
        aclk : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        s_axis_adc0_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc0_tvalid : in STD_LOGIC;
        s_axis_adc1_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc1_tvalid : in STD_LOGIC;
        m_axis_wb_tdata :out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tlast : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        m_axis_nb0_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_nb0_tvalid : out STD_LOGIC;
        m_axis_nb0_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_nb1_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_nb1_tvalid : out STD_LOGIC;
        m_axis_nb1_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_demod_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_demod_tvalid : out STD_LOGIC;
		cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
		cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;
        out_clk : out STD_LOGIC
    );
    end component RXA;
    
    component TXA is
    Port ( 
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        s_adc_data_rx0 : in std_logic_vector(15 downto 0);
        s_adc_data_rx1 : in std_logic_vector(15 downto 0);
        DAC_DCI_N : out STD_LOGIC;
        DAC_DCI_P : out STD_LOGIC;
        DAC_DCO_P : in STD_LOGIC;
        DAC_DCO_N : in STD_LOGIC;
        DAC_D_N : out STD_LOGIC_VECTOR ( 15 downto 0 );
        DAC_D_P : out STD_LOGIC_VECTOR ( 15 downto 0 );
		cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
		cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component TXA;
        
   component swr is
   Port ( 
       s_axis_data0_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_data0_tuser : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_data0_tvalid : in STD_LOGIC;
       s_axis_data1_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_data1_tuser : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_data1_tvalid : in STD_LOGIC;
       cfg_addra : in STD_LOGIC_VECTOR (7 downto 0);
       cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
	   cfg_douta : out STD_LOGIC_VECTOR (31 downto 0);
       cfg_wr : in STD_LOGIC;                      
       aresetn : in STD_LOGIC;
       aclk : in STD_LOGIC
   );
   end component swr;
    
    component i2s is
    Port ( 
        aclk : in STD_LOGIC;
        s_axis_audioL_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audioR_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC;
        m_axis_audioL_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audioR_tdata : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_audio_tvalid : out STD_LOGIC;
        i2s_mclk : out STD_LOGIC;
        i2s_bclk : out STD_LOGIC;
        i2s_wclk : out STD_LOGIC;
        i2s_dout : out STD_LOGIC;
        i2s_din : in STD_LOGIC
    );
    end component i2s;

    signal aclk : std_logic;
    signal aclk1 : std_logic;
    signal aresetn : std_logic;
    signal rst_sig : std_logic := '0'; 
    signal axis_adc0_tdata, axis_adc1_tdata : std_logic_vector(15 downto 0);
    signal cfg_douta : std_logic_vector(31 downto 0) := (others => '0');
    signal HW_cfg_douta, RXA_cfg_douta, TXA_cfg_douta, SWR_cfg_douta : std_logic_vector(31 downto 0);
    signal HW_wr, RXA_wr, TXA_wr, SWR_wr : std_logic := '0';
    signal axis_swrnb0_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal axis_swrnb0_tvalid : STD_LOGIC;
    signal axis_swrnb0_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal axis_swrnb1_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal axis_swrnb1_tvalid : STD_LOGIC;
    signal axis_swrnb1_tuser : STD_LOGIC_VECTOR (0 downto 0);
    signal s_axis_audioL_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal s_axis_audioR_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal s_axis_audio_tvalid : STD_LOGIC;
    signal m_axis_audioL_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal m_axis_audioR_tdata : STD_LOGIC_VECTOR (23 downto 0);
    signal m_axis_audio_tvalid : STD_LOGIC;
    signal cfg_addra, cfg_addr_r : STD_LOGIC_VECTOR (10 downto 0);
    signal axis_wb_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal axis_wb_tvalid : STD_LOGIC;
    signal audio_clk : STD_LOGIC;
    signal adc1_inv : STD_LOGIC  := '1';

    ATTRIBUTE X_INTERFACE_INFO : string;
    ATTRIBUTE X_INTERFACE_INFO OF bram_addra: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA ADDR";
    ATTRIBUTE X_INTERFACE_INFO OF bram_clka: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA CLK";
    ATTRIBUTE X_INTERFACE_INFO OF bram_dina: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA DIN";
    ATTRIBUTE X_INTERFACE_INFO OF bram_douta: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA DOUT";
    ATTRIBUTE X_INTERFACE_INFO OF bram_ena: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA EN";
    ATTRIBUTE X_INTERFACE_INFO OF bram_rsta: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA RST";
    ATTRIBUTE X_INTERFACE_INFO OF bram_wea: SIGNAL IS "xilinx.com:interface:bram:1.0 BRAM_PORTA WE";
    
    ATTRIBUTE X_INTERFACE_INFO OF ADC0_CLK_P: SIGNAL IS "xilinx.com:interface:diff_clock:1.0 ADC0_CLK CLK_P";
    ATTRIBUTE X_INTERFACE_INFO OF ADC0_CLK_N: SIGNAL IS "xilinx.com:interface:diff_clock:1.0 ADC0_CLK CLK_N";
    ATTRIBUTE X_INTERFACE_INFO OF ADC1_CLK_P: SIGNAL IS "xilinx.com:interface:diff_clock:1.0 ADC1_CLK CLK_P";
    ATTRIBUTE X_INTERFACE_INFO OF ADC1_CLK_N: SIGNAL IS "xilinx.com:interface:diff_clock:1.0 ADC1_CLK CLK_N";
    
    ATTRIBUTE X_INTERFACE_INFO of aclk_122: SIGNAL is "xilinx.com:signal:clock:1.0 aclk_122 CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of aclk_122: SIGNAL is "ASSOCIATED_BUSIF m_axis_ser0:m_axis_ser1:m_axis_wb:m_axis_i2s:s_axis_iq:m_linear_iq0:m_linear_iq1, FREQ_HZ 122880000"; 

    ATTRIBUTE X_INTERFACE_PARAMETER OF bram_rsta: SIGNAL IS "XIL_INTERFACENAME BRAM_PORTA, MASTER_TYPE BRAM_CTRL, MEM_SIZE 8192, MEM_WIDTH 32, MEM_ECC NONE, READ_WRITE_MODE READ_WRITE, READ_LATENCY 1";
    ATTRIBUTE X_INTERFACE_INFO of audio_clk: SIGNAL is "xilinx.com:signal:clock:1.0 audio_clk CLK";
    ATTRIBUTE X_INTERFACE_PARAMETER of audio_clk: SIGNAL is "FREQ_HZ 122880000"; 

begin 

    aclk_122 <= aclk;
    cfg_addra <= bram_addra(12 downto 2);
    bram_douta <= RXA_cfg_douta when cfg_addra(10 downto 8) = "001" or cfg_addr_r(10 downto 8) = "001" else 
                  TXA_cfg_douta when cfg_addra(10 downto 8) = "010" or cfg_addr_r(10 downto 8) = "010" else 
                  SWR_cfg_douta when cfg_addra(10 downto 8) = "011" or cfg_addr_r(10 downto 8) = "011" else 
                  HW_cfg_douta;                                  

    HW_cfg_douta <= x"0000000" & CAT_DTR & CAT_RTC & CW_KEY & PTT;   

    m_axis_ser1_tdata <= (others => '0');  
    
cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        HW_wr <= '0';    
        RXA_wr <= '0';
        TXA_wr <= '0'; 
        rst_sig <= '0';  
        if bram_ena = '1' then
            cfg_addr_r <= cfg_addra;  
            if bram_wea = x"F" then 
                if cfg_addra(10 downto 8) = "000" then
                    HW_wr <= '1';  
                    if cfg_addra(7 downto 0) = x"00" then
                        rst_sig <= '1';
                    end if;  
                elsif cfg_addra(10 downto 8) = "001" then
                    RXA_wr <= '1';
                elsif cfg_addra(10 downto 8) = "010" then
                    TXA_wr <= '1';  
                    if  cfg_addra(7 downto 0) = x"01" then
                        TX_ON <= bram_dina(1);   
                        adc1_inv <= bram_dina(2);    
                    end if; 
                elsif cfg_addra(10 downto 8) = "011" then
                    SWR_wr <= '1';     
                end if;        
            end if;  
        end if;
   end if;
end process cmd_process;
    
adc_0 : adc_2ch
    Port map( 
        ADC0_CLK_N => ADC1_CLK_N,
        ADC0_CLK_P => ADC1_CLK_P,
        ADC0_OUT_N => ADC1_OUT_N,
        ADC0_OUT_P => ADC1_OUT_P,
        ADC1_OUT_N => ADC0_OUT_N,
        ADC1_OUT_P => ADC0_OUT_P,
        ADC1_CLK_N => ADC0_CLK_N,
        ADC1_CLK_P => ADC0_CLK_P,
        adc0_out => axis_adc0_tdata,
        adc1_out => axis_adc1_tdata,
        rst_async => rst_sig,
        adc1_inv => adc1_inv,
        aresetn_out => aresetn,
        aclk_out => aclk
    );
    
RXA_0: RXA
    port map ( 
        aclk => aclk,
        aresetn => aresetn,
        s_axis_adc0_tdata => axis_adc0_tdata,
        s_axis_adc0_tvalid => '1',
        s_axis_adc1_tdata => axis_adc1_tdata,
        s_axis_adc1_tvalid => '1',
        m_axis_wb_tdata => axis_wb_tdata,
        m_axis_wb_tvalid => axis_wb_tvalid,
        m_axis_wb_tlast => m_axis_wb_tlast,
        m_axis_wb_tready => m_axis_wb_tready,
        m_axis_nb0_tdata => axis_swrnb0_tdata,
        m_axis_nb0_tvalid => axis_swrnb0_tvalid,
        m_axis_nb0_tuser => axis_swrnb0_tuser,
        m_axis_nb1_tdata => axis_swrnb1_tdata,
        m_axis_nb1_tvalid => axis_swrnb1_tvalid,
        m_axis_nb1_tuser => axis_swrnb1_tuser,
        m_axis_demod_tdata => s_axis_audioL_tdata,
        m_axis_demod_tvalid => s_axis_audio_tvalid,
        cfg_addra => cfg_addr_r(7 downto 0),
        cfg_dina => bram_dina,
		cfg_douta => RXA_cfg_douta,
        cfg_wr => RXA_wr,
        out_clk => audio_clk
    );  
    
    m_axis_wb_tdata <= axis_wb_tdata;
    m_axis_wb_tvalid <= axis_wb_tvalid;
    m_axis_ser0_tdata <= axis_wb_tdata;
    m_axis_ser0_tvalid <= axis_wb_tvalid;
    m_axis_ser1_tvalid <= axis_wb_tvalid;

    
swr_0 : swr
    port map ( 
        s_axis_data0_tdata => axis_swrnb0_tdata,
        s_axis_data0_tuser => axis_swrnb0_tuser,
        s_axis_data0_tvalid => axis_swrnb0_tvalid,
        s_axis_data1_tdata => axis_swrnb1_tdata,
        s_axis_data1_tuser => axis_swrnb1_tuser,
        s_axis_data1_tvalid => axis_swrnb1_tvalid,
        cfg_addra => cfg_addr_r(7 downto 0),
        cfg_dina => bram_dina,
		cfg_douta => SWR_cfg_douta,
        cfg_wr => SWR_wr,                   
        aresetn => aresetn,                     
        aclk => aclk
    );
    
TXA_0 : TXA
    port map (
        s_axis_audio_tdata => m_axis_audioR_tdata,
        s_axis_audio_tvalid => m_axis_audio_tvalid,
        s_adc_data_rx0 => axis_adc0_tdata,
        s_adc_data_rx1 => axis_adc1_tdata,
        DAC_DCI_N => DAC_DCI_N,
        DAC_DCI_P => DAC_DCI_P,
        DAC_DCO_P => DAC_DCO_P,
        DAC_DCO_N => DAC_DCO_N,
        DAC_D_N => DAC_D_N,
        DAC_D_P => DAC_D_P,
        cfg_addra => cfg_addr_r(7 downto 0),
        cfg_dina => bram_dina,
		cfg_douta => TXA_cfg_douta,
        cfg_wr => TXA_wr,
        aresetn => aresetn,                     
        aclk => aclk
    );
    
    m_axis_ser0_tlast <= '1';
    m_axis_ser1_tlast <= '1';
    
    s_axis_audioR_tdata <= s_axis_audioL_tdata;
    
audio_0 : i2s
    port map ( 
        aclk => audio_clk,
        s_axis_audioL_tdata => s_axis_audioL_tdata,
        s_axis_audioR_tdata => s_axis_audioR_tdata,
        s_axis_audio_tvalid => s_axis_audio_tvalid,
        m_axis_audioL_tdata => m_axis_audioL_tdata,
        m_axis_audioR_tdata => m_axis_audioR_tdata,
        m_axis_audio_tvalid => m_axis_audio_tvalid,
        i2s_mclk => i2s_mclk,
        i2s_bclk => i2s_bclk,
        i2s_wclk => i2s_wclk,
        i2s_dout => i2s_dout,
        i2s_din => i2s_din
    );
    
IDELAYCTRL_inst : IDELAYCTRL
   port map (
      RDY => open,       -- 1-bit output: Ready output
      REFCLK => aclk, -- 1-bit input: Reference clock input
      RST => '0'        -- 1-bit input: Active high reset input
   );

end Behavioral;
