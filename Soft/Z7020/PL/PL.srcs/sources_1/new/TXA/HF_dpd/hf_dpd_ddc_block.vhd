library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd_ddc_block is
    Port (
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC;
        s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);  -- {Q(15:0), I(15:0)}
        m_axis_bb_i       : out signed (15 downto 0);
        m_axis_bb_q       : out signed (15 downto 0);
        m_axis_bb_valid   : out STD_LOGIC;
        ovr               : out STD_LOGIC
    );
end hf_dpd_ddc_block;

architecture Structural of hf_dpd_ddc_block is
    
    -- ========================================================================
    -- 1. КОМПОНЕНТ CIC IP (СГЕНЕРИРОВАННЫЙ ВАМИ)
    -- ========================================================================
    COMPONENT cic_hf_dpd
        PORT (
            aclk                : IN  STD_LOGIC;
            aresetn             : IN  STD_LOGIC;
            s_axis_data_tdata   : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            s_axis_data_tvalid  : IN  STD_LOGIC;
            s_axis_data_tready  : OUT STD_LOGIC;
            m_axis_data_tdata   : OUT STD_LOGIC_VECTOR(55 DOWNTO 0);
            m_axis_data_tvalid  : OUT STD_LOGIC
        );
    END COMPONENT;
    
    -- ========================================================================
    -- 2. СИГНАЛЫ
    -- ========================================================================
    
    -- Сигналы DDS (входные I/Q)
    signal dds_i             : signed(15 downto 0) := (others => '0');
    signal dds_q             : signed(15 downto 0) := (others => '0');
    
    -- Сигналы АЦП
    signal adc_data          : signed(15 downto 0) := (others => '0');
    
    -- Сигналы смесителя
    signal mix_i_full        : signed(31 downto 0) := (others => '0');
    signal mix_q_full        : signed(31 downto 0) := (others => '0');
    signal mix_i, mix_q      : signed(15 downto 0) := (others => '0');
    
    -- Сигналы для CIC IP
    signal cic_i_tdata       : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal cic_i_tvalid      : STD_LOGIC := '0';
    signal cic_i_tready      : STD_LOGIC;
    signal cic_i_tdata_out   : STD_LOGIC_VECTOR(55 downto 0) := (others => '0');
    signal cic_i_tvalid_out  : STD_LOGIC := '0';
    
    signal cic_q_tdata       : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal cic_q_tvalid      : STD_LOGIC := '0';
    signal cic_q_tready      : STD_LOGIC;
    signal cic_q_tdata_out   : STD_LOGIC_VECTOR(55 downto 0) := (others => '0');
    signal cic_q_tvalid_out  : STD_LOGIC := '0';
    
    -- Сигналы для выхода
    signal bb_i_scaled       : signed(15 downto 0) := (others => '0');
    signal bb_q_scaled       : signed(15 downto 0) := (others => '0');
    signal valid_reg         : STD_LOGIC := '0';
    signal overflow_flag     : STD_LOGIC := '0';
    signal init_done         : STD_LOGIC := '0';
    
    -- Константы масштабирования для CIC
    -- CIC: 3 каскада, децимация 2048, вход 16 бит, выход 49 бит
    -- Сдвиг для приведения к 16 бит: 49 - 16 = 33
    constant SCALE_SHIFT    : integer := 32;
    
