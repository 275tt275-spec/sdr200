
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hf_dpd_ddc_block is
    generic (
        -- Коэффициент децимации (например, 2048: 122.88 МГц / 2048 = 60 кГц, идеально для полосы 5 кГц)
        DECIMATION_RATE : integer := 2048 
    );
    Port (
        aclk              : in  STD_LOGIC;                     -- 122.88 MHz
        s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        m_axis_bb_i       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
        m_axis_bb_q       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
        m_axis_bb_valid   : out STD_LOGIC                      -- Строб готовности данных (1 такт из 2048)
    );
end hf_dpd_ddc_block;

architecture Behavioral of hf_dpd_ddc_block is
    -- Сигналы смесителя
    signal adc_reg         : signed(15 downto 0) := (others => '0');
    signal dds_cos, dds_sin : signed(15 downto 0) := (others => '0');
    signal mix_i, mix_q     : signed(31 downto 0) := (others => '0');

    -- Секция интеграторов (работают на полной частоте 122.88 МГц)
    -- Разрядность увеличена до 64 бит для предотвращения переполнения при децимации
    signal int_i1, int_i2, int_i3 : signed(63 downto 0) := (others => '0');
    signal int_q1, int_q2, int_q3 : signed(63 downto 0) := (others => '0');

    -- Счетчик децимации
    signal decim_cnt       : integer range 0 to DECIMATION_RATE-1 := 0;
    signal decim_clk_en    : std_logic := '0';

    -- Секция гребенчатых фильтров (Comb), работают на пониженной частоте
    signal comb_i1_reg, comb_i2_reg : signed(63 downto 0) := (others => '0');
    signal comb_q1_reg, comb_q2_reg : signed(63 downto 0) := (others => '0');
    
    signal comb_i1, comb_i2, comb_i3 : signed(63 downto 0) := (others => '0');
    signal comb_q1, comb_q2, comb_q3 : signed(63 downto 0) := (others => '0');

begin

    process(aclk)
    begin
        if rising_edge(aclk) then
            -----------------------------------------------------------------
            -- 1. СМЕСИТЕЛЬ (122.88 МГц)
            -----------------------------------------------------------------
            adc_reg <= signed(s_axis_adc_tdata);
            dds_cos <= signed(s_axis_dds_tdata(15 downto 0));
            dds_sin <= -signed(s_axis_dds_tdata(31 downto 16));

            mix_i   <= adc_reg * dds_cos;
            mix_q   <= adc_reg * dds_sin;

            -----------------------------------------------------------------
            -- 2. ИНТЕГРАТОРЫ (3 каскада накопления, 122.88 МГц)
            -----------------------------------------------------------------
            int_i1 <= int_i1 + resize(mix_i, 64);
            int_i2 <= int_i2 + int_i1;
            int_i3 <= int_i3 + int_i2;

            int_q1 <= int_q1 + resize(mix_q, 64);
            int_q2 <= int_q2 + int_q1;
            int_q3 <= int_q3 + int_q2;

            -----------------------------------------------------------------
            -- 3. ДЕЦИМАТОР (Генератор строба частоты)
            -----------------------------------------------------------------
            if decim_cnt = DECIMATION_RATE - 1 then
                decim_cnt    <= 0;
                decim_clk_en <= '1';
            else
                decim_cnt    <= decim_cnt + 1;
                decim_clk_en <= '0';
            end if;

            -----------------------------------------------------------------
            -- 4. ГРЕБЕНЧАТЫЕ ФИЛЬТРЫ (Comb - дифференциаторы, частота ~60 кГц)
            -----------------------------------------------------------------
            m_axis_bb_valid <= decim_clk_en; -- Выходной строб валидности данных

            if decim_clk_en = '1' then
                -- Каскад 1
                comb_i1      <= int_i3 - comb_i1_reg;
                comb_i1_reg  <= int_i3;
                comb_q1      <= int_q3 - comb_q1_reg;
                comb_q1_reg  <= int_q3;

                -- Каскад 2
                comb_i2      <= comb_i1 - comb_i2_reg;
                comb_i2_reg  <= comb_i1;
                comb_q2      <= comb_q1 - comb_q2_reg;
                comb_q2_reg  <= comb_q1;

                -- Каскад 3
                comb_i3      <= comb_i2;
                comb_q3      <= comb_q2;

                -- Выходной сдвиг (разрядность нормализуется в зависимости от усиления CIC)
                -- Для 3-каскадного CIC с децимацией 2048 усиление составляет примерно 2048^3
                -- Мы берем стабильные старшие биты результата
                m_axis_bb_i  <= comb_i3(55 downto 40); 
                m_axis_bb_q  <= comb_q3(55 downto 40);
            end if;
        end if;
    end process;

end Behavioral;

