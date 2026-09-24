----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.06.2024 12:08:09
-- Design Name: 
-- Module Name: TXA_modulator - Behavioral
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

-- -- -- Select demodulator for RXA bits[0:3] 
-- -- -- 0 j3e 2400 yes offset 1850 Hz
-- -- -- 1 a3e
-- -- -- 2 a1a    
-- -- -- 3 f3e  

----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;
use IEEE.NUMERIC_STD.ALL;


-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TXA_modulator16 is
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
end TXA_modulator16;

architecture Behavioral of TXA_modulator16 is

    COMPONENT dds_16_16 IS
    PORT (
        aclk : IN STD_LOGIC;
        aclken : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    END COMPONENT dds_16_16;

    COMPONENT cmpy_16_16
      PORT (
        aclk : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_ctrl_tvalid : IN STD_LOGIC;
        s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
      );
    END COMPONENT cmpy_16_16;

    COMPONENT TXA_fos16 is
        Port ( 
           aclk : in  STD_LOGIC;     
           s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_axis_tvalid : in STD_LOGIC;
           m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
           m_axis_tvalid : out STD_LOGIC;
           s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
           s_axis_cfg_tvalid : in STD_LOGIC;
           overflow : out STD_LOGIC
        );
    END COMPONENT TXA_fos16;  
    
    signal audio_gain : STD_LOGIC_VECTOR (17 downto 0) := "00" & x"3FFF";
    signal audio_data : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    signal audio_data_valid : std_logic := '0';  
    signal freq_offset_data : STD_LOGIC_VECTOR (15 downto 0) := x"1799";
    signal freq_offset_valid : std_logic := '0';
    signal freq_offset_valid_r : std_logic := '0';
    signal dds_data : std_logic_vector(31 DOWNTO 0);   
    signal mult_in_data : std_logic_vector(31 DOWNTO 0); 
    signal mult_out_data : std_logic_vector(31 DOWNTO 0);
    signal mult_out_valid : std_logic;
    signal carrier_level : STD_LOGIC_VECTOR (15 downto 0) :=  x"3FFF";      -- := x"3FFFFF";        100%
    signal modulation : STD_LOGIC_VECTOR (1 downto 0) := "00";
    signal A3E_envelope : STD_LOGIC_VECTOR (15 downto 0);
    signal J3E_data : std_logic_vector(31 DOWNTO 0);
    signal iq_in_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal fos_in_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal fos_in_tvalid : STD_LOGIC;
    signal fos_out_tdata : STD_LOGIC_VECTOR (31 downto 0);
    signal fos_out_tvalid : STD_LOGIC;
    signal lsb_select : std_logic := '0';
    signal a3e_mod : std_logic := '0';
    signal fos_cfg_tvalid : std_logic := '0';
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0);
    signal j3e_data_valid_reg : std_logic := '0';
    signal ovr_reg : STD_LOGIC_VECTOR (2 downto 0) := (others => '0');

begin

    fos_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(3 downto 1) = "100" else '0';
    ovr <= ovr_reg;

process(aclk)
begin
	if rising_edge(aclk) then
	    if audio_data_valid = '1' then
	        freq_offset_valid <= freq_offset_valid_r;
	        freq_offset_valid_r <= '0';  
	    end if;    		
		if s_axis_cfg_tvalid = '1' then		
			if s_axis_cfg_tdest = x"0" then
                modulation <= s_axis_cfg_tdata(1 downto 0); 
            elsif s_axis_cfg_tdest = x"1" then	
				lsb_select <= s_axis_cfg_tdata(0); 
            elsif s_axis_cfg_tdest = x"2" then
                audio_gain <= s_axis_cfg_tdata(17 downto 0); 	
            elsif s_axis_cfg_tdest = x"3" then
                carrier_level <= s_axis_cfg_tdata(15 downto 0); 
            elsif s_axis_cfg_tdest = x"4" then
                freq_offset_data <= s_axis_cfg_tdata(15 downto 0); 	
                freq_offset_valid_r <= '1';
-- 8 and 9 for FOS                				
			end if;				     			           
		end if;  
	end if;
