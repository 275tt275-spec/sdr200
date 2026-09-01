
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hf_dpd_ddc_block is
    Port (
        aclk              : in  STD_LOGIC;                     -- 122.88 MHz
        aresetn           : in  STD_LOGIC;
        s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        m_axis_bb_i       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
        m_axis_bb_q       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
        m_axis_bb_valid   : out STD_LOGIC;                     -- Строб готовности данных (1 такт из 2048)
        ovr               : out STD_LOGIC
    );
end hf_dpd_ddc_block;

architecture Behavioral of hf_dpd_ddc_block is

    component cic_hf_dpd IS
        PORT (
            aclk : IN STD_LOGIC;
            aresetn : IN STD_LOGIC;
            s_axis_data_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            s_axis_data_tvalid : IN STD_LOGIC;
            s_axis_data_tready : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC
        );
    end component cic_hf_dpd;

   -- Константы ограничений для 16-битного знакового выхода (Saturated Output)
    constant MAX_SIGNED_16 : signed(15 downto 0) := x"7FFF"; -- +32767
    constant MIN_SIGNED_16 : signed(15 downto 0) := x"8000"; -- -32768

    -- Сигналы смесителя
    signal adc_reg              : signed(15 downto 0) := (others => '0');
    signal dds_cos, dds_sin     : signed(15 downto 0) := (others => '0');
    signal mix_i, mix_q         : signed(31 downto 0) := (others => '0');
    signal mix_i16, mix_q16     : std_logic_vector(15 downto 0);
    signal cic_out_i, cic_out_q : std_logic_vector(55 downto 0);
    signal cic_v_i, cic_v_q     : std_logic := '0';
    signal cic_reg_i, cic_reg_q : signed(55 downto 0);
    signal v_reg_i, v_reg_q     : std_logic := '0';
    
    signal ovr_reg  : STD_LOGIC := '0';

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
         end if;
    end process;

    ovr <= ovr_reg;
    mix_i16 <= std_logic_vector(mix_i(30 downto 15));
    mix_q16 <= std_logic_vector(mix_q(30 downto 15));
    
    hf_dpd_cic_i : cic_hf_dpd
    PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_data_tdata => mix_i16,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_i,
        m_axis_data_tvalid => cic_v_i
    );
    
    hf_dpd_cic_q : cic_hf_dpd
    PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_data_tdata => mix_q16,
        s_axis_data_tvalid => '1',
        s_axis_data_tready => open,
        m_axis_data_tdata => cic_out_q,
        m_axis_data_tvalid => cic_v_q
    );

    process(aclk)
    begin
        if rising_edge(aclk) then
            ovr_reg <= '0';
            if cic_v_i = '1' then
                cic_reg_i <= signed(cic_out_i);
                v_reg_i <= '1';
            end if;
            if cic_v_q = '1' then
                cic_reg_q <= signed(cic_out_q);
                v_reg_q <= '1';
            end if;
            if v_reg_i = '1' and v_reg_q = '1' then
                m_axis_bb_valid <= '1';
                v_reg_i <= '0';
                v_reg_q <= '0';
                
                if (cic_reg_i(55 downto 47) /= "000000000" and cic_reg_i(55 downto 47) /= "111111111") then
                    -- Переполнение! Смотрим на старший (знаковый) бит для определения знака полки
                    if cic_reg_i(55) = '0' then
                        m_axis_bb_i <= MAX_SIGNED_16; -- Положительное насыщение
                    else
                        m_axis_bb_i <= MIN_SIGNED_16; -- Отрицательное насыщение
                    end if;
                    ovr_reg <= '1';
                else
                    -- Переполнения нет, безопасно отдаем целевые 16 бит
                    m_axis_bb_i <= cic_reg_i(47 downto 32);
                end if;
                
                if (cic_reg_q(55 downto 47) /= "000000000" and cic_reg_q(55 downto 47) /= "111111111") then
                    -- Переполнение! Смотрим на старший (знаковый) бит для определения знака полки
                    if cic_reg_q(55) = '0' then
                        m_axis_bb_q <= MAX_SIGNED_16; -- Положительное насыщение
                    else
                        m_axis_bb_q <= MIN_SIGNED_16; -- Отрицательное насыщение
                    end if;
                    ovr_reg <= '1';
                else
                    -- Переполнения нет, безопасно отдаем целевые 16 бит
                    m_axis_bb_q <= cic_reg_q(47 downto 32);
                end if;
                
            else
                m_axis_bb_valid <= '0';    
            end if;

        end if;
    end process;

end Behavioral;

