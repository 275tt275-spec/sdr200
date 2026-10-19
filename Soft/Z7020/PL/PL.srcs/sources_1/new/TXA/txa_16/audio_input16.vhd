library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity audio_input16 is
     Port ( 
       aclk : in  STD_LOGIC;     
       s_axis_tdata : in STD_LOGIC_VECTOR (23 downto 0);
       s_axis_tvalid : in STD_LOGIC;
       m_axis_tdata : out STD_LOGIC_VECTOR (15 downto 0);
       m_axis_tvalid : out STD_LOGIC;
       s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
       s_axis_cfg_tdest : in STD_LOGIC_VECTOR (0 downto 0);
       s_axis_cfg_tvalid : in STD_LOGIC;
       overflow : out STD_LOGIC_VECTOR (1 downto 0)
    );
end audio_input16;

architecture Behavioral of audio_input16 is

component fir_audio_16 IS
    port (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    end component fir_audio_16;
    
    -- Внутренние сигналы
    signal gain_correct      : std_logic_vector(3 downto 0) := x"6";
    signal fir_out_tdata     : std_logic_vector(47 downto 0);
    signal fir_out_tvalid    : std_logic;
    
    -- Выходные регистры конвейера
    signal out_rounded       : signed(15 downto 0) := (others => '0');
    signal m_axis_tvalid_reg : std_logic := '0';
    signal gain_overflow_reg : std_logic := '0';
    signal audio_overflow_reg : std_logic := '0';

begin

    -- Процесс фиксации настроек усиления из AXIS Config
    proc_config : process(aclk)
    begin
        if rising_edge(aclk) then
            -- 1. Приоритет отдается конфигурации извне
            if s_axis_cfg_tvalid = '1' then
                if s_axis_cfg_tdest = "1" then
                    gain_correct <= s_axis_cfg_tdata(3 downto 0);
                end if;    
            end if;
        end if;
    end process proc_config;

audio_0 : fir_audio_16
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => s_axis_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => s_axis_tdata,
        m_axis_data_tvalid => fir_out_tvalid,
        m_axis_data_tdata => fir_out_tdata
    );
    
 -- Процесс коррекции усиления, округления результата и защиты от насыщения
 proc_dsp : process(aclk)
        variable shift_val : integer range 0 to 15;
        -- Расширяем разрядность сетки до 64 бит (48 бит FIR + 15 бит макс. сдвига + 1 бит под знак)
        variable extended  : signed(63 downto 0); 
        variable shifted   : signed(63 downto 0);
        variable rounded   : signed(63 downto 0);
        constant ROUND_VAL : signed(63 downto 0) := shift_left(to_signed(1, 64), 31);
    begin
        if rising_edge(aclk) then
            m_axis_tvalid_reg <= fir_out_tvalid;

            case gain_correct is
                when "0001"   => shift_val := 1;
                when "0010"   => shift_val := 2;
                when "0011"   => shift_val := 3;
                when "0100"   => shift_val := 4;
                when "0101"   => shift_val := 5;
                when "0110"   => shift_val := 6;
                when "0111"   => shift_val := 7;
                when "1000"   => shift_val := 8;
                when "1001"   => shift_val := 9;
                when "1010"   => shift_val := 10;
                when "1011"   => shift_val := 11;
                when "1100"   => shift_val := 12;
                when "1101"   => shift_val := 13;
                when "1110"   => shift_val := 14;
                when "1111"   => shift_val := 15;
                when others   => shift_val := 0;
            end case;

            -- 1. Знаковое расширение 48-битного выхода FIR до 64 бит
            extended := resize(signed(fir_out_tdata), 64);
            
            -- 2. Арифметический сдвиг влево (усиление сигнала)
            shifted  := shift_left(extended, shift_val);
            
            -- 3. Строгое Symmetric Rounding to Infinity для отбрасываемых 32 бит:
            -- Половина веса - это 2^31 = 2147483648 (в двоичном виде: "1" и 31 ноль)
            if (shifted(63) = '1' and shifted(31 downto 0) = "10000000000000000000000000000000") then
                rounded := shifted; -- Для отрицательной середины шкалы оставляем усечение (-inf)
            else
                rounded := shifted + ROUND_VAL; -- Для остальных случаев прибавляем половину веса
            end if;

            -- 4. Контроль насыщения и усечение до целевых 16 бит (разряды 47 downto 32).
            -- Проверяем знаковые разряды выше полезного сигнала (биты 62 downto 48).
            if rounded(63) = '0' then
                if rounded(62 downto 48) /= (62 downto 48 => '0') then
                    out_rounded       <= x"7FFF"; -- Положительное переполнение
                    gain_overflow_reg <= '1';
                else
                    out_rounded       <= rounded(47 downto 32);
                    gain_overflow_reg <= '0';
                end if;
            else
                if rounded(62 downto 48) /= (62 downto 48 => '1') then
                    out_rounded       <= x"8000"; -- Отрицательное переполнение
                    gain_overflow_reg <= '1';
                else
                    out_rounded       <= rounded(47 downto 32);
                    gain_overflow_reg <= '0';
                end if;
            end if;
        end if;
    end process proc_dsp;

    -- Назначение выходных портов
    m_axis_tdata  <= std_logic_vector(out_rounded);
    m_axis_tvalid <= m_axis_tvalid_reg;
    overflow      <= gain_overflow_reg & audio_overflow_reg;
    
end Behavioral;
