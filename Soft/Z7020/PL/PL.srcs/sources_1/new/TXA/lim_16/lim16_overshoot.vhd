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
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim16_lpf_fir;

    component lim16_div is
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component lim16_div;
    
    signal delay_out_0, delay_out_1, audio_sync : std_logic_vector(31 downto 0) := (others => '0');        
    signal cordic_in       : std_logic_vector(31 downto 0);
    signal cordic_out      : std_logic_vector(31 downto 0);
    signal cordic_tvalid   : std_logic;
    signal magnitude       : std_logic_vector(15 downto 0) := (others => '0');
    signal magnitude1      : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude2      : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude3      : std_logic_vector(15 downto 0) := (others => '0');  
    signal magnitude4      : std_logic_vector(15 downto 0) := (others => '0');  
    signal max_reg         : std_logic_vector(15 downto 0) := (others => '0');
    signal corr            : std_logic_vector(15 downto 0) := x"0000";
    signal corr1           : std_logic_vector(15 downto 0) := x"0000";
    signal denom           : std_logic_vector(15 downto 0) := x"0001";
    signal divout_0        : std_logic_vector(23 downto 0); 
    signal divout_1        : std_logic_vector(23 downto 0); 
    signal divout_valid_0  : std_logic;
    signal divout_valid_1  : std_logic;
    signal div_over_0      : std_logic;
    signal div_over_1      : std_logic;
    signal fir_in_tdata    : std_logic_vector(31 downto 0);
    signal fir_in_tvalid   : std_logic;
    
    -- ИСПРАВЛЕНО: Выход FIR-фильтра должен быть строго 80 бит (79 downto 0)
    signal fir_out_tdata   : std_logic_vector(79 downto 0);
    signal fir_out_tvalid  : std_logic;
    signal delay_tvalid    : std_logic := '0';
    
        -- Регистры для округления результатов деления (24 бита)
    signal divout_0_round     : signed(23 downto 0) := (others => '0');
    signal divout_1_round     : signed(23 downto 0) := (others => '0');
    signal divout_valid_pipe  : std_logic := '0';
    signal div_over_pipe      : std_logic := '0';
    
    -----------------------------------------------------------------
    -- Сигналы для конвейера Округления и Насыщения (Rounding & Saturation)
    -----------------------------------------------------------------
    -- Выделенные из FIR 40-битные знаковые каналы А и Б
    signal fir_a_raw, fir_b_raw     : signed(39 downto 0);
    
    constant GAIN_SHIFT : integer := 14;     
    constant C_ROUND_VAL : signed(39 downto 0) := x"0000000200";
    signal fir_a_round, fir_b_round : signed(39 downto 0) := (others => '0');
    signal fir_valid_pipe1          : std_logic := '0';
    
    -- СТАДИЯ 2: Выходные регистры каналов после Сатурации
    signal ch_a_16_reg, ch_b_16_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal out_valid_reg            : std_logic := '0';
    signal out_over_reg             : std_logic := '0';

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
    
process(aclk)
begin
    if rising_edge(aclk) then  
        if cordic_tvalid = '1' then
            magnitude1  <= magnitude;
            magnitude2  <= magnitude1;
            magnitude3  <= magnitude2;
            magnitude4  <= magnitude3;
            delay_out_0 <= s_axis_data_tdata;
            delay_out_1 <= delay_out_0;
        end if;    
    end if;
end process;

process(aclk)
    -- Переменные для мгновенного расчета дерева максимумов без задержек на такты
    variable max_pair1  : std_logic_vector(15 downto 0);
    variable max_pair2  : std_logic_vector(15 downto 0);
    variable max_stage2 : std_logic_vector(15 downto 0);
    variable v_max      : std_logic_vector(15 downto 0);
    variable v_corr     : std_logic_vector(15 downto 0);
    variable v_corr1    : std_logic_vector(15 downto 0);
begin
    if rising_edge(aclk) then
        delay_tvalid <= '0';
        
        if cordic_tvalid = '1' then
            -- Шаг 1 дерева: Сравниваем пары параллельно
            if unsigned(magnitude4) < unsigned(magnitude3) then max_pair1 := magnitude3; else max_pair1 := magnitude4; end if;
            if unsigned(magnitude2) < unsigned(magnitude1) then max_pair2 := magnitude1; else max_pair2 := magnitude2; end if;
            
            -- Шаг 2 дерева: Находим максимум из пар
            if unsigned(max_pair1) < unsigned(max_pair2) then max_stage2 := max_pair2; else max_stage2 := max_pair1; end if;
            
            -- Шаг 3: Находим финальный максимум с учетом текущего отсчета
            if unsigned(max_stage2) < unsigned(magnitude) then v_max := magnitude; else v_max := max_stage2; end if;
            max_reg <= v_max;
            
            -- Шаг 4: Вычисление отклонения (corr) относительно лимита
            if unsigned(v_max) < unsigned(limit) then
                v_corr := x"0000";
            else
                v_corr := std_logic_vector(unsigned(v_max) - unsigned(limit));
            end if;
            corr <= v_corr;
            
            -- Шаг 5: Конвейерное масштабирование corr1 (умножение на 2 с насыщением)
            if v_corr(15) = '1' then
                v_corr1 := x"FFFF";
            else
                v_corr1 := v_corr(14 downto 0) & '0';
            end if;
            corr1 <= v_corr1;

            -- Шаг 6: Формирование финального делителя denom
            if ("0" & unsigned(v_corr1)) + ("0" & unsigned(limit)) > 65535 then
                denom <= x"FFFF";
            else
                denom <= std_logic_vector(unsigned(v_corr1) + unsigned(limit));
            end if;
            
            audio_sync   <= delay_out_1;
            delay_tvalid <= '1';
        end if;
    end if;
