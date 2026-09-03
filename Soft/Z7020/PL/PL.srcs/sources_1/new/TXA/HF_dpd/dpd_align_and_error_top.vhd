library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dpd_align_and_error_top is
    Generic (
        DATA_WIDTH   : integer := 16;
        ADDR_WIDTH   : integer := 8;    -- 2^8 = 256 тактов максимальной задержки для RAM
        ALPHA_SHIFT  : integer := 8     -- Коэффициент сглаживания фильтра (1/256)
    );
    Port (
        -- Системные сигналы
        aclk                 : in  std_logic;
        aresetn              : in  std_logic;
        
        -- Интерфейс конфигурации
        cfg_delay_ticks      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        cfg_train_en         : in  std_logic;
        cfg_hold_coeffs      : in  std_logic;
        
        -- Входной опорный сигнал (Прямой тракт TX)
        s_axis_ref_tdata_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_ref_tdata_q   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        s_axis_ref_tvalid    : in  std_logic;
        
        -- Входной сигнал обратной связи (Тракт приема FB от АЦП)
        s_axis_fb_tdata_i    : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_tdata_q    : in  signed(DATA_WIDTH-1 downto 0);
        s_axis_fb_tvalid     : in  std_logic;
        
        -- Выход вычисленной и сглаженной ошибки для адаптации LUT
        m_axis_err_i         : out signed(31 downto 0);
        m_axis_err_q         : out signed(31 downto 0);
        m_axis_err_valid     : out std_logic
    );
end dpd_align_and_error_top;

architecture Structural of dpd_align_and_error_top is

    -- Декларация компонента линии задержки (Time Alignment)
    component time_alignment is
        generic (
            DATA_WIDTH  : integer := 16;
            ADDR_WIDTH  : integer := 8
        );
        port (
            aclk                 : in  std_logic;
            aresetn              : in  std_logic;
            cfg_delay_ticks      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            s_axis_ref_tdata_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            s_axis_ref_tdata_q   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            s_axis_ref_tvalid    : in  std_logic;
            m_axis_align_tdata_i : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m_axis_align_tdata_q : out std_logic_vector(DATA_WIDTH-1 downto 0);
            m_axis_align_tvalid  : out std_logic
        );
    end component;

    -- Декларация компонента вычисления ошибки (Error Calculator)
    component dpd_error_calc is
        generic (
            DATA_WIDTH  : integer := 16;
            ALPHA_SHIFT : integer := 8
        );
        port (
            aclk               : in  std_logic;
            aresetn            : in  std_logic;
            s_axis_ref_i       : in  signed(DATA_WIDTH-1 downto 0);
            s_axis_ref_q       : in  signed(DATA_WIDTH-1 downto 0);
            s_axis_ref_valid   : in  std_logic;
            s_axis_fb_i        : in  signed(DATA_WIDTH-1 downto 0);
            s_axis_fb_q        : in  signed(DATA_WIDTH-1 downto 0);
            s_axis_fb_valid    : in  std_logic;
            cfg_train_en       : in  std_logic;
            cfg_hold_coeffs    : in  std_logic;
            m_axis_err_i       : out signed(31 downto 0);
            m_axis_err_q       : out signed(31 downto 0);
            m_axis_err_valid   : out std_logic
        );
    end component;

    -- Внутренние сигналы (связующие шины между двумя модулями)
    signal delayed_ref_i       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal delayed_ref_q       : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal delayed_ref_valid   : std_logic;

    signal delayed_ref_i_sgn   : signed(DATA_WIDTH-1 downto 0);
    signal delayed_ref_q_sgn   : signed(DATA_WIDTH-1 downto 0);

begin

    -- Преобразование типов std_logic_vector в signed для корректной математики
    delayed_ref_i_sgn <= signed(delayed_ref_i);
    delayed_ref_q_sgn <= signed(delayed_ref_q);

    -- Инстанцирование 1: Линия задержки опорного сигнала TX
    u_time_alignment : time_alignment
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            ADDR_WIDTH => ADDR_WIDTH
        )
        port map (
            aclk                 => aclk,
            aresetn              => aresetn,
            cfg_delay_ticks      => cfg_delay_ticks,
            s_axis_ref_tdata_i   => s_axis_ref_tdata_i,
            s_axis_ref_tdata_q   => s_axis_ref_tdata_q,
            s_axis_ref_tvalid    => s_axis_ref_tvalid,
            m_axis_align_tdata_i => delayed_ref_i,
            m_axis_align_tdata_q => delayed_ref_q,
            m_axis_align_tvalid  => delayed_ref_valid
        );

    -- Инстанцирование 2: Вычислитель сглаженной ошибки DPD
    u_dpd_error_calc : dpd_error_calc
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            ALPHA_SHIFT => ALPHA_SHIFT
        )
        port map (
            aclk               => aclk,
            aresetn            => aresetn,
            s_axis_ref_i       => delayed_ref_i_sgn,
            s_axis_ref_q       => delayed_ref_q_sgn,
            s_axis_ref_valid   => delayed_ref_valid,
            s_axis_fb_i        => s_axis_fb_tdata_i,
            s_axis_fb_q        => s_axis_fb_tdata_q,
            s_axis_fb_valid    => s_axis_fb_tvalid,
            cfg_train_en       => cfg_train_en,
            cfg_hold_coeffs    => cfg_hold_coeffs,
            m_axis_err_i       => m_axis_err_i,
            m_axis_err_q       => m_axis_err_q,
            m_axis_err_valid   => m_axis_err_valid
        );

end Structural;
