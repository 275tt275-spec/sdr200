----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.05.2025 12:51:47
-- Design Name: 
-- Module Name: RXA_wide - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity RXA_wide is
     Port ( 
        m_axis_wb_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_wb_tvalid : out STD_LOGIC;
        m_axis_wb_tready : in STD_LOGIC;
        s_axis_signal_tdata : in STD_LOGIC_VECTOR (15 downto 0);
        dds_value : in STD_LOGIC_VECTOR (31 downto 0);
        dds_valid : in STD_LOGIC;
        ovr : out STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end RXA_wide;

architecture Behavioral of RXA_wide is

    component dds16a
    Port (
        aclk : IN STD_LOGIC;
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
    );
    end component dds16a;
    
--   component cmpy_16x16r24 IS
--   PORT (
--       aclk : IN STD_LOGIC;
--       aresetn : IN STD_LOGIC;
--       s_axis_a_tvalid : IN STD_LOGIC;
--       s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--       s_axis_b_tvalid : IN STD_LOGIC;
--       s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
--       s_axis_ctrl_tvalid : IN STD_LOGIC;
--       s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
--       m_axis_dout_tvalid : OUT STD_LOGIC;
--       m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
--   );
--   END component cmpy_16x16r24;
    
    COMPONENT cic_wide IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    END COMPONENT cic_wide;
    
    COMPONENT  fir_wide_1 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END COMPONENT fir_wide_1;
    
    COMPONENT  fir_wide_2 IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tready : IN STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END COMPONENT fir_wide_2;
    
    signal resetn_r : std_logic := '1';
    signal reset_cic : std_logic;
--    signal dds_out : std_logic_vector(31 downto 0);  
--   signal mult_in : std_logic_vector(31 downto 0); 
--   signal mult_out : std_logic_vector(47 downto 0);  
    
    signal dds_out : std_logic_vector(31 downto 0);
    
    -- Сигналы для оптимизированного вещественного смесителя
    signal dds_cos : signed(15 downto 0);
    signal dds_sin : signed(15 downto 0);
    signal adc_sig : signed(15 downto 0);
    
    -- Промежуточные результаты умножения (16x16 = 32 бита, берем верхние 24 бита для CIC)
    signal mult_i_full : signed(31 downto 0) := (others => '0');
    signal mult_q_full : signed(31 downto 0) := (others => '0');
    
    signal cic_in_data_0, cic_in_data_1 : std_logic_vector(23 downto 0);   
    signal wb_cic_out_0, wb_cic_out_1 : std_logic_vector(23 downto 0);
    signal cic_out_0, cic_out_1 : std_logic_vector(23 downto 0) := (others => '0');
    signal cic_out_valid : std_logic_vector(1 downto 0);
    signal outwb_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal fir1wb_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir1wb_in_tvalid : STD_LOGIC := '0';
    signal fir1wb_in_tready : STD_LOGIC;
    signal fir1wb_out_tdata : STD_LOGIC_VECTOR (63 downto 0);
    signal fir2wb_in_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir2wb_in_tready : STD_LOGIC;
    signal fir2wb_in_tvalid : STD_LOGIC;
    signal fir2wb_out_tdata : STD_LOGIC_VECTOR (47 downto 0);
    signal fir2wb_out_tvalid : STD_LOGIC;
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal ctrl_tdata : std_logic_vector(7 downto 0) := (others => '0');
    signal sat_i_out : std_logic_vector(15 downto 0); 
    signal sat_q_out : std_logic_vector(15 downto 0); 
    signal sat_valid : STD_LOGIC := '0';

begin

dds_0 : dds16a
    PORT MAP (
        aclk => aclk, 
        s_axis_config_tvalid => dds_valid,
        s_axis_config_tdata => dds_value,
        m_axis_data_tvalid => open,
        m_axis_data_tdata => dds_out
    );
    
    -- Разделяем шину DDS на Cos (реальная) и Sin (мнимая) компоненты
    dds_cos <= signed(dds_out(31 downto 16));
    dds_sin <= signed(dds_out(15 downto 0));
    adc_sig <= signed(s_axis_signal_tdata);
    
-------------------------------------------------------------------------
    -- Оптимизированный смеситель с округлением: 0 смещения DC, всего 2 DSP!
    -------------------------------------------------------------------------
    p_mixer : process(aclk)
        variable v_mul_i : signed(31 downto 0);
        variable v_mul_q : signed(31 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                mult_i_full <= (others => '0');
                mult_q_full <= (others => '0');
            else
                -- 1. Вычисляем чистое произведение (16x16 = 32 бита)
                v_mul_i := adc_sig * dds_cos;
                v_mul_q := adc_sig * dds_sin;
                
                -- 2. Прибавляем 0.5 LSB нового 24-битного формата.
                --    Так как мы отбрасываем биты с 6 по 0, вес добавляемой единицы равен 2^6 = 64 (0x40).
                --    Это превращает усечение в симметричное округление и уничтожает DC-смещение.
                mult_i_full <= v_mul_i + to_signed(64, 32);
                mult_q_full <= v_mul_q + to_signed(64, 32);
            end if;
        end if;
    end process p_mixer;
    
    -- Извлекаем старшие 24 бита из 32-битного результата умножения для подачи на CIC.
    -- Формат Q1.15 * Q1.15 дает Q2.30. Старший бит - знаковый. Срез (30 downto 7)
    -- сохраняет сетку знака и точность без потери динамического диапазона.
    cic_in_data_0 <= std_logic_vector(mult_i_full(30 downto 7));
    cic_in_data_1 <= std_logic_vector(mult_q_full(30 downto 7));
    
--    mult_in <= s_axis_signal_tdata & s_axis_signal_tdata;
--    
--process(aclk)
--begin
--    if rising_edge(aclk) then
--        -- Классический полином LFSR x^16 + x^14 + x^13 + x^11 + 1
--        lfsr_reg <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);
--    end if;
--end process;
--
--    ctrl_tdata(0) <= lfsr_reg(0); -- Подаем случайный бит в нулевой разряд
--    ctrl_tdata(7 downto 1) <= (others => '0');
--    
--mult_0 : cmpy_16x16r24
--    PORT MAP (
--        aclk => aclk, 
--        aresetn => aresetn,
--        s_axis_a_tvalid => '1',
--        s_axis_a_tdata => mult_in,
--        s_axis_b_tvalid => '1',
--        s_axis_b_tdata => dds_out,
--        s_axis_ctrl_tvalid => '1',
--        s_axis_ctrl_tdata => ctrl_tdata,
--        m_axis_dout_tvalid => open,
--        m_axis_dout_tdata => mult_out
--    );
--    
--    cic_in_data_0 <= mult_out(47 downto 24);
--    cic_in_data_1 <= mult_out(23 downto 0);
    reset_cic <= aresetn and resetn_r;
    
process(aclk)
begin
	if rising_edge(aclk) then		
		resetn_r <= aresetn;  
	end if;
end process;

wb_cic_0 : cic_wide
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_0,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => wb_cic_out_0,
        m_axis_data_tvalid => cic_out_valid(0)
    );

