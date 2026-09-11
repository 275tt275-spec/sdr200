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
        txa_on            : in  STD_LOGIC;
        
        -- DDS для DDC
        s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
        
        -- Выход конфигурации
        m_cfg_dout        : out STD_LOGIC_VECTOR (31 downto 0);
       
        -- Тактирование и сброс
        aclk              : in  STD_LOGIC;
        aresetn           : in  STD_LOGIC
    );
end hf_dpd;

architecture Structural of hf_dpd is

    component dpd_fb is
        Port (
            ref_i : in  STD_LOGIC_VECTOR (15 downto 0);
            ref_q : in  STD_LOGIC_VECTOR (15 downto 0);
            adc_fb : in  STD_LOGIC_VECTOR (15 downto 0);
            s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
            fb_out_i : out  STD_LOGIC_VECTOR (15 downto 0);
            fb_out_q : out  STD_LOGIC_VECTOR (15 downto 0);
            txa_on : in  STD_LOGIC;
            cfg_clr : in  STD_LOGIC;
            phase_slow : in  STD_LOGIC;
            i_corr_amp : in std_logic_vector(17 downto 0);
            q_corr_amp : in std_logic_vector(17 downto 0);
            s_axis_cfg_tdata : in STD_LOGIC_VECTOR (7 downto 0);
            s_axis_cfg_tdest : in STD_LOGIC_VECTOR (1 downto 0);
            s_axis_cfg_tvalid : in STD_LOGIC;
            aclk : in  STD_LOGIC
        );
    end component dpd_fb;

	component adc2zeroif
    Port ( 
        clk : in  STD_LOGIC;
        ce : in  STD_LOGIC;
        clr : in  STD_LOGIC;
        din : in  STD_LOGIC_VECTOR (15 downto 0);
        cosine : in  STD_LOGIC_VECTOR (15 downto 0);
        sine : in  STD_LOGIC_VECTOR (15 downto 0);
        i_amp : in  STD_LOGIC_VECTOR (17 downto 0);
        q_amp : in  STD_LOGIC_VECTOR (17 downto 0);
        i_out : out  STD_LOGIC_VECTOR (15 downto 0);
        q_out : out  STD_LOGIC_VECTOR (15 downto 0)
    );
	end component;
    
    -- ========================================================================
    -- 1. ВНУТРЕННИЕ СИГНАЛЫ (решение проблемы с чтением out портов)
    -- ========================================================================
    
    -- Сигналы для DDC
    signal bb_i_sig, bb_q_sig   : signed(15 downto 0);
    signal ref_i_sig, ref_q_sig : signed(15 downto 0);
    signal ref_i_reg, ref_q_reg : std_logic_vector(15 downto 0);
    signal ddc_ovf              : std_logic_vector(1 downto 0);
    signal error_i, error_q     : signed(31 downto 0) := (others => '0');
    signal error_valid          : STD_LOGIC := '0';
    signal sine_dds, cosine_dds : std_logic_vector(15 downto 0);
    signal i_corr_amp, q_corr_amp : std_logic_vector(17 downto 0) := x"7fff" & "00";
    signal bb_i, bb_q           : std_logic_vector(15 downto 0);

    
    -- Сигналы управления
    signal cfg_delay_ticks      : std_logic_vector(7 downto 0) := x"01";
    signal cfg_train_en         : STD_LOGIC := '0';
    signal cfg_hold_coeffs      : STD_LOGIC := '0';
    signal cfg_bypass           : STD_LOGIC := '1';
    signal cfg_address          : INTEGER range 0 to 31;
    signal cfg_data             : STD_LOGIC_VECTOR(31 downto 0);
    signal cfg_clr              : STD_LOGIC := '0';
    signal cfg_phase_slow       : STD_LOGIC := '0';
    signal dpd_fb_cfg_tvalid    : STD_LOGIC := '0';
    
    -- Сигналы для DPD ядра
    signal dpd_i_out, dpd_q_out : signed(15 downto 0);
    signal dpd_ovf              : STD_LOGIC;
    
    -- Буфер для входных данных
    signal iq_i, iq_q           : signed(23 downto 0);
    signal iq25_i, iq25_q       : signed(24 downto 0);
    
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
    
    cosine_dds <= s_axis_dds_tdata(15 downto 0);
    sine_dds <= s_axis_dds_tdata(31 downto 16);	
    iq25_i <= resize(iq_i, 25) + to_signed(128, 25);
    iq25_q <= resize(iq_q, 25) + to_signed(128, 25);
    
    ref_i_sig <= iq25_i(23 downto 8);
    ref_q_sig <= iq25_q(23 downto 8);
    ref_i_reg <= std_logic_vector(ref_i_sig);
    ref_q_reg <= std_logic_vector(ref_q_sig);
    
