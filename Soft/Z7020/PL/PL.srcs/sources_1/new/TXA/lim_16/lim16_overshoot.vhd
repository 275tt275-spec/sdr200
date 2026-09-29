----------------------------------------------------------------------------------
-- Overshoot controller
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim16_overshoot is
Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_data_tvalid : in STD_LOGIC; 
        limit : in STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata : in STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : in STD_LOGIC;
        fir_reload_tlast : in STD_LOGIC;
        fir_config_tdata : in STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : in STD_LOGIC;
        over : out std_logic_vector(1 downto 0);
        denom_dbg : out std_logic_vector(15 downto 0); 
        aclk : in STD_LOGIC
    );
end lim16_overshoot;

architecture Behavioral of lim16_overshoot is

component lim16_translate_cordic
        port (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component lim16_translate_cordic;
    
    component blk_mem_32
        port (
            clka : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            clkb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
        );
    end component blk_mem_32;    
    
    COMPONENT lim16_lpf_fir IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_data_tvalid : IN STD_LOGIC;
            s_axis_data_tready : OUT STD_LOGIC;
            s_axis_data_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tready : OUT STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_reload_tvalid : IN STD_LOGIC;
            s_axis_reload_tready : OUT STD_LOGIC;
            s_axis_reload_tlast : IN STD_LOGIC;
            s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(95 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim16_lpf_fir;
    
    COMPONENT signed_round_sat is
    generic (
        IWID       : integer := 37; -- Исходная разрядность данных
        OWID       : integer := 24; -- Выходная разрядность после округления
        SHIFT_LEFT : integer := 0   -- Параметр сдвига данных вверх перед округлением (0, 1, 2 и т.д.)
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;
        i_data  : in  std_logic_vector(IWID-1 downto 0);
        i_valid : in  std_logic;
        o_data  : out std_logic_vector(OWID-1 downto 0);
        o_valid : out std_logic;
        ovf     : out std_logic -- Флаг фиксации переполнения (сатурации)
    );
    END COMPONENT  signed_round_sat;

    component lim16_div is
    generic (
        G_BIT_HIGH : integer := 17  -- Позиция старшего (знакового) бита выходного окна (задается снаружи)
    );
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component lim16_div;
    
    signal divout_0        : std_logic_vector(15 downto 0); 
    signal divout_1        : std_logic_vector(15 downto 0); 
    signal divout_valid_0  : std_logic;
    signal divout_valid_1  : std_logic;
    signal div_over_0      : std_logic;
    signal div_over_1      : std_logic;
    signal fir_in_tdata    : std_logic_vector(31 downto 0);
    signal fir_in_tvalid   : std_logic;
    
    -- Регистры хранения истории амплитуд (работают на частоте 16 кГц)
    signal audio_sync    : std_logic_vector(31 downto 0) := (others => '0');        
    signal delay_out_0, delay_out_1, delay_out_2   : std_logic_vector(31 downto 0) := (others => '0');        
    
    signal cordic_in     : std_logic_vector(31 downto 0);
    signal cordic_out    : std_logic_vector(31 downto 0);
    signal cordic_tvalid : std_logic;
    signal magnitude     : std_logic_vector(15 downto 0) := (others => '0');
    signal magnitude1    : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude2    : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude3    : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude4    : std_logic_vector(15 downto 0) := (others => '0');  
    signal max_reg       : std_logic_vector(15 downto 0) := (others => '0');
    signal corr          : std_logic_vector(15 downto 0) := x"0000";
    signal corr1         : std_logic_vector(15 downto 0) := x"0000";
    signal denom         : std_logic_vector(15 downto 0) := x"0001";
    signal delay_tvalid  : std_logic := '0';
    
    -- ИСПРАВЛЕНО: Выход FIR-фильтра должен быть строго 80 бит (79 downto 0)
    signal fir_out_tdata   : std_logic_vector(95 downto 0);
    signal fir_out_tvalid  : std_logic;
    
    constant GAIN_SHIFT : integer := 13;     
    signal ch_a_16_reg, ch_b_16_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal out_valid_reg            : std_logic := '0';
    signal out_over_a, out_over_b   : std_logic := '0';
    
        -- Счетчик тактов для последовательного выполнения операций
    signal calc_cycle : integer range 0 to 7 := 0;
    
    -- Промежуточные сигналы для дерева поиска максимума
    signal max_p1, max_p2 : unsigned(15 downto 0) := (others => '0');
    signal max_st2        : unsigned(15 downto 0) := (others => '0');
    signal max_final      : unsigned(15 downto 0) := (others => '0');
    
    -- Локальные регистры для математики
    signal v_corr         : unsigned(15 downto 0) := (others => '0');
    signal v_corr1        : unsigned(15 downto 0) := (others => '0');

begin

    denom_dbg <= denom;
    cordic_in <= s_axis_data_tdata(31) & s_axis_data_tdata(31 downto 17) & s_axis_data_tdata(15) & s_axis_data_tdata(15 downto 1);

mag_cordic_0 : lim16_translate_cordic
    PORT MAP (
      aclk                    => aclk,
      s_axis_cartesian_tvalid => s_axis_data_tvalid,
      s_axis_cartesian_tdata  => cordic_in, 
      m_axis_dout_tvalid      => cordic_tvalid,
      m_axis_dout_tdata       => cordic_out
    );

    -- Вычисляем модуль амплитуды из выхода CORDIC
    magnitude <= std_logic_vector(abs(signed(cordic_out(15 downto 0))));  
    
       -----------------------------------------------------------------
    -- РАСПРЕДЕЛЕННЫЙ ПО ТАКТАМ ПРОЦЕСС ВЫЧИСЛЕНИЯ DENOM (FSM/СЧЕТЧИК)
    -----------------------------------------------------------------
process(aclk)
    begin
        if rising_edge(aclk) then
            -- Строб валидности для делителя держится строго 1 такт aclk
            delay_tvalid <= '0';
            
            -- Шаг 0: Ожидание нового аудио-сэмпла от CORDIC (16 кГц)
            if cordic_tvalid = '1' then
                -- 1. Сдвигаем историю амплитуд в самый первый такт
                magnitude1   <= magnitude;
                magnitude2   <= magnitude1;
                magnitude3   <= magnitude2;
                magnitude4   <= magnitude3;
                
                -- 2. Сдвигаем историю аудио-сэмплов (строго в темпе 16 кГц)
                delay_out_0  <= s_axis_data_tdata;
                delay_out_1  <= delay_out_0;
                delay_out_2  <= delay_out_1;
                
                -- Запускаем последовательный вычислительный счетчик
                calc_cycle   <= 1;
                
            elsif calc_cycle > 0 then
                -- Инкрементируем счетчик тактов aclk
                if calc_cycle < 7 then
                    calc_cycle <= calc_cycle + 1;
                else
                    calc_cycle <= 0; -- Вычисления завершены, уходим в ожидание
                end if;
                
                -- Пошаговый автомат вычислений (1 операция за 1 такт aclk)
                case calc_cycle is
                    
                    when 1 =>
                        -- ТАКТ aclk 1: Первый ярус сравнения (параллельные независимые пары)
                        if unsigned(magnitude4) < unsigned(magnitude3) then 
                            max_p1 <= unsigned(magnitude3); 
                        else 
                            max_p1 <= unsigned(magnitude4); 
                        end if;
                        
                        if unsigned(magnitude2) < unsigned(magnitude1) then 
                            max_p2 <= unsigned(magnitude1); 
                        else 
                            max_p2 <= unsigned(magnitude2); 
                        end if;
                        
                    when 2 =>
                        -- ТАКТ aclk 2: Второй ярус сравнения
                        if max_p1 < max_p2 then 
                            max_st2 <= max_p2; 
                        else 
                            max_st2 <= max_p1; 
                        end if;
                        
                    when 3 =>
                        -- ТАКТ aclk 3: Финальный ярус сравнения (поиск максимума из 5 точек)
                        if max_st2 < unsigned(magnitude) then 
                            max_final <= unsigned(magnitude); 
                        else 
                            max_final <= max_st2; 
                        end if;
                        
                    when 4 =>
                        -- ТАКТ aclk 4: Сохранение максимума в регистр и расчет отклонения (corr)
                        max_reg <= std_logic_vector(max_final);
                        
                        if max_final < unsigned(limit) then
                            v_corr <= x"0000";
                        else
                            v_corr <= max_final - unsigned(limit);
                        end if;
                        
                    when 5 =>
                        -- ТАКТ aclk 5: Масштабирование отклонения (corr1) с насыщением
                        corr <= std_logic_vector(v_corr);
                        
                        if v_corr(15) = '1' then
                            v_corr1 <= x"FFFF";
                        else
                            v_corr1 <= v_corr(14 downto 0) & '0';
                        end if;
                        
                    when 6 =>
                        -- ТАКТ aclk 6: Формирование финального делителя (denom) с насыщением
                        corr1 <= std_logic_vector(v_corr1);
                        
                        if ("0" & v_corr1) + ("0" & unsigned(limit)) > 65535 then
                            denom <= x"FFFF";
                        else
                            denom <= std_logic_vector(v_corr1 + unsigned(limit));
                        end if;
                        
                        -- Фиксируем аудиоданные из центра скользящего окна
                        audio_sync <= delay_out_2;
                        
                    when 7 =>
                        -- ТАКТ aclk 7: Выставляем строб валидности на 1 такт для делителей.
                        -- На этом такте шины denom и audio_sync стабильны и синхронны!
                        delay_tvalid <= '1';
                        
                    when others => 
                        null;
                end case;
            end if;
        end if;
    end process;

    
div_0 : lim16_div
    generic map (
        G_BIT_HIGH => 16
    )
    PORT MAP (
        s_axis_divisor_tvalid  => delay_tvalid,
        s_axis_divisor_tdata   => denom,
        s_axis_dividend_tvalid => delay_tvalid,
        s_axis_dividend_tdata  => audio_sync(31 downto 16),
        m_axis_dout_tvalid     => divout_valid_0,
        m_axis_dout_tdata      => divout_0,
        out_over               => div_over_0,
        aclk                   => aclk
    );
    
div_1 : lim16_div
    generic map (
        G_BIT_HIGH => 16
    )
    PORT MAP (
        s_axis_divisor_tvalid  => delay_tvalid,
        s_axis_divisor_tdata   => denom,
        s_axis_dividend_tvalid => delay_tvalid,
        s_axis_dividend_tdata  => audio_sync(15 downto 0),
        m_axis_dout_tvalid     => divout_valid_1,
        m_axis_dout_tdata      => divout_1,
        out_over               => div_over_1,
        aclk                   => aclk
    );
  
    fir_in_tdata  <= divout_0 & divout_1;
    fir_in_tvalid <= divout_valid_0;
    over(0)       <= div_over_0 or div_over_1;
     
fir_0 : lim16_lpf_fir
    PORT MAP (
        aclk                            => aclk,
        s_axis_data_tvalid              => fir_in_tvalid,
        s_axis_data_tready              => open,
        s_axis_data_tdata               => fir_in_tdata,
        s_axis_config_tvalid            => fir_config_tvalid,
        s_axis_config_tready            => open,
        s_axis_config_tdata             => fir_config_tdata,
        s_axis_reload_tvalid            => fir_reload_tvalid,
        s_axis_reload_tready            => open,
        s_axis_reload_tlast             => fir_reload_tlast,
        s_axis_reload_tdata             => fir_reload_tdata,
        m_axis_data_tvalid              => fir_out_tvalid,
        m_axis_data_tdata               => fir_out_tdata,
        event_s_reload_tlast_missing    => open,
        event_s_reload_tlast_unexpected => open
    );
    
    signed_round_sat_0 : signed_round_sat
    generic map(
        IWID       => 48,
        OWID       => 16,
        SHIFT_LEFT => GAIN_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir_out_tdata(95 downto 48),
        i_valid => fir_out_tvalid,
        o_data  => ch_a_16_reg,
        o_valid => out_valid_reg,
        ovf     => out_over_a
    );
    
    signed_round_sat_1 : signed_round_sat
    generic map(
        IWID       => 48,
        OWID       => 16,
        SHIFT_LEFT => GAIN_SHIFT
    )
    port map (
        aclk    => aclk,
        aresetn => '1',
        i_data  => fir_out_tdata(47 downto 0),
        i_valid => fir_out_tvalid,
        o_data  => ch_b_16_reg,
        o_valid => open,
        ovf     => out_over_b
    );

    -----------------------------------------------------------------
    -- Назначение выходных портов модуля из стабильных регистров
    -----------------------------------------------------------------
    -- Теперь переключение шины данных и валида строго синхронизировано на Stage 2
    m_axis_data_tdata  <= ch_a_16_reg & ch_b_16_reg;
    m_axis_data_tvalid <= out_valid_reg;
    over(1)            <= out_over_a or out_over_b;
    
end Behavioral;

