library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gain16_24_lim is
    generic (
        G_DATA_IN_WIDTH  : integer := 24; -- Разрядность входного сигнала
        G_GAIN_WIDTH     : integer := 16; -- Разрядность коэффициента усиления
        G_DATA_OUT_WIDTH : integer := 16; -- Разрядность выходного сигнала
        G_SHIFT_BITS     : integer := 24  -- Сколько бит отбрасываем (дробная часть КУ)
    );
    port (
        aclk              : in  std_logic;
        multin_tdata      : in  std_logic_vector(G_DATA_IN_WIDTH-1 downto 0);
        multin_tvalid     : in  std_logic;
        gain              : in  std_logic_vector(G_GAIN_WIDTH-1 downto 0);
        multout_tdata     : out std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0);
        multout_tvalid    : out std_logic;
        over              : out std_logic_vector(0 downto 0)
    );
end entity gain16_24_lim;

architecture rtl of gain16_24_lim is

    -- Константа для округления (добавляем '1' в старший отбрасываемый бит)
    -- Для G_SHIFT_BITS = 13 это будет 2**12 = 4096 (x"1000")
    constant C_ROUND_VAL     : signed(G_DATA_IN_WIDTH + G_GAIN_WIDTH - 1 downto 0) := 
                               to_signed(2**(G_SHIFT_BITS - 1), G_DATA_IN_WIDTH + G_GAIN_WIDTH);
    
    -- Полная разрядность умножения (24 + 16 = 40 бит)
    signal multout_sig       : signed(G_DATA_IN_WIDTH + G_GAIN_WIDTH - 1 downto 0) := (others => '0');
    signal multout_tvalid_d, multout_tvalid_r  : std_logic := '0';
    signal over_r            : std_logic := '0';
    signal multout_tdata_r   : std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0) := (others => '0');

    -- Индексы для вырезания полезных данных на выходе
    constant C_BIT_LOW       : integer := G_SHIFT_BITS; -- 13
    constant C_BIT_HIGH      : integer := G_SHIFT_BITS + G_DATA_OUT_WIDTH - 1; -- 13 + 16 - 1 = 28
    
    -- Граничные значения для насыщения (максимум и минимум для 16 бит)
    constant C_MAX_POS       : std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0) := (G_DATA_OUT_WIDTH-1 => '0', others => '1'); -- x"7FFF"
    constant C_MIN_NEG       : std_logic_vector(G_DATA_OUT_WIDTH-1 downto 0) := (G_DATA_OUT_WIDTH-1 => '1', others => '0'); -- x"8000"

begin

    process(aclk)
    begin
        if rising_edge(aclk) then  
            -- Шаг 1: Конвейерное умножение с автоматическим округлением (внутри DSP блока)
            multout_sig      <= resize(signed(multin_tdata) * signed(gain) + C_ROUND_VAL, multout_sig'length);       
            multout_tvalid_d <= multin_tvalid;
            
            -- Шаг 2: Вторая стадия конвейера - задержка валида
            multout_tvalid_r    <= multout_tvalid_d;

            -- Шаг 3: Проверка знакового расширения и сатурация (насыщение)
            -- Проверяем биты с 39 по 28. Если они все одинаковые, то переполнения нет.
            if multout_sig(multout_sig'high downto C_BIT_HIGH) = (multout_sig'high downto C_BIT_HIGH => '1') or 
               multout_sig(multout_sig'high downto C_BIT_HIGH) = (multout_sig'high downto C_BIT_HIGH => '0') then
               
                over_r  <= '0';
                -- Вырезаем округленные 16 бит (28 downt 13)
                multout_tdata_r <= std_logic_vector(multout_sig(C_BIT_HIGH downto C_BIT_LOW));
                
            -- Если старший знаковый бит (39-й) равен '0', то переполнение вверх
            elsif multout_sig(multout_sig'high) = '0' then 
                over_r  <= '1'; 
                multout_tdata_r <= C_MAX_POS; -- +32767
                
            -- Иначе переполнение вниз
            else
                over_r  <= '1'; 
                multout_tdata_r <= C_MIN_NEG; -- -32768
            end if;    
        end if;
    end process;
    
    multout_tdata <= multout_tdata_r;
    multout_tvalid <= multout_tvalid_r; 
    over(0) <= over_r;

end architecture rtl;
