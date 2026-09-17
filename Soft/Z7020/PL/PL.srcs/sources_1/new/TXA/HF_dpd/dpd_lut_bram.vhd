-- Модуль: dpd_lut_bram
-- Назначение: LUT на Block RAM для DPD-ядра (real + imag), с инициализацией
--             из файла и поддержкой одновременного чтения и записи.
--
-- Реализация: Xilinx XPM xpm_memory_sdpram (Simple Dual Port BRAM).
--             Один BRAM на компоненту (real/imag) на одну ветвь памяти.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library xpm;
use xpm.vcomponents.all;

entity dpd_lut_bram is
    Generic (
        LUT_ADDR_WIDTH  : integer := 8;    -- 2^8 = 256 адресов
        COEFF_WIDTH     : integer := 16;   -- разрядность коэффициента
        INIT_FILE_REAL  : string  := "lut_real.mem";
        INIT_FILE_IMAG  : string  := "lut_imag.mem";
        MEMORY_DEPTH    : integer := 1     -- сколько BRAM-ветвей
    );
    Port (
        -- Системные
        aclk            : in  std_logic;
        aresetn         : in  std_logic;

        -- Порт чтения (для прямого тракта)
        rd_addr         : in  std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
        rd_en           : in  std_logic;
        rd_real         : out std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        rd_imag         : out std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);

        -- Порт записи (для адаптации)
        wr_addr         : in  std_logic_vector(LUT_ADDR_WIDTH-1 downto 0);
        wr_real         : in  std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        wr_imag         : in  std_logic_vector(MEMORY_DEPTH*COEFF_WIDTH-1 downto 0);
        wr_en           : in  std_logic_vector(MEMORY_DEPTH-1 downto 0)
    );
end entity dpd_lut_bram;

architecture rtl of dpd_lut_bram is

    -- Разбиваем входные шины на отдельные слова
    type word_array_t is array (0 to MEMORY_DEPTH-1) of
        std_logic_vector(COEFF_WIDTH-1 downto 0);

    signal wr_real_words : word_array_t;
    signal wr_imag_words : word_array_t;

    -- Выходы BRAM (по одному на ветвь)
    signal rd_real_words : word_array_t;
    signal rd_imag_words : word_array_t;

    -- Тип для корректного формирования шины разрешения записи (XPM требует вектор)
    type wea_array_t is array (0 to MEMORY_DEPTH-1) of std_logic_vector(0 downto 0);
    signal wea_real_bit : wea_array_t;
    signal wea_imag_bit : wea_array_t;