wb_cic_1 : cic_wide
    PORT MAP (
        aclk => aclk,
        aresetn => reset_cic,
        s_axis_data_tdata => cic_in_data_1,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => wb_cic_out_1,
        m_axis_data_tvalid => cic_out_valid(1)
    );
    
process(aclk)
begin
	if rising_edge(aclk) then
	
		if cic_out_valid(0) = '1' then
		  cic_out_0 <= wb_cic_out_0;
		  outwb_valid(0) <= '1';
		end if; 
		if cic_out_valid(1) = '1' then
		  cic_out_1 <= wb_cic_out_1;
		  outwb_valid(1) <= '1';
		end if; 
		
		fir1wb_in_tvalid <= '0';
		if outwb_valid = "11" and fir1wb_in_tready = '1' then
		   outwb_valid <= (others => '0');
		   fir1wb_in_tvalid <= '1';		   
		end if; 
		
	end if;
end process;

    fir1wb_in_tdata <= cic_out_0 & cic_out_1;

wb_fir_1 : fir_wide_1
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir1wb_in_tvalid,
        s_axis_data_tready => fir1wb_in_tready,
        s_axis_data_tdata => fir1wb_in_tdata,
        m_axis_data_tvalid => fir2wb_in_tvalid,
        m_axis_data_tready => fir2wb_in_tready,
        m_axis_data_tdata => fir1wb_out_tdata
    );
    
    fir2wb_in_tdata <= fir1wb_out_tdata(63 downto 40) & fir1wb_out_tdata(31 downto 8);
    
