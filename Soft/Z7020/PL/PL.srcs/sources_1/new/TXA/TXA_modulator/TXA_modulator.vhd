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

entity TXA_modulator is
    Port ( 
        m_axis_iq_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_iq_tvalid : out STD_LOGIC;
        s_axis_audio_tdata : in STD_LOGIC_VECTOR (23 downto 0);
        s_axis_audio_tvalid : in STD_LOGIC; 
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (3 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        tx_on : in STD_LOGIC;
        ovr : out STD_LOGIC_VECTOR (2 downto 0);
        aclk : in STD_LOGIC
    );
end TXA_modulator;

architecture Behavioral of TXA_modulator is

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

    COMPONENT cmpy_24_16 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_ctrl_tvalid : IN STD_LOGIC;
        s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT cmpy_24_16;

    COMPONENT TXA_fos is
        Port ( 
           aclk : in  STD_LOGIC;     
           s_axis_tdata : in STD_LOGIC_VECTOR (47 downto 0);
           s_axis_tvalid : in STD_LOGIC;
           m_axis_tdata : out STD_LOGIC_VECTOR (47 downto 0);
           m_axis_tvalid : out STD_LOGIC;
           s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
           s_axis_cfg_tvalid : in STD_LOGIC;
           overflow : out STD_LOGIC
        );
    END COMPONENT TXA_fos;  
    
    signal audio_gain : STD_LOGIC_VECTOR (17 downto 0) := "00" & x"3FFF";
 --   signal audio_data_42 : STD_LOGIC_VECTOR (41 downto 0);
    signal audio_data : STD_LOGIC_VECTOR (23 downto 0);
    signal audio_data_valid : std_logic := '0';  
--    signal audio_data_valid_r : std_logic := '0';  
    signal freq_offset_data : STD_LOGIC_VECTOR (15 downto 0) := x"1799";
    signal freq_offset_valid : std_logic := '0';
    signal freq_offset_valid_r : std_logic := '0';
    signal dds_data : std_logic_vector(31 DOWNTO 0);   
    signal mult_in_data : std_logic_vector(47 DOWNTO 0); 
    signal mult_out_data : std_logic_vector(63 DOWNTO 0);
    signal mult_out_valid : std_logic;
    signal carrier_level : STD_LOGIC_VECTOR (23 downto 0) :=  x"3FFFFF";      -- := x"3FFFFF";        100%
    signal modulation : STD_LOGIC_VECTOR (1 downto 0) := "00";
    signal A3E_envelope : STD_LOGIC_VECTOR (23 downto 0);
    signal J3E_data : std_logic_vector(47 DOWNTO 0);
    signal iq_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fos_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fos_in_tvalid : STD_LOGIC;
    signal fos_out_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fos_out_tvalid : STD_LOGIC;
    signal lsb_select : std_logic := '0';
--    signal audio_abs_in : STD_LOGIC_VECTOR (23 downto 0); 
    signal a3e_mod : std_logic := '0';
    signal fos_cfg_tvalid : std_logic := '0';
--    signal audio_max_abs_reg : STD_LOGIC_VECTOR (24 downto 0) := (others => '0');
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0);
    signal j3e_data_valid_reg : std_logic := '0';
    signal i_channel_rounded : signed(24 downto 0); -- 25 бит, чтобы не потерять знак при сложении
    signal q_channel_rounded : signed(24 downto 0);
    signal res_rounded_sig : signed(41 downto 0);

begin

    fos_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(3 downto 1) = "100" else '0';

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
                carrier_level <= s_axis_cfg_tdata(23 downto 0); 
            elsif s_axis_cfg_tdest = x"4" then
                freq_offset_data <= s_axis_cfg_tdata(15 downto 0); 	
                freq_offset_valid_r <= '1';
-- 8 and 9 for FOS                				
			end if;				     			           
		end if;  
	end if;
end process;

process(aclk)
    variable mult_res : signed(41 downto 0);
    variable round_add : signed(41 downto 0) := (14 => '1', others => '0');
    variable res_rounded : signed(41 downto 0);
begin
    if rising_edge(aclk) then
        -- Задержка валидности ровно на 1 такт - в строгом соответствии с audio_data!
        audio_data_valid <= s_axis_audio_tvalid; 
        lfsr_reg       <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);  

        mult_res := signed(s_axis_audio_tdata) * signed(audio_gain);
        res_rounded := mult_res + round_add;
        res_rounded_sig <= res_rounded;

        if (res_rounded(41 downto 38) = "1111") or (res_rounded(41 downto 38) = "0000") then
            ovr(0) <= '0';
            audio_data <= std_logic_vector(res_rounded(38 downto 15));
        elsif res_rounded(41) = '0' then
            ovr(0) <= '1';
            audio_data <= x"7FFFFF";
        else
            ovr(0) <= '1';
            audio_data <= x"800000";
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
    
