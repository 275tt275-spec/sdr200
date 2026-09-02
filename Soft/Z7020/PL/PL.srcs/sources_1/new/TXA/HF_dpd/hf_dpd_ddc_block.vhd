library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd_ddc_block is
    Port (
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC;
        s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        s_axis_adc_tvalid : in  STD_LOGIC;
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        m_axis_bb_i       : out signed (15 downto 0);
        m_axis_bb_q       : out signed (15 downto 0);
        m_axis_bb_valid   : out STD_LOGIC;
        ovr               : out STD_LOGIC
    );
end hf_dpd_ddc_block;

architecture Behavioral of hf_dpd_ddc_block is
    
    -- Сигналы для NCO
    signal phase_acc       : unsigned(31 downto 0);
    signal phase_inc       : unsigned(31 downto 0);
    signal sin_lut_out     : signed(15 downto 0);
    signal cos_lut_out     : signed(15 downto 0);
    
    -- Сигналы для умножителей
    signal adc_data        : signed(15 downto 0);
    signal mix_i, mix_q    : signed(31 downto 0);
    
    -- Сигналы для CIC фильтра (децимация 2048)
    -- Для 122.88 МГц -> 60 кГц частота дискретизации
    constant CIC_STAGES    : integer := 4;
    constant CIC_DECIM     : integer := 2048;
    
    type cic_state_t is array (0 to CIC_STAGES-1) of signed(31 downto 0);
    signal cic_int_i, cic_int_q : cic_state_t;
    
    type cic_comb_t is array (0 to CIC_STAGES-1) of signed(31 downto 0);
    signal cic_comb_i, cic_comb_q : cic_comb_t;
    
    signal cic_comb_delay_i, cic_comb_delay_q : cic_comb_t;
    
    signal decim_counter   : integer range 0 to CIC_DECIM-1;
    signal decim_en        : STD_LOGIC;
    
    -- Сигналы для выходного буфера
    signal bb_i_reg, bb_q_reg : signed(15 downto 0);
    signal valid_reg       : STD_LOGIC;
    
begin
    
    -- ========================================================================
    -- 1. NCO (Численный управляемый генератор)
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                phase_acc <= (others => '0');
                phase_inc <= unsigned(s_axis_dds_tdata(31 downto 0));
            else
                phase_inc <= unsigned(s_axis_dds_tdata(31 downto 0));
                phase_acc <= phase_acc + phase_inc;
            end if;
        end if;
    end process;
    
    -- LUT для Sin/Cos (квартальная аппроксимация)
    DDS_LUT_Inst: entity work.dds_lut
        Port map (
            clk      => aclk,
            phase    => phase_acc(31 downto 24), -- Используем старшие 8 бит
            sin_out  => sin_lut_out,
            cos_out  => cos_lut_out
        );
    
    -- ========================================================================
    -- 2. Смеситель (Перенос на нулевую частоту)
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                adc_data <= (others => '0');
                mix_i <= (others => '0');
                mix_q <= (others => '0');
            elsif s_axis_adc_tvalid = '1' then
                adc_data <= signed(s_axis_adc_tdata);
                -- I = adc * cos, Q = adc * sin
                mix_i <= adc_data * cos_lut_out;
                mix_q <= adc_data * sin_lut_out;
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 3. CIC фильтр (интегратор + дециматор + гребенчатый фильтр)
    -- ========================================================================
    
    -- Интегратор
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                for i in 0 to CIC_STAGES-1 loop
                    cic_int_i(i) <= (others => '0');
                    cic_int_q(i) <= (others => '0');
                end loop;
            else
                cic_int_i(0) <= cic_int_i(0) + mix_i(31 downto 16);
                cic_int_q(0) <= cic_int_q(0) + mix_q(31 downto 16);
                
                for i in 1 to CIC_STAGES-1 loop
                    cic_int_i(i) <= cic_int_i(i) + cic_int_i(i-1);
                    cic_int_q(i) <= cic_int_q(i) + cic_int_q(i-1);
                end loop;
            end if;
        end if;
    end process;
    
    -- Дециматор
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                decim_counter <= 0;
                decim_en <= '0';
            else
                if decim_counter = CIC_DECIM-1 then
                    decim_counter <= 0;
                    decim_en <= '1';
                else
                    decim_counter <= decim_counter + 1;
                    decim_en <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Гребенчатый фильтр
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                for i in 0 to CIC_STAGES-1 loop
                    cic_comb_delay_i(i) <= (others => '0');
                    cic_comb_delay_q(i) <= (others => '0');
                    cic_comb_i(i) <= (others => '0');
                    cic_comb_q(i) <= (others => '0');
                end loop;
            elsif decim_en = '1' then
                -- Сохраняем выход интегратора в момент децимации
                cic_comb_delay_i(0) <= cic_int_i(CIC_STAGES-1);
                cic_comb_delay_q(0) <= cic_int_q(CIC_STAGES-1);
                cic_comb_i(0) <= cic_int_i(CIC_STAGES-1) - cic_comb_delay_i(0);
                cic_comb_q(0) <= cic_int_q(CIC_STAGES-1) - cic_comb_delay_q(0);
                
                for i in 1 to CIC_STAGES-1 loop
                    cic_comb_delay_i(i) <= cic_comb_i(i-1);
                    cic_comb_delay_q(i) <= cic_comb_q(i-1);
                    cic_comb_i(i) <= cic_comb_i(i-1) - cic_comb_delay_i(i);
                    cic_comb_q(i) <= cic_comb_q(i-1) - cic_comb_delay_q(i);
                end loop;
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 4. Выходной буфер
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                bb_i_reg <= (others => '0');
                bb_q_reg <= (others => '0');
                valid_reg <= '0';
            else
                if decim_en = '1' then
                    -- Масштабирование и приведение к 16 бит
                    bb_i_reg <= resize(shift_right(cic_comb_i(CIC_STAGES-1), CIC_STAGES*2 - 1), 16);
                    bb_q_reg <= resize(shift_right(cic_comb_q(CIC_STAGES-1), CIC_STAGES*2 - 1), 16);
                    valid_reg <= '1';
                else
                    valid_reg <= '0';
                end if;
            end if;
        end if;
    end process;
    
    m_axis_bb_i <= bb_i_reg;
    m_axis_bb_q <= bb_q_reg;
    m_axis_bb_valid <= valid_reg;
    ovr <= '0';
    
end Behavioral;