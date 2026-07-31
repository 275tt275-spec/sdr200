----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 27.07.2026 15:38:58
-- Design Name: 
-- Module Name: adc_corr - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity adc_corr is
  Port (
        aclk : in std_logic;
        aresetn : in std_logic;
        adc0_in : in std_logic_vector(15 downto 0);
        adc1_in : in std_logic_vector(15 downto 0);
        cfg_addra : in STD_LOGIC_VECTOR (0 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC;
        adc0_out    : out std_logic_vector(15 downto 0); 
        adc1_out    : out std_logic_vector(15 downto 0)
   );
end adc_corr;

architecture Behavioral of adc_corr is

    signal reg_gain      : signed(15 downto 0) := x"7FFF"; -- По умолчанию 1.0 (в формате Q1.15)
    signal reg_phase     : signed(15 downto 0) := x"0000"; -- По умолчанию 0.0
    signal reg_dc_offset_i : signed(15 downto 0) := x"0000";
    signal reg_dc_offset_q : signed(15 downto 0) := x"0000";
    
    -- Сигналы конвейера вычислений (Latency = 3 такта)
    -- Такт 1: Вычитание DC Offset и фиксация входов
    signal i_dc_t1       : signed(15 downto 0) := (others => '0');
    signal q_dc_t1       : signed(15 downto 0) := (others => '0');
    
    -- Такт 2: Аппаратное умножение DSP48 (16x16 = 32 бита)
    signal mul_gain_t2   : signed(31 downto 0) := (others => '0');
    signal mul_phase_t2  : signed(31 downto 0) := (others => '0');
    signal q_dc_t2       : signed(15 downto 0) := (others => '0'); -- Задержка Q для выравнивания
    
    -- Такт 3: Компенсация фазы (вычитание утечки I из Q) и нормировка сдвигом
    signal i_corr_t3     : signed(15 downto 0) := (others => '0');
    signal q_corr_t3     : signed(15 downto 0) := (others => '0');
    
    -- Округляющий бит находится на позиции 14 (так как сдвиг идет с 15 бита)
    signal const_round : signed(31 downto 0) := to_signed(16384, 32); -- 16384 это 2^14 (0x00004000)

begin

    p_config : process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                reg_gain        <= x"7FFF"; 
                reg_phase       <= x"0000";
                reg_dc_offset_i <= x"0000";
                reg_dc_offset_q <= x"0000";
            elsif cfg_wr = '1' then
                if cfg_addra = "0" then
                    reg_gain  <= signed(cfg_dina(15 downto 0));
                    reg_phase <= signed(cfg_dina(31 downto 16));
                else
                    reg_dc_offset_i <= signed(cfg_dina(15 downto 0));
                    reg_dc_offset_q <= signed(cfg_dina(31 downto 16));
                end if;
            end if;
        end if;
    end process p_config;

    p_core : process(aclk)
        variable v_i_dc       : signed(15 downto 0);
        variable v_q_dc       : signed(15 downto 0);
        variable v_mul_gain   : signed(31 downto 0);
        variable v_mul_phase  : signed(31 downto 0);
        variable v_q_corr     : signed(15 downto 0);
        variable v_mul_gain_rounded : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                adc0_out <= (others => '0');
                adc1_out <= (others => '0');
            else
                -- 1. Комбинаторное удаление постоянной составляющей (DC Offset)
                v_i_dc := signed(adc0_in) - reg_dc_offset_i;
                v_q_dc := signed(adc1_in) - reg_dc_offset_q;
    
                -- 2. Комбинаторное перемножение (выполняется внутри DSP48E1 без внутренних регистров)
                v_mul_gain  := v_i_dc * reg_gain;
                v_mul_phase := v_i_dc * reg_phase;
    
                -- 3. Комбинаторная компенсация фазы и сдвиг (масштабирование Q1.15)
                v_q_corr := v_q_dc - v_mul_phase(30 downto 15);
    
                -- 4. Фиксация результатов на выходных триггерах (дает Latency = 1 такт)
                v_mul_gain_rounded := v_mul_gain + const_round;
                adc0_out <= std_logic_vector(v_mul_gain_rounded(30 downto 15));
                adc1_out <= std_logic_vector(v_q_corr);
            end if;
        end if;
    end process;

end Behavioral;
