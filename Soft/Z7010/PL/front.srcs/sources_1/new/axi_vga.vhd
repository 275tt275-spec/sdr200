library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_vga is
    generic (
        -- Ширина адресной шины AXI (64 КБ = 16 бит)
        C_S_AXI_ADDR_WIDTH : integer := 16;
        C_S_AXI_DATA_WIDTH : integer := 32
    );
    port (
        -- Глобальные сигналы AXI
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;
        
        -- Каналы записи адреса и данных (AXI Write)
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;
        
        -- Каналы чтения адреса и данных (AXI Read)
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic;
        
        -- Выходные сигналы для внутренней VGA-логики (генератора таймингов)
        o_h_ctrl1        : out std_logic_vector(31 downto 0);
        o_h_ctrl2        : out std_logic_vector(31 downto 0);
        o_v_ctrl1        : out std_logic_vector(31 downto 0);
        o_v_ctrl2        : out std_logic_vector(31 downto 0);
        o_px_nco_lsbs    : out std_logic_vector(31 downto 0);
        o_px_nco_msbs    : out std_logic_vector(31 downto 0);
        o_vga_fbuf_addr  : out std_logic_vector(31 downto 0);
        o_total_pixels   : out std_logic_vector(31 downto 0);
        o_irq_reg        : out std_logic_vector(31 downto 0);
        o_brightness     : out std_logic_vector(31 downto 0)
    );
end entity axi_vga;

architecture rtl of axi_vga is

    -- Сигналы интерфейса AXI
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bvalid  : std_logic;
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(31 downto 0);
    signal axi_rvalid  : std_logic;

    -- Внутренние регистры (согласно вашей структуре vga_creg_map)
    signal reg_h_ctrl1       : std_logic_vector(31 downto 0) := x"8840053f";
    signal reg_h_ctrl2       : std_logic_vector(31 downto 0) := x"000A0017";
    signal reg_v_ctrl1       : std_logic_vector(31 downto 0) := x"06300325";
    signal reg_v_ctrl2       : std_logic_vector(31 downto 0) := x"0001D003";
    signal reg_px_nco_lsbs   : std_logic_vector(31 downto 0) := x"33333333";
    signal reg_px_nco_msbs   : std_logic_vector(31 downto 0) := x"00000005";
    signal reg_vga_fbuf_addr : std_logic_vector(31 downto 0) := x"0F000000";
    signal reg_total_pixels  : std_logic_vector(31 downto 0) := x"400C0000";
    signal reg_irq_reg       : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_brightness    : std_logic_vector(31 downto 0) := x"00000020";

    -- Сигналы управления записью/чтением
    signal reg_wren : std_logic;
    signal reg_rden : std_logic;
    
    -- Смещение адреса слова (биты [5:2] для 10 регистров)
    -- Так как адресация побайтовая, младшие 2 бита [1:0] игнорируются
    signal waddr_index : integer range 0 to 15;
    signal raddr_index : integer range 0 to 15;

begin

    -- Назначение выходных портов AXI
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= "00"; -- OKAY
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= "00"; -- OKAY
    S_AXI_RVALID  <= axi_rvalid;

    -- Привязка внутренних регистров к выходным интерфейсам для VGA логики
    o_h_ctrl1       <= reg_h_ctrl1;
    o_h_ctrl2       <= reg_h_ctrl2;
    o_v_ctrl1       <= reg_v_ctrl1;
    o_v_ctrl2       <= reg_v_ctrl2;
    o_px_nco_lsbs   <= reg_px_nco_lsbs;
    o_px_nco_msbs   <= reg_px_nco_msbs;
    o_vga_fbuf_addr <= reg_vga_fbuf_addr;
    o_total_pixels  <= reg_total_pixels;
    o_irq_reg       <= reg_irq_reg;
    o_brightness    <= reg_brightness;

    -- Индексы регистров (выделяем биты с 5 по 2 для адресации слов)
    waddr_index <= to_integer(unsigned(S_AXI_AWADDR(5 downto 2)));
    raddr_index <= to_integer(unsigned(S_AXI_ARADDR(5 downto 2)));

    ---------------------------------------------------------------------------
    -- Логика ЗАПИСИ AXI (Исправленная: Готовность выставляется без задержек)
    ---------------------------------------------------------------------------
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
            else
                -- Готовность принять адрес записи
                if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
                    axi_awready <= '1';
                else
                    axi_awready <= '0';
                end if;

                -- Готовность принять данные записи
                if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1') then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;

                -- Формирование подтверждения транзакции записи (BVALID)
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1') then
                    axi_bvalid <= '1';
                elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    reg_wren <= axi_awready and S_AXI_AWVALID and axi_wready and S_AXI_WVALID;

    -- Процесс записи в регистры конфигурации VGA
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                reg_h_ctrl1       <= (others => '0');
                reg_h_ctrl2       <= (others => '0');
                reg_v_ctrl1       <= (others => '0');
                reg_v_ctrl2       <= (others => '0');
                reg_px_nco_lsbs   <= (others => '0');
                reg_px_nco_msbs   <= (others => '0');
                reg_vga_fbuf_addr <= (others => '0');
                reg_total_pixels  <= (others => '0');
                reg_irq_reg       <= (others => '0');
                reg_brightness    <= (others => '0');
            elsif reg_wren = '1' then
                case waddr_index is
                    when 0  => reg_h_ctrl1       <= S_AXI_WDATA;
                    when 1  => reg_h_ctrl2       <= S_AXI_WDATA;
                    when 2  => reg_v_ctrl1       <= S_AXI_WDATA;
                    when 3  => reg_v_ctrl2       <= S_AXI_WDATA;
                    when 4  => reg_px_nco_lsbs   <= S_AXI_WDATA;
                    when 5  => reg_px_nco_msbs   <= S_AXI_WDATA;
                    when 6  => reg_vga_fbuf_addr <= S_AXI_WDATA;
                    when 7  => reg_total_pixels  <= S_AXI_WDATA;
                    when 8  => reg_irq_reg       <= S_AXI_WDATA;
                    when 9  => reg_brightness    <= S_AXI_WDATA;
                    when others => null; -- Остальные адреса в пределах 16-ти слов игнорируются
                end case;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Логика ЧТЕНИЯ AXI (Исправленная: Убран баг с задержкой в 8 тактов)
    ---------------------------------------------------------------------------
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_rvalid  <= '0';
            else
                -- Готовность принять адрес чтения выставляется мгновенно
                if (axi_arready = '0' and S_AXI_ARVALID = '1') then
                    axi_arready <= '1';
                else
                    axi_arready <= '0';
                end if;

                -- Выставляем RVALID сразу после фиксации адреса
                if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
                    axi_rvalid <= '1';
                elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);

    -- Мультиплексор чтения регистров
    process(S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rdata <= (others => '0');
            elsif reg_rden = '1' then
                case raddr_index is
                    when 0  => axi_rdata <= reg_h_ctrl1;
                    when 1  => axi_rdata <= reg_h_ctrl2;
                    when 2  => axi_rdata <= reg_v_ctrl1;
                    when 3  => axi_rdata <= reg_v_ctrl2;
                    when 4  => axi_rdata <= reg_px_nco_lsbs;
                    when 5  => axi_rdata <= reg_px_nco_msbs;
                    when 6  => axi_rdata <= reg_vga_fbuf_addr;
                    when 7  => axi_rdata <= reg_total_pixels;
                    when 8  => axi_rdata <= reg_irq_reg;
                    when 9  => axi_rdata <= reg_brightness;
                    when others => axi_rdata <= X"DEADBEEF"; -- Чтение нераспределенной памяти
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