begin
    
    -- ========================================================================
    -- 3. ИЗВЛЕЧЕНИЕ I/Q ИЗ DDS
    -- ========================================================================
    -- Формат s_axis_dds_tdata: {Q(15:0), I(15:0)}
    dds_i <= signed(s_axis_dds_tdata(15 downto 0));
    dds_q <= signed(s_axis_dds_tdata(31 downto 16));
    
    -- ========================================================================
    -- 4. СМЕСИТЕЛЬ (I/Q ДЕМОДУЛЯЦИЯ)
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                adc_data <= (others => '0');
                mix_i_full <= (others => '0');
                mix_q_full <= (others => '0');
                mix_i <= (others => '0');
                mix_q <= (others => '0');
                init_done <= '0';
            else
                adc_data <= signed(s_axis_adc_tdata);
                init_done <= '1';
                
                -- I = adc * cos (I компонента DDS)
                -- Q = adc * sin (Q компонента DDS)
                mix_i_full <= adc_data * dds_i;
                mix_q_full <= adc_data * dds_q;
                
                -- Обрезаем до 16 бит для CIC (берем старшие биты)
                mix_i <= mix_i_full(30 downto 15);
                mix_q <= mix_q_full(30 downto 15);
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 5. CIC ФИЛЬТРЫ ДЛЯ I И Q КАНАЛОВ
    -- ========================================================================
    
    -- I канал
    cic_i_tdata <= std_logic_vector(mix_i);
    cic_i_tvalid <= init_done;
    
    CIC_I_Inst: cic_hf_dpd
        PORT MAP (
            aclk                => aclk,
            aresetn             => aresetn,
            s_axis_data_tdata   => cic_i_tdata,
            s_axis_data_tvalid  => cic_i_tvalid,
            s_axis_data_tready  => cic_i_tready,
            m_axis_data_tdata   => cic_i_tdata_out,
            m_axis_data_tvalid  => cic_i_tvalid_out
        );
    
    -- Q канал
    cic_q_tdata <= std_logic_vector(mix_q);
    cic_q_tvalid <= init_done;
    
    CIC_Q_Inst: cic_hf_dpd
        PORT MAP (
            aclk                => aclk,
            aresetn             => aresetn,
            s_axis_data_tdata   => cic_q_tdata,
            s_axis_data_tvalid  => cic_q_tvalid,
            s_axis_data_tready  => cic_q_tready,
            m_axis_data_tdata   => cic_q_tdata_out,
            m_axis_data_tvalid  => cic_q_tvalid_out
        );
    
-- ========================================================================
-- 6. МАСШТАБИРОВАНИЕ И НАСЫЩЕНИЕ ВЫХОДА (УПРОЩЕННАЯ ВЕРСИЯ)
-- ========================================================================
process(aclk)
    variable temp_i, temp_q : signed(55 downto 0);
    variable scaled_i, scaled_q : signed(15 downto 0);
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            bb_i_scaled <= (others => '0');
            bb_q_scaled <= (others => '0');
            valid_reg <= '0';
            overflow_flag <= '0';
        else
            if cic_i_tvalid_out = '0' and cic_q_tvalid_out = '0' then
                overflow_flag <= '0';
            end if;
            
            if cic_i_tvalid_out = '1' and cic_q_tvalid_out = '1' then
                -- Преобразуем выход CIC в signed
                temp_i := signed(cic_i_tdata_out);
                temp_q := signed(cic_q_tdata_out);
                
                -- ============================================================
                -- МАСШТАБИРОВАНИЕ С НАСЫЩЕНИЕМ
                -- ============================================================
                
                -- I канал
                -- Сначала проверяем на переполнение до сдвига
                if temp_i > shift_left(to_signed(32767, 56), SCALE_SHIFT) then
                    bb_i_scaled <= to_signed(32767, 16);
                    overflow_flag <= '1';
                elsif temp_i < shift_left(to_signed(-32768, 56), SCALE_SHIFT) then
                    bb_i_scaled <= to_signed(-32768, 16);
                    overflow_flag <= '1';
                else
                    -- Безопасный сдвиг
                    scaled_i := resize(shift_right(temp_i, SCALE_SHIFT), 16);
                    bb_i_scaled <= scaled_i;
                end if;
                
                -- Q канал
                if temp_q > shift_left(to_signed(32767, 56), SCALE_SHIFT) then
                    bb_q_scaled <= to_signed(32767, 16);
                    overflow_flag <= '1';
                elsif temp_q < shift_left(to_signed(-32768, 56), SCALE_SHIFT) then
                    bb_q_scaled <= to_signed(-32768, 16);
                    overflow_flag <= '1';
                else
                    scaled_q := resize(shift_right(temp_q, SCALE_SHIFT), 16);
                    bb_q_scaled <= scaled_q;
                end if;
                
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end if;
end process;
    
    -- ========================================================================
    -- 7. ВЫХОДНЫЕ СИГНАЛЫ
    -- ========================================================================
    m_axis_bb_i <= bb_i_scaled;
    m_axis_bb_q <= bb_q_scaled;
    m_axis_bb_valid <= valid_reg;
    ovr <= overflow_flag;
    
end Structural;