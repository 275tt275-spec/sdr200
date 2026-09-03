library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity time_alignment is
    Generic (
        DATA_WIDTH  : integer := 16;
        ADDR_WIDTH  : integer := 8   -- 2 в степени 8 = 256 тактов максимальной задержки
    );
    Port (
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
end time_alignment;

architecture Behavioral of time_alignment is
    type ram_type is array (0 to (2**ADDR_WIDTH)-1) of std_logic_vector((DATA_WIDTH*2)-1 downto 0);
    signal ram_block     : ram_type := (others => (others => '0'));
    signal write_ptr      : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal read_ptr       : unsigned(ADDR_WIDTH-1 downto 0) := (others => '0');
    signal combined_in    : std_logic_vector((DATA_WIDTH*2)-1 downto 0);
    signal combined_out   : std_logic_vector((DATA_WIDTH*2)-1 downto 0);
    signal r_valid        : std_logic := '0';
begin
    -- Объединяем I и Q в одну шину, чтобы они записывались в память синхронно
    combined_in <= s_axis_ref_tdata_i & s_axis_ref_tdata_q;
    -- Адрес чтения - это адрес записи минус задержка (автоматически зацикливается)
    read_ptr <= write_ptr - unsigned(cfg_delay_ticks);
process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            write_ptr <= (others => '0');
            r_valid <= '0';
            m_axis_align_tdata_i <= (others => '0');
            m_axis_align_tdata_q <= (others => '0');
        else
            -- Запись новых данных в циклическую память BRAM
            if s_axis_ref_tvalid = '1' then
                ram_block(to_integer(write_ptr)) <= combined_in;
                write_ptr <= write_ptr + 1;
            end if;
            -- Чтение задержанных данных из памяти
            combined_out <= ram_block(to_integer(read_ptr));
            r_valid <= s_axis_ref_tvalid;
            -- Разделение шины обратно на каналы I и Q
            m_axis_align_tdata_i <= combined_out((DATA_WIDTH*2)-1 downto DATA_WIDTH);
            m_axis_align_tdata_q <= combined_out(DATA_WIDTH-1 downto 0);
        end if;
    end if;
end process;

    m_axis_align_tvalid <= r_valid;end Behavioral;
