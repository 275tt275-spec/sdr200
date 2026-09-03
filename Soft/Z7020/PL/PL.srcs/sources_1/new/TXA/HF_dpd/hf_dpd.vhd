library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity hf_dpd is
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
        
        -- DDS для DDC
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        
        -- Выход конфигурации
        m_cfg_dout        : out STD_LOGIC_VECTOR (31 downto 0);
        
        -- Статус переполнения
        m_ovf             : out STD_LOGIC_VECTOR(1 downto 0);
        
        -- Тактирование и сброс
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC
    );
end hf_dpd;

architecture Structural of hf_dpd is
    
    -- ========================================================================
    -- 1. ВНУТРЕННИЕ СИГНАЛЫ (решение проблемы с чтением out портов)
    -- ========================================================================
    
    -- Сигналы для DDC
    signal bb_i, bb_q           : signed(15 downto 0);
    signal bb_valid             : STD_LOGIC;
    signal adc_ovf              : STD_LOGIC;
    
    -- Сигналы управления
    signal cfg_train_en         : STD_LOGIC := '0';
    signal cfg_hold_coeffs      : STD_LOGIC := '0';
    signal cfg_bypass           : STD_LOGIC := '1';
    signal cfg_address          : INTEGER range 0 to 31;
    signal cfg_data             : STD_LOGIC_VECTOR(31 downto 0);
    signal cfg_we               : STD_LOGIC;
    
    -- Сигналы для DPD ядра
    signal dpd_i_out, dpd_q_out : signed(15 downto 0);
    signal dpd_ovf              : STD_LOGIC;
    
    -- Буфер для входных данных
    signal iq_i, iq_q           : signed(23 downto 0);
    
begin
    
    -- ========================================================================
    -- 3. БЛОК ПРИЕМА ВХОДНЫХ I/Q ДАННЫХ
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                iq_i <= (others => '0');
                iq_q <= (others => '0');
            else
                -- Извлечение I и Q из 48-битного слова
                -- Формат: {Q(23:0), I(23:0)}
                iq_i <= signed(s_axis_iq_tdata(23 downto 0));
                iq_q <= signed(s_axis_iq_tdata(47 downto 24));
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 4. DDC БЛОК
    -- ========================================================================
    DDC_Inst: entity work.hf_dpd_ddc_block
        Port map (
            aclk              => aclk,
            aresetn           => aresetn,
            s_axis_adc_tdata  => s_axis_adc_tdata,
            s_axis_dds_tdata  => s_axis_dds_tdata,
            m_axis_bb_i       => bb_i,
            m_axis_bb_q       => bb_q,
            m_axis_bb_valid   => bb_valid,
            ovr               => adc_ovf
        );
    
    -- ========================================================================
    -- 5. ЯДРО DPD
    -- ========================================================================
    DPD_Core_Inst: entity work.hf_dpd_core_200w
        Generic map (
            MEMORY_DEPTH   => 3,
            LUT_ADDR_WIDTH => 8,
            DATA_WIDTH     => 16,
            COEFF_WIDTH    => 16
        )
        Port map (
            aclk              => aclk,
            aresetn           => aresetn,
            
            -- Входной сигнал (I/Q 24-бит -> приводим к 16 бит)
            s_axis_iq_i       => iq_i(23 downto 8),
            s_axis_iq_q       => iq_q(23 downto 8),
            
            -- Выходной сигнал
            m_axis_iq_i       => dpd_i_out,
            m_axis_iq_q       => dpd_q_out,
            
            -- Сигнал обратной связи
            s_axis_fb_i       => bb_i,
            s_axis_fb_q       => bb_q,
            s_axis_fb_valid   => bb_valid,
            
            -- Управление
            cfg_train_en      => cfg_train_en,
            cfg_hold_coeffs   => cfg_hold_coeffs,
            
            -- Статус
            m_ovf             => dpd_ovf
        );
    
    -- ========================================================================
    -- 6. ФОРМИРОВАНИЕ ВЫХОДНОГО AXI STREAM
    -- ========================================================================
    process(aclk)
        variable i_scaled, q_scaled : signed(15 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                m_axis_iq_tdata <= (others => '0');
            elsif cfg_bypass = '1' then
                -- Вход: 48 бит {Q(23:0), I(23:0)}
                -- Выход: 32 бит {Q(15:0), I(15:0)}
                -- Берем старшие 16 бит с округлением
                
                -- I канал (биты 23..0)
                i_scaled := resize(shift_right(signed(s_axis_iq_tdata(23 downto 0)), 8), 16);
                -- Q канал (биты 47..24)
                q_scaled := resize(shift_right(signed(s_axis_iq_tdata(47 downto 24)), 8), 16);
                
                m_axis_iq_tdata <= std_logic_vector(q_scaled) & std_logic_vector(i_scaled);
            else
                -- Формат: {Q(15:0), I(15:0)}
                m_axis_iq_tdata <= std_logic_vector(dpd_q_out) & std_logic_vector(dpd_i_out);
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 7. БЛОК УПРАВЛЕНИЯ КОНФИГУРАЦИЕЙ
    -- ========================================================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                cfg_train_en <= '0';
                cfg_hold_coeffs <= '0';
                cfg_bypass <= '1';
                cfg_address <= 0;
                cfg_data <= (others => '0');
                cfg_we <= '0';
                m_cfg_dout <= (others => '0');
            else
                
                if s_axis_cfg_tvalid = '1' then
                    case to_integer(unsigned(s_axis_cfg_tdest)) is
                        when 0 => -- Адрес 0: Управление
                            cfg_train_en <= s_axis_cfg_tdata(0);
                            cfg_hold_coeffs <= s_axis_cfg_tdata(1);
                            cfg_bypass <= s_axis_cfg_tdata(2);
                            cfg_we <= '1';
                            
                            -- Ответное подтверждение
                            m_cfg_dout <= x"00000001";
                            
                        when 1 => -- Адрес 1: Чтение статуса
                            m_cfg_dout(0) <= dpd_ovf;
                            m_cfg_dout(1) <= adc_ovf;
                            m_cfg_dout(2) <= cfg_train_en;
                            m_cfg_dout(3) <= cfg_hold_coeffs;
                            
                        when others =>
                            m_cfg_dout <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    -- ========================================================================
    -- 8. ВЫХОДНЫЕ СТАТУСНЫЕ СИГНАЛЫ
    -- ========================================================================
    m_ovf(0) <= dpd_ovf;
    m_ovf(1) <= adc_ovf;
    
end Structural;