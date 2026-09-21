----------------------------------------------------------------------------------
-- Weaver SSB modulator
-- преобразование Уивера
-- на входе 24 бита 16 KSamples аудио
-- на выходе 47 бит IQ 16 KSamples
-- phase_accum текущее значение фазы чвтоты преобразования (default 1850 Hz)
-- По адресу 0x4 загрузка фильтра LPF (симметричный на 64 taps)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lim16_a2iq is
    Port (
        m_axis_iq_tdata     : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_iq_tvalid    : out STD_LOGIC;
        s_axis_audio_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
        s_axis_audio_tvalid : in  STD_LOGIC; 
        dds_cfg_data        : in  STD_LOGIC_VECTOR (31 downto 0);
        dds_cfg_tvalid      : in  STD_LOGIC;
        fir_reload_tdata    : in  STD_LOGIC_VECTOR (23 DOWNTO 0);
        fir_reload_tvalid   : in  STD_LOGIC;
        fir_reload_tlast    : in  STD_LOGIC;
        fir_config_tdata    : in  STD_LOGIC_VECTOR (7 DOWNTO 0);
        fir_config_tvalid   : in  STD_LOGIC;
        aclk                : in  STD_LOGIC 
    );
end lim16_a2iq;

architecture Behavioral of lim16_a2iq is

COMPONENT dds_16_16_ph IS
  PORT (
    aclk : IN STD_LOGIC;
    aclken : IN STD_LOGIC;
    s_axis_config_tvalid : IN STD_LOGIC;
    s_axis_config_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    m_axis_data_tvalid : OUT STD_LOGIC;
    m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT dds_16_16_ph;

COMPONENT cmpy_16_16
  PORT (
    aclk : IN STD_LOGIC;
    s_axis_a_tvalid : IN STD_LOGIC;
    s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_b_tvalid : IN STD_LOGIC;
    s_axis_b_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axis_ctrl_tvalid : IN STD_LOGIC;
    s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
  );
END COMPONENT cmpy_16_16;

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

    signal dds_config_tdata_reg  : STD_LOGIC_VECTOR(31 DOWNTO 0) := (others => '0');
    signal dds_config_tvalid_reg : STD_LOGIC := '0';
    signal dds_config_tvalid     : STD_LOGIC := '0';
    signal dds_tvalid            : STD_LOGIC;
    signal dds_tdata             : STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    -- Вход комплексного умножителя: аудио дублируется на I и Q (формат 48 бит под cmpy_16_24)
    signal mult_in_data          : STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    -- Выход умножителя / Вход FIR-фильтра
    signal firin_tdata           : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal firin_tvalid          : STD_LOGIC;
    
    -- Выход FIR-фильтра (79 downto 40 = Q, 39 downto 0 = I)
    signal firout_tdata          : STD_LOGIC_VECTOR(79 DOWNTO 0);
    signal firout_tvalid         : STD_LOGIC;
    
    -- Сигналы генератора псевдослучайной последовательности (LFSR)
    signal lfsr_reg              : STD_LOGIC_VECTOR(15 downto 0) := x"A5A5"; 
    signal ctrl_tdata            : STD_LOGIC_VECTOR(7 downto 0)  := (others => '0');

    -----------------------------------------------------------------
    -- Сигналы для конвейера Округления и Насыщения (Rounding & Saturation)
    -----------------------------------------------------------------
    -- Выделенные из FIR 40-битные знаковые каналы I и Q
    signal fir_i_raw, fir_q_raw     : signed(39 downto 0);
    
    -- Шаг 1 конвейера: Результат добавления округления (+0.5 младшего бита)
    -- Константа x"1000" (добавление 1 в 12-й бит для сохранения сетки 28 downto 13)
    constant C_ROUND_VAL : signed(39 downto 0) := x"0000008000"; -- единица в 15-м бите
    signal fir_i_round, fir_q_round : signed(39 downto 0) := (others => '0');
    signal fir_valid_pipe1          : std_logic := '0';
    
    -- Шаг 2 конвейера: Выходные 16-битные регистры после проверки на переполнение
    signal i_out_reg, q_out_reg     : std_logic_vector(15 downto 0) := (others => '0');
    signal fir_valid_pipe2          : std_logic := '0';

begin

    -- Дублируем 16-битный аудио-сигнал в I и Q каналы и расширяем каждый до 24 бит знаком (sign extension)
    -- В cmpy_16_24 данные упакованы как: [24 бита Q] & [24 бита I]
    mult_in_data(15 downto 0)  <= s_axis_audio_tdata; -- Канал I
    mult_in_data(31 downto 16) <= s_axis_audio_tdata; -- Канал Q
process(aclk)
begin
    if rising_edge(aclk) then
        -- Фиксация конфигурации DDS по tvalid
        if dds_cfg_tvalid = '1' then
           dds_config_tvalid_reg <= '1'; 
           dds_config_tdata_reg  <= dds_cfg_data;
        end if;
        
        -- Сброс регистра валидности после применения настроек при наличии аудиоданных
        if s_axis_audio_tvalid = '1' and dds_config_tvalid_reg = '1' then
            dds_config_tvalid_reg <= '0';
        end if;
        
        -- Классический полином LFSR x^16 + x^14 + x^13 + x^11 + 1
        lfsr_reg <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);
    end if;