mply_0 : cmpy_24_16
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
    variable i_full   : signed(31 downto 0);
    variable q_full   : signed(31 downto 0);
    variable i_scaled : signed(32 downto 0); -- 33 бита для безопасного сложения с константой 64
    variable q_scaled : signed(32 downto 0);
begin
    if rising_edge(aclk) then
        -- Синхронная задержка сигнала валидности на 1 такт
        j3e_data_valid_reg <= mult_out_valid; 
        
        -- Сброс флага переполнения по умолчанию для текущего такта
        ovr(1) <= '0';

        -- Разделение шины на I и Q каналы
        i_full := signed(mult_out_data(63 downto 32));
        q_full := signed(mult_out_data(31 downto 0));

        -- Прибавляем 64 (половина веса 7-го бита) с расширением знака для округления
        i_scaled := resize(i_full, 33) + 64;
        q_scaled := resize(q_full, 33) + 64;

        -- === Проверка переполнения и насыщение для канала I ===
        -- Ожидаемый диапазон после сдвига на 7 бит должен умещаться в 25 знаковых бит
        -- Проверяем верхние биты (с 32 по 31)
        if (i_scaled(32) = '0' and i_scaled(31) /= '0') then
            i_channel_rounded <= "0" & x"FFFFFF"; -- Положительное насыщение (max POS 25-bit)
            ovr(1)  <= '1';
        elsif (i_scaled(32) = '1' and i_scaled(31) /= '1') then
            i_channel_rounded <= "1" & x"000000"; -- Отрицательное насыщение (max NEG 25-bit)
            ovr(1)  <= '1';
        else
            i_channel_rounded <= i_scaled(31 downto 7);
        end if;

        -- === Проверка переполнения и насыщение для канала Q ===
        if (q_scaled(32) = '0' and q_scaled(31) /= '0') then
            q_channel_rounded <= "0" & x"FFFFFF"; 
            ovr(1)  <= '1';
        elsif (q_scaled(32) = '1' and q_scaled(31) /= '1') then
            q_channel_rounded <= "1" & x"000000"; 
            ovr(1)  <= '1';
        else
            q_channel_rounded <= q_scaled(31 downto 7);
        end if;
    end if;
end process;

    j3e_data <= std_logic_vector(i_channel_rounded(23 downto 0)) & std_logic_vector(q_channel_rounded(23 downto 0)) when lsb_select = '0' else
            std_logic_vector(q_channel_rounded(23 downto 0)) & std_logic_vector(i_channel_rounded(23 downto 0));
    
    a3e_mod <= '1' when modulation = "01" else '0';
    -- audio_data должен быть симметричен относительно 0
    -- A3E_envelope — это всегда положительная величина (несущая + звук)
    A3E_envelope <= carrier_level + audio_data;  

    iq_in_tdata <= A3E_envelope & x"000000" when (a3e_mod = '1') else j3e_data;          
--    audio_abs_in <= A3E_envelope when a3e_mod = '1' else audio_data;                               
    
    fos_in_tdata <= x"400000" & x"400000" when modulation = "10" else iq_in_tdata;
    fos_in_tvalid <= s_axis_audio_tvalid when a3e_mod = '1' else j3e_data_valid_reg;
    
--process(aclk)
--begin
--    if rising_edge(aclk) then
--        audio_max_abs_reg <= std_logic_vector(abs(resize(signed(audio_abs_in), 25)));
--    end if;
--end process;
--
--    audio_max_abs <= audio_max_abs_reg;

txa_fos_0 : TXA_fos
    PORT MAP  (
        aclk => aclk,    
        s_axis_tdata => fos_in_tdata,
        s_axis_tvalid => fos_in_tvalid,
        m_axis_tdata => fos_out_tdata,
        m_axis_tvalid => fos_out_tvalid,
        s_axis_cfg_tdata => s_axis_cfg_tdata,
        s_axis_cfg_tdest => s_axis_cfg_tdest(0 downto 0),
        s_axis_cfg_tvalid => fos_cfg_tvalid,
        overflow => ovr(2)
   );
   
   m_axis_iq_tdata <= fos_out_tdata when tx_on = '1' else (others => '0');
   m_axis_iq_tvalid <= fos_out_tvalid;
   
end Behavioral;
