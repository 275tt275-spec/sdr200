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
    -- ЕДИНЫЙ ПРОЦЕСС ОБРАБОТКИ АУДИОСИГНАЛА С РАЗРЕШЕНИЕМ ТАКТИРОВАНИЯ (CE)
    -----------------------------------------------------------------
    process(aclk)
        -- Локальные переменные для мгновенного поиска максимума на частоте отсчетов
        variable max_pair1  : unsigned(15 downto 0);
        variable max_pair2  : unsigned(15 downto 0);
        variable max_stage2 : unsigned(15 downto 0);
        variable v_max      : unsigned(15 downto 0);
        variable v_corr     : unsigned(15 downto 0);
        variable v_corr1    : unsigned(15 downto 0);
    begin
        if rising_edge(aclk) then
            -- Строб валидности для делителя держится ровно 1 такт aclk
            delay_tvalid <= '0';
            
            -- Логика активируется СТРОГО в момент готовности отсчета от CORDIC (16 кГц)
            if cordic_tvalid = '1' then
                
                -- 1. Сдвиг истории амплитуд
                magnitude1  <= magnitude;
                magnitude2  <= magnitude1;
                magnitude3  <= magnitude2;
                magnitude4  <= magnitude3;
                
                -- 2. Дерево поиска максимума из 5 отсчетов (выполняется за 0 нс на кремнии)
                if unsigned(magnitude4) < unsigned(magnitude3) then max_pair1 := unsigned(magnitude3); else max_pair1 := unsigned(magnitude4); end if;
                if unsigned(magnitude2) < unsigned(magnitude1) then max_pair2 := unsigned(magnitude1); else max_pair2 := unsigned(magnitude2); end if;
                if max_pair1 < max_pair2 then max_stage2 := max_pair2; else max_stage2 := max_pair1; end if;
                if max_stage2 < unsigned(magnitude) then v_max := unsigned(magnitude); else v_max := max_stage2; end if;
                max_reg <= std_logic_vector(v_max);
                
                -- 3. Вычисление отклонения (corr) относительно лимита
                if v_max < unsigned(limit) then
                    v_corr := x"0000";
                else
                    v_corr := v_max - unsigned(limit);
                end if;
                corr <= std_logic_vector(v_corr);
                
                -- 4. Масштабирование (умножение на 2 с насыщением)
                if v_corr(15) = '1' then
                    v_corr1 := x"FFFF";
                else
                    v_corr1 := v_corr(14 downto 0) & '0';
                end if;
                corr1 <= std_logic_vector(v_corr1);

                -- 5. Формирование финального делителя denom
                if ("0" & v_corr1) + ("0" & unsigned(limit)) > 65535 then
                    denom <= x"FFFF";
                else
                    denom <= std_logic_vector(v_corr1 + unsigned(limit));
                end if;
                
                -- 6. ТОЧНАЯ ФАЗОВАЯ СИНХРОНИЗАЦИЯ С УЧЕТОМ ОКНА:
                -- Продвигаем аудиоданные по цепочке строго в темпе 16 кГц
                delay_out_0  <= s_axis_data_tdata;
                delay_out_1  <= delay_out_0;
                delay_out_2  <= delay_out_1;
                
                -- Берем отсчет аудио из центра окна (задержка ровно 2 аудио-периода)
                audio_sync   <= delay_out_2;
                
                -- Выставляем строб валидности строго на 1 такт aclk.
                -- На этом такте на шине denom уже лежит актуальное значение, 
                -- а на шине audio_sync - строго соответствующий ему отсчет звука!
                delay_tvalid <= '1';
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