end process;

    -- Назначение управляющего бита дизеринга для комплексного умножителя
    ctrl_tdata(0)          <= lfsr_reg(0); 
    ctrl_tdata(7 downto 1) <= (others => '0');
    
    -- Выдача строба конфигурации строго во время валидности аудио-семпла
    dds_config_tvalid <= dds_config_tvalid_reg when s_axis_audio_tvalid = '1' else '0';
    
    -- 1. Цифровой синтезатор частоты (DDS)
    dds_0 : dds_16_16_ph
    PORT MAP (
        aclk                 => aclk,
        aclken               => s_axis_audio_tvalid,
        s_axis_config_tvalid => dds_config_tvalid,
        s_axis_config_tdata  => dds_config_tdata_reg,
        m_axis_data_tvalid   => dds_tvalid,
        m_axis_data_tdata    => dds_tdata
    );

    -- 2. Комплексный умножитель (Смещение частоты звука)
    mult_0 : cmpy_16_16
    PORT MAP (
        aclk               => aclk,
        s_axis_a_tvalid    => s_axis_audio_tvalid,
        s_axis_a_tdata     => mult_in_data,
        s_axis_b_tvalid    => dds_tvalid,
        s_axis_b_tdata     => dds_tdata,
        s_axis_ctrl_tvalid => '1',
        s_axis_ctrl_tdata  => ctrl_tdata,
        m_axis_dout_tvalid => firin_tvalid,
        m_axis_dout_tdata  => firin_tdata
    );

    -- 3. Фильтр нижних частот Уивера (Симметричный LPF)
    fir_0 : lim16_lpf_fir
    PORT MAP (
        aclk                            => aclk,
        s_axis_data_tvalid              => firin_tvalid,
        s_axis_data_tready              => open,
        s_axis_data_tdata               => firin_tdata,
        s_axis_config_tvalid            => fir_config_tvalid,
        s_axis_config_tready            => open,
        s_axis_config_tdata             => fir_config_tdata,
        s_axis_reload_tvalid            => fir_reload_tvalid,
        s_axis_reload_tready            => open,
        s_axis_reload_tlast             => fir_reload_tlast,
        s_axis_reload_tdata             => fir_reload_tdata,
        m_axis_data_tvalid              => firout_tvalid,
        m_axis_data_tdata               => firout_tdata,
        event_s_reload_tlast_missing    => open,
        event_s_reload_tlast_unexpected => open
    );

    -- Разделяем шину фильтра на индивидуальные компоненты I и Q
    fir_q_raw <= signed(firout_tdata(79 downto 40));
    fir_i_raw <= signed(firout_tdata(39 downto 0));

    -- Двухстадийный процесс конвейерной обработки сигналов IQ
    process(aclk)
    begin
        if rising_edge(aclk) then
            -----------------------------------------------------------------
            -- СТАДИЯ 1: Математическое округление (Rounding)
            -- Прибавляем единицу в 12-й бит для округления сетки (28 downto 13)
            -----------------------------------------------------------------
            fir_i_round     <= fir_i_raw + C_ROUND_VAL;
            fir_q_round     <= fir_q_raw + C_ROUND_VAL;
            fir_valid_pipe1 <= firout_tvalid;

            -----------------------------------------------------------------
            -- СТАДИЯ 2: Сатурация (Saturation) и ограничение до 16 бит
            -----------------------------------------------------------------
            fir_valid_pipe2 <= fir_valid_pipe1;

            -- Обработка канала I (Синхронная проверка переполнения)
            if fir_i_round(39 downto 31) = "111111111" or fir_i_round(39 downto 31) = "000000000" then
                i_out_reg <= std_logic_vector(fir_i_round(31 downto 16));
            elsif fir_i_round(39) = '0' then
                i_out_reg <= x"7FFF"; -- Положительное ограничение
            else
                i_out_reg <= x"8000"; -- Отрицательное ограничение
            end if;

            -- Обработка канала Q (Синхронная проверка переполнения)
            if fir_q_round(39 downto 31) = "111111111" or fir_q_round(39 downto 31) = "000000000" then
                q_out_reg <= std_logic_vector(fir_q_round(31 downto 16));
            elsif fir_q_round(39) = '0' then
                q_out_reg <= x"7FFF"; -- Положительное ограничение
            else
                q_out_reg <= x"8000"; -- Отрицательное ограничение
            end if;
            
        end if;
    end process;

    -----------------------------------------------------------------
    -- Назначение выходных портов модуля
    -----------------------------------------------------------------
    -- Упаковываем каналы в формат AXIS: [16 бит Q] & [16 бит I]
    m_axis_iq_tdata  <= q_out_reg & i_out_reg;
    m_axis_iq_tvalid <= fir_valid_pipe2;

end Behavioral;