inst_dpd_fb : dpd_fb
    Port map (
        ref_i            => ref_i_reg,
        ref_q            => ref_q_reg,
        adc_fb           => s_axis_adc_tdata,
        s_axis_dds_tdata => s_axis_dds_tdata,
        fb_out_i         => bb_i,
        fb_out_q         => bb_q,
        txa_on           => txa_on,
        cfg_clr          => cfg_clr,
        phase_slow       => cfg_phase_slow,
        i_corr_amp       => i_corr_amp,
        q_corr_amp       => q_corr_amp,
        s_axis_cfg_tdata => s_axis_cfg_tdata(7 downto 0),
        s_axis_cfg_tdest => s_axis_cfg_tdest(1 downto 0),
        s_axis_cfg_tvalid => dpd_fb_cfg_tvalid,
        aclk             => aclk
    );
    
    bb_i_sig <= signed(bb_i);
    bb_q_sig <= signed(bb_q);  
    
    DPD_Error_Inst: entity work.dpd_align_and_error_top
    Generic map (
        DATA_WIDTH   => 16,
        ADDR_WIDTH   => 8,    -- 2^8 = 256 тактов максимальной задержки для RAM
        ALPHA_SHIFT  => 2     -- Коэффициент сглаживания фильтра (1/256)
    )
    Port map (
        aclk                 => aclk,
        aresetn              => aresetn,
        cfg_delay_ticks      => cfg_delay_ticks,
        cfg_train_en         => cfg_train_en,
        cfg_hold_coeffs      => cfg_hold_coeffs,
        s_axis_ref_tdata_i   => ref_i_sig,
        s_axis_ref_tdata_q   => ref_q_sig,
        s_axis_ref_tvalid    => '1',
        s_axis_fb_tdata_i    => bb_i_sig,
        s_axis_fb_tdata_q    => bb_q_sig,
        s_axis_fb_tvalid     => '1',
        m_axis_err_i         => error_i,
        m_axis_err_q         => error_q,
        m_axis_err_valid     => error_valid
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
            s_axis_fb_i       => bb_i_sig,
            s_axis_fb_q       => bb_q_sig,
            s_axis_fb_valid   => '1',
            
            -- Сигнал ошибки
            error_i           => error_i,
            error_q           => error_q,
            error_valid       => error_valid,
            
            -- Управление
            cfg_delay_ticks   => cfg_delay_ticks,
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
    dpd_fb_cfg_tvalid <= s_axis_cfg_tvalid when s_axis_cfg_tdest(4) = '1' else '0'; 
    
    process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                cfg_train_en <= '0';
                cfg_hold_coeffs <= '0';
                cfg_bypass <= '1';
                cfg_address <= 0;
                cfg_data <= (others => '0');
                m_cfg_dout <= (others => '0');
            else
                m_cfg_dout(0) <= dpd_ovf;
                m_cfg_dout(1) <= cfg_train_en;
                m_cfg_dout(2) <= cfg_hold_coeffs;
                m_cfg_dout(3 downto 2) <= ddc_ovf;
                
                if s_axis_cfg_tvalid = '1' then                
                    case to_integer(unsigned(s_axis_cfg_tdest)) is
                        when 0 => -- Адрес 0: Управление
                            cfg_train_en <= s_axis_cfg_tdata(0);
                            cfg_hold_coeffs <= s_axis_cfg_tdata(1);
                            cfg_bypass <= s_axis_cfg_tdata(2);                            
                        when 1 => 
                            cfg_delay_ticks <= s_axis_cfg_tdata(7 downto 0);   
                        when 7 => 
				            i_corr_amp <= s_axis_cfg_tdata(17 downto 0);
			            when 8 =>
				            q_corr_amp <= s_axis_cfg_tdata(17 downto 0);
      
                        when others =>
                            
                    end case;
                end if;
            end if;
        end if;
    end process;
    
end Structural;