end process;

process(aclk)
    -- Оптимизировано: разрядность снижена до физических 34 бит (33 downto 0)
    variable mult_res    : signed(33 downto 0);
    variable round_add   : signed(33 downto 0) := (14 => '1', others => '0');
    variable res_rounded : signed(33 downto 0);
begin
    if rising_edge(aclk) then
        -- Задержка валидности ровно на 1 такт - в строгом соответствии с audio_data!
        audio_data_valid <= s_axis_audio_tvalid; 
        lfsr_reg         <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);  
        
        ovr_reg(1)       <= '0'; -- Исключаем неопределенность 'U' на незадействованном бите

        -- Прямое знаковое умножение 16x18 дает ровно 34 бита (размерности теперь строго совпадают)
        mult_res    := signed(s_axis_audio_tdata) * signed(audio_gain);
        res_rounded := mult_res + round_add;

        -- Проверка переполнения по старшим битам (33 downto 30 вместо прежних 41 downto 38)
        if (res_rounded(33 downto 30) = "1111") or (res_rounded(33 downto 30) = "0000") then
            ovr_reg(0) <= '0';
            -- Отрезаем целевые 16 бит звука (смещено на 8 бит вниз из-за уменьшения разрядности)
            audio_data <= std_logic_vector(res_rounded(30 downto 15));
        elsif res_rounded(33) = '0' then
            ovr_reg(0) <= '1';
            audio_data <= x"7FFF"; -- Положительное насыщение
        else
            ovr_reg(0) <= '1';
            audio_data <= x"8000"; -- Отрицательное насыщение
        end if;
    end if;
end process;

dds_0 : dds_16_16
    PORT MAP (
        aclk => aclk,
        aclken => audio_data_valid,
        s_axis_config_tvalid => freq_offset_valid,
        s_axis_config_tdata => freq_offset_data,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_data
    ); 
    
    mult_in_data <= audio_data & audio_data;
    ctrl_tdata <= "0000000" & lfsr_reg(0);
    
mply_0 : cmpy_16_16
    PORT MAP (
        aclk => aclk,
        s_axis_a_tvalid => audio_data_valid,
        s_axis_a_tdata => mult_in_data,
        s_axis_b_tvalid => audio_data_valid,
        s_axis_b_tdata => dds_data,
        s_axis_ctrl_tvalid => '1',
        s_axis_ctrl_tdata => ctrl_tdata,
        m_axis_dout_tvalid => mult_out_valid,
        m_axis_dout_tdata => mult_out_data
    );
    
process(aclk)
begin
    if rising_edge(aclk) then
        j3e_data_valid_reg <= mult_out_valid;
    end if;
end process;

    j3e_data <= mult_out_data(31 downto 16) & mult_out_data(15 downto 0) when lsb_select = '0' else
            mult_out_data(15 downto 0) & mult_out_data(31 downto 16);
    
    a3e_mod <= '1' when modulation = "01" else '0';
    -- audio_data должен быть симметричен относительно 0
    -- A3E_envelope — это всегда положительная величина (несущая + звук)
    A3E_envelope <= carrier_level + audio_data; 
    iq_in_tdata <= A3E_envelope & x"0000" when (a3e_mod = '1') else j3e_data;                                      
    
    fos_in_tdata <= x"4000" & x"4000" when modulation = "10" else iq_in_tdata; -- CW
    fos_in_tvalid <= s_axis_audio_tvalid when a3e_mod = '1' else j3e_data_valid_reg;

txa_fos_0 : TXA_fos16
    PORT MAP  (
        aclk => aclk,    
        s_axis_tdata => fos_in_tdata,
        s_axis_tvalid => fos_in_tvalid,
        m_axis_tdata => fos_out_tdata,
        m_axis_tvalid => fos_out_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(0 downto 0),
        s_axis_cfg_tvalid => fos_cfg_tvalid,
        overflow => ovr_reg(2)
   );
   
   m_axis_iq_tdata <= fos_out_tdata when tx_on = '1' else (others => '0');
   m_axis_iq_tvalid <= fos_out_tvalid;
   
end Behavioral;