begin

    ----------------------------------------------------------------------------
    -- Распаковка входных шин записи в отдельные слова и подготовка масок записи
    ----------------------------------------------------------------------------
    gen_unpack : for m in 0 to MEMORY_DEPTH-1 generate
        wr_real_words(m) <= wr_real((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH);
        wr_imag_words(m) <= wr_imag((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH);
        
        -- Явно приравниваем бит разрешения к вектору, убирая WARNING 10-3093
        wea_real_bit(m)(0) <= wr_en(m);
        wea_imag_bit(m)(0) <= wr_en(m);
    end generate;

    ----------------------------------------------------------------------------
    -- Упаковка выходов BRAM в одну шину чтения
    ----------------------------------------------------------------------------
    gen_pack : for m in 0 to MEMORY_DEPTH-1 generate
        rd_real((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH) <= rd_real_words(m);
        rd_imag((m+1)*COEFF_WIDTH-1 downto m*COEFF_WIDTH) <= rd_imag_words(m);
    end generate;

    ----------------------------------------------------------------------------
    -- BRAM-ветви для REAL
    ----------------------------------------------------------------------------
    gen_bram_real : for m in 0 to MEMORY_DEPTH-1 generate

        xpm_memory_sdpram_inst : xpm_memory_sdpram
        generic map (
            -- Общие параметры
            MEMORY_SIZE         => (2**LUT_ADDR_WIDTH) * COEFF_WIDTH,
            MEMORY_PRIMITIVE    => "block",
            CLOCKING_MODE       => "common_clock",
            ECC_MODE            => "no_ecc",

            -- Инициализация
            MEMORY_INIT_FILE    => INIT_FILE_REAL,
            MEMORY_INIT_PARAM   => "",   
            USE_MEM_INIT        => 1,

            -- Порт записи (A)
            WRITE_DATA_WIDTH_A  => COEFF_WIDTH,
            BYTE_WRITE_WIDTH_A  => COEFF_WIDTH, -- Запись целиком всего слова (16 бит)
            ADDR_WIDTH_A        => LUT_ADDR_WIDTH,

            -- Порт чтения (B)
            READ_DATA_WIDTH_B   => COEFF_WIDTH,
            ADDR_WIDTH_B        => LUT_ADDR_WIDTH,
            READ_RESET_VALUE_B  => "0",
            READ_LATENCY_B      => 1,
            WRITE_MODE_B        => "read_first", -- Исправлено: режим ставится на порт B

            -- Служебные
            WAKEUP_TIME         => "0",
            AUTO_SLEEP_TIME     => 0,
            USE_EMBEDDED_CONSTRAINT => 0,
            MEMORY_OPTIMIZATION => "true",
            CASCADE_HEIGHT      => 0,
            SIM_ASSERT_CHK      => 0
        )
        port map (
            -- Порт записи (A)
            clka                => aclk,
            ena                 => '1',
            wea                 => wea_real_bit(m), -- Исправлено: статический сигнал без (others)
            addra               => wr_addr,
            dina                => wr_real_words(m),

            -- Порт чтения (B)
            clkb                => aclk,
            enb                 => rd_en,
            addrb               => rd_addr,
            doutb               => rd_real_words(m),
            regceb              => '1',
            rstb                => '0',

            -- Служебные (Исправлены имена портов по спецификации XPM VHDL)
            injectdbiterra      => '0', 
            injectsbiterra      => '0',
            sleep               => '0', -- Исправлено: обязательный порт теперь подключен
            dbiterrb            => open,
            sbiterrb            => open
        );

    end generate gen_bram_real;

    ----------------------------------------------------------------------------
    -- BRAM-ветви для IMAG
    ----------------------------------------------------------------------------
    gen_bram_imag : for m in 0 to MEMORY_DEPTH-1 generate

        xpm_memory_sdpram_inst : xpm_memory_sdpram
        generic map (
            MEMORY_SIZE         => (2**LUT_ADDR_WIDTH) * COEFF_WIDTH,
            MEMORY_PRIMITIVE    => "block",
            CLOCKING_MODE       => "common_clock",
            ECC_MODE            => "no_ecc",

            MEMORY_INIT_FILE    => INIT_FILE_IMAG,
            MEMORY_INIT_PARAM   => "",
            USE_MEM_INIT        => 1,

            WRITE_DATA_WIDTH_A  => COEFF_WIDTH,
            BYTE_WRITE_WIDTH_A  => COEFF_WIDTH,
            ADDR_WIDTH_A        => LUT_ADDR_WIDTH,

            READ_DATA_WIDTH_B   => COEFF_WIDTH,
            ADDR_WIDTH_B        => LUT_ADDR_WIDTH,
            READ_RESET_VALUE_B  => "0",
            READ_LATENCY_B      => 1,
            WRITE_MODE_B        => "read_first",

            WAKEUP_TIME         => "0",
            AUTO_SLEEP_TIME     => 0,
            USE_EMBEDDED_CONSTRAINT => 0,
            MEMORY_OPTIMIZATION => "true",
            CASCADE_HEIGHT      => 0,
            SIM_ASSERT_CHK      => 0
        )
        port map (
            clka                => aclk,
            ena                 => '1',
            wea                 => wea_imag_bit(m),
            addra               => wr_addr,
            dina                => wr_imag_words(m),

            clkb                => aclk,
            enb                 => rd_en,
            addrb               => rd_addr,
            doutb               => rd_imag_words(m),
            regceb              => '1',
            rstb                => '0',

            injectdbiterra      => '0',
            injectsbiterra      => '0',
            sleep               => '0', 
            dbiterrb            => open,
            sbiterrb            => open
        );

    end generate gen_bram_imag;

end architecture rtl;