end process;
    
div_0 : lim16_div
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
    
process(aclk)
begin
    if rising_edge(aclk) then
        -- Конвейерное округление: прибавляем '1' в 7-й бит (вес 128)
        -- Операция автоматически оптимизируется синтезатором внутри FPGA
        if divout_valid_0 = '1' then
            divout_0_round <= signed(divout_0) + to_signed(128, 24);
            divout_1_round <= signed(divout_1) + to_signed(128, 24);
        end if;
        
        -- Продвигаем валид и флаг переполнения по конвейеру на 1 такт
        divout_valid_pipe <= divout_valid_0;
        div_over_pipe     <= div_over_0 or div_over_1;
    end if;
end process;

    fir_in_tdata  <= std_logic_vector(divout_0_round(23 downto 8)) & std_logic_vector(divout_1_round(23 downto 8));
    fir_in_tvalid <= divout_valid_pipe;
    over(0)       <= div_over_pipe;
     
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
    -- Разделяем выход шины фильтра на индивидуальные каналы А и Б по 40 бит
    fir_a_raw <= signed(fir_out_tdata(79 downto 40));
    fir_b_raw <= signed(fir_out_tdata(39 downto 0));

    -- Двухстадийный процесс конвейерной обработки выходных сигналов IQ
    process(aclk)
        -- Переменные-флаги переполнения знакового расширения
        variable overflow_a : boolean;
        variable overflow_b : boolean;
    begin
        if rising_edge(aclk) then
            -----------------------------------------------------------------
            -- СТАДИЯ 1: Конвейерное округление (Rounding)
            -- Прибавляем единицу в вес 8-го бита (C_ROUND_VAL = x"1000" в терминах 40 бит)
            -----------------------------------------------------------------
            fir_a_round     <= fir_a_raw + C_ROUND_VAL;
            fir_b_round     <= fir_b_raw + C_ROUND_VAL;
            fir_valid_pipe1 <= fir_out_tvalid;

            -----------------------------------------------------------------
            -- СТАДИЯ 2: Сатурация (Saturation) и проверка знакового расширения
            -----------------------------------------------------------------
            out_valid_reg <= fir_valid_pipe1;

            if fir_valid_pipe1 = '1' then
                -- По умолчанию считаем, что переполнения нет
                overflow_a := false;
                overflow_b := false;
                out_over_reg <= '0';

                -- ИСПРАВЛЕННЫЙ ЦИКЛ КАНАЛА А: 
                -- При GAIN_SHIFT = 7 полезный срез равен (32 downto 17). Значит, 32-й бит - знаковый.
                -- Проверяем биты расширения строго ВЫШЕ старшего полезного бита (от 39 до 33)
                for i in 39 downto (39 - GAIN_SHIFT + 1) loop
                    if fir_a_round(i) /= fir_a_round(39) then
                        overflow_a := true;
                    end if;
                end loop;

                if overflow_a then
                    out_over_reg <= '1';
                    if fir_a_round(39) = '0' then
                        ch_a_16_reg <= x"7FFF"; -- Положительное насыщение
                    else
                        ch_a_16_reg <= x"8000"; -- Отрицательное насыщение
                    end if;
                else
                    -- Ошибки нет, забираем 16 бит округленной полезной части со сдвигом усиления
                    ch_a_16_reg <= std_logic_vector(fir_a_round((39 - GAIN_SHIFT) downto (24 - GAIN_SHIFT)));
                end if;

                -- ИСПРАВЛЕННЫЙ ЦИКЛ КАНАЛА Б:
                -- Проверяем биты знакового расширения строго выше полезного 32-го бита (от 39 до 33)
                for i in 39 downto (39 - GAIN_SHIFT + 1) loop
                    if fir_b_round(i) /= fir_b_round(39) then
                        overflow_b := true;
                    end if;
                end loop;

                if overflow_b then
                    out_over_reg <= '1';
                    if fir_b_round(39) = '0' then
                        ch_b_16_reg <= x"7FFF"; -- Положительное насыщение
                    else
                        ch_b_16_reg <= x"8000"; -- Отрицательное насыщение
                    end if;
                else
                    -- Ошибки нет, забираем 16 бит округленной полезной части со сдвигом усиления
                    ch_b_16_reg <= std_logic_vector(fir_b_round((39 - GAIN_SHIFT) downto (24 - GAIN_SHIFT)));
                end if;
            else
                out_over_reg <= '0'; -- Сбрасываем флаг, если данные невалидны
            end if;
        end if;
    end process;

    -----------------------------------------------------------------
    -- Назначение выходных портов модуля из стабильных регистров
    -----------------------------------------------------------------
    -- Данные и валид переключаются строго синхронно в одной старт-стопной точке конвейера Stage 2
    m_axis_data_tdata  <= ch_a_16_reg & ch_b_16_reg;
    m_axis_data_tvalid <= out_valid_reg;
    over(1)            <= out_over_reg;

end Behavioral;