wb_fir_2 : fir_wide_2
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir2wb_in_tvalid,
        s_axis_data_tready => fir2wb_in_tready,
        s_axis_data_tdata => fir2wb_in_tdata,
        m_axis_data_tvalid => fir2wb_out_tvalid,
        m_axis_data_tready => m_axis_wb_tready,
        m_axis_data_tdata => fir2wb_out_tdata
    );
    
 --   m_axis_wb_tdata <= fir2wb_out_tdata(42 downto 27) & fir2wb_out_tdata(18 downto 3);
 process(aclk)
    -- Переменные для выделения полных 24-битных знаковых каналов I и Q
    variable v_raw_i : signed(23 downto 0);
    variable v_raw_q : signed(23 downto 0);
    
    -- Переменные для округления (25 бит для защиты от промежуточного переполнения при сложении)
    variable v_round_i : signed(24 downto 0); 
    variable v_round_q : signed(24 downto 0);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            sat_i_out <= (others => '0');
            sat_q_out <= (others => '0');
            sat_valid <= '0';
        else
            -- 1. Разделяем выходную шину fir2wb на знаковые каналы I и Q (по 24 бита)
            v_raw_i := signed(fir2wb_out_tdata(47 downto 24));
            v_raw_q := signed(fir2wb_out_tdata(23 downto 0));
            
            -- Сдвиг флага валидности данных на 1 такт конвейера
            sat_valid <= fir2wb_out_tvalid;

            -- 2. Знаковое округление (Rounding)
            --    Поскольку целевое окно начинается с 4-го бита, отбрасываемые биты с 3 по 0 - это дробная часть.
            --    Прибавляем 0.5 LSB относительно нового МЗР. Для бита 4 это значение 8 (2^3 = "1000" в двоичной системе).
            v_round_i := resize(v_raw_i, 25) + to_signed(8, 25);
            v_round_q := resize(v_raw_q, 25) + to_signed(8, 25);

            -----------------------------------------------------------------
            -- 3. Проверка насыщения (Saturation) для I-канала
            --    Проверяем, укладывается ли округленный результат, сдвинутый на 4 бита,
            --    в границы 16-бит signed (-32768 до +32767).
            -----------------------------------------------------------------
            -- Сравнение и анализ переполнения идет строго по новой сетке со сдвигом (биты с 24 по 4)
            if (v_round_i(24 downto 4) > 32767) then
                sat_i_out <= x"7FFF"; -- Жесткое ограничение сверху (Положительный пик)
                ovr <= '1';
            elsif (v_round_i(24 downto 4) < -32768) then
                sat_i_out <= x"8000"; -- Жесткое ограничение снизу (Отрицательный пик)
                ovr <= '1';
            else
                -- Если переполнения нет, забираем округленный срез разрядов 19 downto 4
                sat_i_out <= std_logic_vector(v_round_i(19 downto 4));
                ovr <= '0';
            end if;

            -----------------------------------------------------------------
            -- 4. Проверка насыщения (Saturation) для Q-канала
            -----------------------------------------------------------------
            if (v_round_q(24 downto 4) > 32767) then
                sat_q_out <= x"7FFF";
                ovr <= '1';
            elsif (v_round_q(24 downto 4) < -32768) then
                sat_q_out <= x"8000";
                ovr <= '1';
            else
                sat_q_out <= std_logic_vector(v_round_q(19 downto 4));
                ovr <= '0';
            end if;
        end if;
    end if;
end process;

m_axis_wb_tdata  <= sat_i_out & sat_q_out;
m_axis_wb_tvalid <= sat_valid;


end Behavioral;
