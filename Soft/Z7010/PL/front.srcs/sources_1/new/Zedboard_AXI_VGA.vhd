-- VHDL-модуль: Zedboard_AXI_VGA
-- Описание: 24-битный VGA-контроллер с AXI-интерфейсом и DMA.
-- Переработан с Verilog-источника (C) Peter J. Bone.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library xpm;
use xpm.vcomponents.all;

entity Zedboard_AXI_VGA is
    port (
        -- VGA Interface
        vga_clk     : in  std_logic;
        h_sync      : out std_logic;
        v_sync      : out std_logic;
        lcd_dclk    : out std_logic;
        lcd_de      : out std_logic;
        lcd_dctrl   : out std_logic;
        r           : out std_logic_vector(7 downto 0);
        g           : out std_logic_vector(7 downto 0);
        b           : out std_logic_vector(7 downto 0);
        frm_cpt_irq : out std_logic;

        -- AXI Control Interface
        s_axi_aclk     : in  std_logic;
        s_axi_aresetn  : in  std_logic;
        s_axi_awvalid  : in  std_logic;
        s_axi_awaddr   : in  std_logic_vector(31 downto 0);
        s_axi_awready  : out std_logic;
        s_axi_wvalid   : in  std_logic;
        s_axi_wdata    : in  std_logic_vector(31 downto 0);
        s_axi_wstrb    : in  std_logic_vector(3 downto 0);
        s_axi_wready   : out std_logic;
        s_axi_bvalid   : out std_logic;
        s_axi_bresp    : out std_logic_vector(1 downto 0);
        s_axi_bready   : in  std_logic;
        s_axi_arvalid  : in  std_logic;
        s_axi_araddr   : in  std_logic_vector(31 downto 0);
        s_axi_arready  : out std_logic;
        s_axi_rvalid   : out std_logic;
        s_axi_rdata    : out std_logic_vector(31 downto 0);
        s_axi_rresp    : out std_logic_vector(1 downto 0);
        s_axi_rready   : in  std_logic;

        -- AXI Master DMA Interface
        m_axi_aclk     : in  std_logic;
        m_axi_aresetn  : in  std_logic;
        m_axi_arready  : in  std_logic;
        m_axi_rdata    : in  std_logic_vector(31 downto 0);
        m_axi_rlast    : in  std_logic;
        m_axi_rvalid   : in  std_logic;
        m_axi_araddr   : out std_logic_vector(31 downto 0);
        m_axi_arlen    : out std_logic_vector(7 downto 0);
        m_axi_arsize   : out std_logic_vector(2 downto 0);
        m_axi_arburst  : out std_logic_vector(1 downto 0);
        m_axi_arprot   : out std_logic_vector(2 downto 0);
        m_axi_arvalid  : out std_logic;
        m_axi_rready   : out std_logic
    );
end entity Zedboard_AXI_VGA;

architecture rtl of Zedboard_AXI_VGA is

    -- Константы состояний DMA
    constant IDLE        : std_logic_vector(7 downto 0) := x"01";
    constant ADDR_READY  : std_logic_vector(7 downto 0) := x"02";
    constant READ        : std_logic_vector(7 downto 0) := x"04";
    constant READ_REQ    : std_logic_vector(7 downto 0) := x"08";
    constant FIFO_WAIT   : std_logic_vector(7 downto 0) := x"10";

    -- VGA-регистры
    signal h_sync_r      : std_logic := '0';
    signal h_cnt         : unsigned(10 downto 0) := (others => '0');
    signal v_sync_r      : std_logic := '0';
    signal v_cnt         : unsigned(10 downto 0) := (others => '0');
    signal px_clk_nco_r  : unsigned(35 downto 0) := (others => '0');
    signal irq           : std_logic := '0';
    signal fifo_ready    : std_logic := '0';

    -- AXI Control Registers
    signal h_cntrl1      : std_logic_vector(31 downto 0) := x"8840053f";
    signal h_cntrl2      : std_logic_vector(31 downto 0) := x"000A0017";
    signal v_cntrl1      : std_logic_vector(31 downto 0) := x"06300325";
    signal v_cntrl2      : std_logic_vector(31 downto 0) := x"0001D003";
    signal msbs_px_nco   : std_logic_vector(31 downto 0) := x"00000005";
    signal lsbs_px_nco   : std_logic_vector(31 downto 0) := x"33333333";
    signal ddr_fbuf_addr : std_logic_vector(31 downto 0) := x"0F000000";
    signal total_pixels  : std_logic_vector(31 downto 0) := x"400C0000";
    signal irq_reg       : std_logic_vector(31 downto 0) := (others => '0');

    -- AXI DMA Master Registers
    signal ddr_address   : std_logic_vector(31 downto 0) := (others => '0');
    signal ar_valid      : std_logic := '0';
    signal m_axi_rready_int : std_logic := '0';
    signal state_r       : std_logic_vector(7 downto 0) := IDLE;
    signal dma_cnt       : unsigned(22 downto 0) := (others => '0');

    -- Internal AXI Control signals
    signal up_clk        : std_logic;
    signal up_wreq       : std_logic;
    signal up_waddr      : std_logic_vector(13 downto 0);
    signal up_wdata      : std_logic_vector(31 downto 0);
    signal up_wack       : std_logic;
    signal up_rreq       : std_logic;
    signal up_raddr      : std_logic_vector(13 downto 0);
    signal up_rdata      : std_logic_vector(31 downto 0);
    signal up_rack       : std_logic;

    -- Internal VGA signals
    signal px_clk        : std_logic;
    signal px_nco_phase  : std_logic_vector(35 downto 0);
    signal px_nco_cntrl  : std_logic_vector(35 downto 0);
    signal thpixels      : unsigned(11 downto 0);
    signal hpixels       : unsigned(11 downto 0);
    signal hpulse        : unsigned(7 downto 0);
    signal hfp           : unsigned(11 downto 0);
    signal hbp           : unsigned(11 downto 0);
    signal hspol         : std_logic;
    signal tvlines       : unsigned(11 downto 0);
    signal vlines        : unsigned(11 downto 0);
    signal vpulse        : unsigned(7 downto 0);
    signal vfp           : unsigned(11 downto 0);
    signal vbp           : unsigned(11 downto 0);
    signal vspol         : std_logic;
    signal dma_data      : std_logic_vector(31 downto 0);
    signal rgb_data      : std_logic_vector(31 downto 0);
    signal vgamem_rd_en  : std_logic;
    signal fifo_readyw   : std_logic;
    signal dma_ready     : std_logic;
    signal dma_rst       : std_logic;
    signal rst_busy_wr   : std_logic;
    signal rst_busy_rd   : std_logic;
    signal rst_ready     : std_logic;
    signal dma_tcnt      : unsigned(24 downto 0);
    signal irq_en        : std_logic;
    signal fifo_wr_en    : std_logic;  -- Промежуточный сигнал для wr_en
    signal brightness    : std_logic_vector(7 downto 0) := x"20";

    -- Компонент AXI Control Interface
    component axi_vga_ctrl is
        port (
            up_rstn          : in  std_logic;
            up_clk           : in  std_logic;
            up_axi_awvalid   : in  std_logic;
            up_axi_awaddr    : in  std_logic_vector(31 downto 0);
            up_axi_awready   : out std_logic;
            up_axi_wvalid    : in  std_logic;
            up_axi_wdata     : in  std_logic_vector(31 downto 0);
            up_axi_wstrb     : in  std_logic_vector(3 downto 0);
            up_axi_wready    : out std_logic;
            up_axi_bvalid    : out std_logic;
            up_axi_bresp     : out std_logic_vector(1 downto 0);
            up_axi_bready    : in  std_logic;
            up_axi_arvalid   : in  std_logic;
            up_axi_araddr    : in  std_logic_vector(31 downto 0);
            up_axi_arready   : out std_logic;
            up_axi_rvalid    : out std_logic;
            up_axi_rresp     : out std_logic_vector(1 downto 0);
            up_axi_rdata     : out std_logic_vector(31 downto 0);
            up_axi_rready    : in  std_logic;
            up_wreq          : out std_logic;
            up_waddr         : out std_logic_vector(13 downto 0);
            up_wdata         : out std_logic_vector(31 downto 0);
            up_wack          : in  std_logic;
            up_rreq          : out std_logic;
            up_raddr         : out std_logic_vector(13 downto 0);
            up_rdata         : in  std_logic_vector(31 downto 0);
            up_rack          : in  std_logic
        );
    end component;

    -- Компонент XPM FIFO Async
    component xpm_fifo_async is
        generic (
            FIFO_MEMORY_TYPE   : string := "auto";
            ECC_MODE           : string := "no_ecc";
            RELATED_CLOCKS     : integer := 0;
            FIFO_WRITE_DEPTH   : integer := 4096;
            WRITE_DATA_WIDTH   : integer := 32;
            WR_DATA_COUNT_WIDTH: integer := 12;
            PROG_FULL_THRESH   : integer := 3968;
            FULL_RESET_VALUE   : integer := 0;
            USE_ADV_FEATURES   : string := "0707";
            READ_MODE          : string := "fwft";
            FIFO_READ_LATENCY  : integer := 0;
            READ_DATA_WIDTH    : integer := 32;
            RD_DATA_COUNT_WIDTH: integer := 12;
            PROG_EMPTY_THRESH  : integer := 256;
            DOUT_RESET_VALUE   : string := "0";
            CDC_SYNC_STAGES    : integer := 2;
            WAKEUP_TIME        : integer := 0
        );
        port (
            rst            : in  std_logic;
            wr_clk         : in  std_logic;
            wr_en          : in  std_logic;
            din            : in  std_logic_vector(31 downto 0);
            full           : out std_logic;
            overflow       : out std_logic;
            prog_full      : out std_logic;
            wr_data_count  : out std_logic_vector(11 downto 0);
            almost_full    : out std_logic;
            wr_ack         : out std_logic;
            wr_rst_busy    : out std_logic;
            rd_clk         : in  std_logic;
            rd_en          : in  std_logic;
            dout           : out std_logic_vector(31 downto 0);
            empty          : out std_logic;
            underflow      : out std_logic;
            rd_rst_busy    : out std_logic;
            prog_empty     : out std_logic;
            rd_data_count  : out std_logic_vector(11 downto 0);
            almost_empty   : out std_logic;
            data_valid     : out std_logic;
            sleep          : in  std_logic;
            injectsbiterr  : in  std_logic;
            injectdbiterr  : in  std_logic;
            sbiterr        : out std_logic;
            dbiterr        : out std_logic
        );
    end component;

    -- Компонент NCO
    component nco36_o36 is
        port (
            clk         : in  std_logic;
            cntrl       : in  std_logic_vector(35 downto 0);
            phase_shift : in  std_logic_vector(35 downto 0);
            phase       : out std_logic_vector(35 downto 0)
        );
    end component;

    -- Компонент BUFG для распределения тактового сигнала
    component BUFG is
        port (
            O : out std_logic;
            I : in  std_logic
        );
    end component;
    
    component lcd_dctrl_en is
     Port ( 
        clk : in STD_LOGIC;
        s_brightness : in std_logic_vector(7 downto 0);
        lcd_dctrl : out STD_LOGIC
     );
    end component lcd_dctrl_en;

begin

    brightness_0 : lcd_dctrl_en
     Port map ( 
        clk => s_axi_aclk,
        s_brightness => brightness,
        lcd_dctrl => lcd_dctrl
     );

    -- Присваиваем внутренние сигналы выходным портам
    m_axi_rready <= m_axi_rready_int;
    up_clk <= s_axi_aclk;
    
    -- Формируем сигнал записи в FIFO
    fifo_wr_en <= m_axi_rvalid and m_axi_rready_int;

    -- VGA Assignments (преобразование типов)
    h_sync <= h_sync_r when hspol = '1' else not h_sync_r;
    v_sync <= v_sync_r when vspol = '1' else not v_sync_r;
    
--    r <= rgb_data(23 downto 16) when (v_cnt < vlines and h_cnt < hpixels) else (others => '0');
--    g <= rgb_data(15 downto 8)  when (v_cnt < vlines and h_cnt < hpixels) else (others => '0');
--    b <= rgb_data(7 downto 0)   when (v_cnt < vlines and h_cnt < hpixels) else (others => '0');
    
    r <= rgb_data(23 downto 16) when (vgamem_rd_en = '1') else (others => '0');
    g <= rgb_data(15 downto 8) when (vgamem_rd_en = '1') else (others => '0');
    b <= rgb_data(7 downto 0) when (vgamem_rd_en = '1') else (others => '0');


    -- Распаковка управляющих регистров
    thpixels <= unsigned(h_cntrl1(11 downto 0));
    hpixels  <= unsigned(h_cntrl1(23 downto 12));
    hpulse   <= unsigned(h_cntrl1(31 downto 24));
    hfp      <= unsigned(h_cntrl2(11 downto 0));
    hbp      <= unsigned(h_cntrl2(23 downto 12));
    hspol    <= h_cntrl2(31);
    
    tvlines  <= unsigned(v_cntrl1(11 downto 0));
    vlines   <= unsigned(v_cntrl1(23 downto 12));
    vpulse   <= unsigned(v_cntrl1(31 downto 24));
    vfp      <= unsigned(v_cntrl2(11 downto 0));
    vbp      <= unsigned(v_cntrl2(23 downto 12));
    vspol    <= v_cntrl2(31);

    -- Формирование управляющих сигналов
    px_nco_cntrl(35 downto 32) <= msbs_px_nco(3 downto 0);
    px_nco_cntrl(31 downto 0)  <= lsbs_px_nco;
    
--    vgamem_rd_en <= '1' when (h_cnt < hpixels and v_cnt < vlines and fifo_ready = '1') else '0';
    vgamem_rd_en <= '1' when (h_cnt < hpixels and v_cnt < vlines and fifo_ready = '1' and dma_ready = '1' and rst_ready = '1') else '0';
    dma_ready    <= total_pixels(31);
    dma_rst      <= total_pixels(30);
    rst_ready    <= not (rst_busy_wr or rst_busy_rd);
--    dma_tcnt     <= shift_left(resize(unsigned(total_pixels(22 downto 0)), 25), 2) - 128;
    dma_tcnt <= shift_left(resize(unsigned(total_pixels(22 downto 0)), 25), 2);
    irq_en       <= irq_reg(0);
    frm_cpt_irq  <= irq;

    -- DMA Data
    dma_data <= m_axi_rdata;
    lcd_dclk     <= px_clk;
 --   lcd_dclk <= px_nco_phase(35);
    lcd_de <= vgamem_rd_en;

    -- VGA Processing
    process(px_clk)
    begin
        if rising_edge(px_clk) then
            if (fifo_ready = '1' and dma_ready = '1' and rst_ready = '1') then
                if (h_cnt >= thpixels) then
                    h_cnt <= (others => '0');
                    if (v_cnt >= tvlines) then
                        v_cnt <= (others => '0');
                    else
                        v_cnt <= v_cnt + 1;
                    end if;
                else
                    h_cnt <= h_cnt + 1;
                end if;

                -- Формирование горизонтального синхроимпульса
                if (h_cnt >= (hpixels + hfp) and h_cnt < (hpixels + hfp + hpulse)) then
                    h_sync_r <= '1';
                else
                    h_sync_r <= '0';
                end if;

                -- Формирование вертикального синхроимпульса
                if (v_cnt >= (vlines + vfp) and v_cnt < (vlines + vfp + vpulse)) then
                    v_sync_r <= '1';
                else
                    v_sync_r <= '0';
                end if;

            elsif (fifo_readyw = '1' and rst_ready = '1') then
                fifo_ready <= fifo_readyw;
            end if;
        end if;
    end process;

    -- AXI Control Interface Processing
    process(up_clk)
    begin
        if rising_edge(up_clk) then
            up_wack <= up_wreq;
            up_rack <= up_rreq;

            -- Write operations
            if (up_wreq = '1') then
                case up_waddr(9 downto 0) is
                    when "0000000000" => h_cntrl1 <= up_wdata;
                    when "0000000001" => h_cntrl2 <= up_wdata;
                    when "0000000010" => v_cntrl1 <= up_wdata;
                    when "0000000011" => v_cntrl2 <= up_wdata;
                    when "0000000100" => lsbs_px_nco <= up_wdata;
                    when "0000000101" => msbs_px_nco <= up_wdata;
                    when "0000000110" => ddr_fbuf_addr <= up_wdata;
                    when "0000000111" => total_pixels <= up_wdata;
                    when "0000001000" => irq_reg <= up_wdata;
                    when "0000001001" => brightness <= up_wdata(7 downto 0);
                    when others => null;
                end case;
            end if;

            -- Read operations
            if (up_rreq = '1') then
                case up_raddr(9 downto 0) is
                    when "0000000000" => up_rdata <= h_cntrl1;
                    when "0000000001" => up_rdata <= h_cntrl2;
                    when "0000000010" => up_rdata <= v_cntrl1;
                    when "0000000011" => up_rdata <= v_cntrl2;
                    when "0000000100" => up_rdata <= lsbs_px_nco;
                    when "0000000101" => up_rdata <= msbs_px_nco;
                    when "0000000110" => up_rdata <= ddr_fbuf_addr;
                    when "0000000111" => up_rdata <= total_pixels;
                    when "0000001000" => up_rdata <= irq_reg;
                    when others       => up_rdata <= x"DEADDEAD";
                end case;
            end if;
        end if;
    end process;

    -- AXI Master DMA Processing
    process(m_axi_aclk)
    begin
        if rising_edge(m_axi_aclk) then
            case state_r is
                when IDLE =>
                    irq <= '0';
                    if (dma_ready = '1' and rst_ready = '1') then
                        if (ddr_address = x"00000000") then
                            ddr_address <= ddr_fbuf_addr;
                            dma_cnt <= (others => '0');
                        end if;
                        state_r <= READ_REQ;
                    end if;

                when READ_REQ =>
                    if (fifo_readyw = '0') then
                        ar_valid <= '1';
                        state_r <= ADDR_READY;
                    end if;

                when ADDR_READY =>
                    if (m_axi_arready = '1') then
                        ar_valid <= '0';
                        m_axi_rready_int <= '1';
                        state_r <= READ;
                    end if;

                when READ =>
                    if (m_axi_rlast = '1') then
                        m_axi_rready_int <= '0';
                        if (dma_cnt < dma_tcnt) then
                            ddr_address <= std_logic_vector(unsigned(ddr_address) + 128);
                            dma_cnt <= dma_cnt + 128;
                        else
                            irq <= irq_en;
                            ddr_address <= (others => '0');
                        end if;
                        state_r <= IDLE;
                    end if;

                when others =>
                    state_r <= IDLE;
            end case;
        end if;
    end process;

    -- AXI DMA Master Outputs (фиксированные параметры)
    m_axi_arprot  <= "000";
    m_axi_arsize  <= "010";
    m_axi_arlen   <= x"1F";
    m_axi_arburst <= "01";
    m_axi_araddr  <= ddr_address;
    m_axi_arvalid <= ar_valid;

    -- Instantiate BUFG for pixel clock
    px_clk_bufg : BUFG
        port map (
            O => px_clk,
            I => px_nco_phase(35)
        );

    -- Instantiate AXI Control Interface
    i_axi_vga_ctrl : axi_vga_ctrl
        port map (
            up_rstn          => s_axi_aresetn,
            up_clk           => up_clk,
            up_axi_awvalid   => s_axi_awvalid,
            up_axi_awaddr    => s_axi_awaddr,
            up_axi_awready   => s_axi_awready,
            up_axi_wvalid    => s_axi_wvalid,
            up_axi_wdata     => s_axi_wdata,
            up_axi_wstrb     => s_axi_wstrb,
            up_axi_wready    => s_axi_wready,
            up_axi_bvalid    => s_axi_bvalid,
            up_axi_bresp     => s_axi_bresp,
            up_axi_bready    => s_axi_bready,
            up_axi_arvalid   => s_axi_arvalid,
            up_axi_araddr    => s_axi_araddr,
            up_axi_arready   => s_axi_arready,
            up_axi_rvalid    => s_axi_rvalid,
            up_axi_rresp     => s_axi_rresp,
            up_axi_rdata     => s_axi_rdata,
            up_axi_rready    => s_axi_rready,
            up_wreq          => up_wreq,
            up_waddr         => up_waddr,
            up_wdata         => up_wdata,
            up_wack          => up_wack,
            up_rreq          => up_rreq,
            up_raddr         => up_raddr,
            up_rdata         => up_rdata,
            up_rack          => up_rack
        );

    -- Instantiate XPM FIFO Async
    fifo_inst : xpm_fifo_async
        generic map (
            FIFO_MEMORY_TYPE    => "auto",
            ECC_MODE            => "no_ecc",
            RELATED_CLOCKS      => 0,
            FIFO_WRITE_DEPTH    => 4096,
            WRITE_DATA_WIDTH    => 32,
            WR_DATA_COUNT_WIDTH => 12,
            PROG_FULL_THRESH    => 3968,
            FULL_RESET_VALUE    => 0,
            USE_ADV_FEATURES    => "0707",
            READ_MODE           => "fwft",
            FIFO_READ_LATENCY   => 0,
            READ_DATA_WIDTH     => 32,
            RD_DATA_COUNT_WIDTH => 12,
            PROG_EMPTY_THRESH   => 256,
            DOUT_RESET_VALUE    => "0",
            CDC_SYNC_STAGES     => 2,
            WAKEUP_TIME         => 0
        )
        port map (
            rst            => dma_rst,
            wr_clk         => m_axi_aclk,
            wr_en          => fifo_wr_en,
            din            => dma_data,
            full           => open,
            overflow       => open,
            prog_full      => fifo_readyw,
            wr_data_count  => open,
            almost_full    => open,
            wr_ack         => open,
            wr_rst_busy    => rst_busy_wr,
            rd_clk         => px_clk,
            rd_en          => vgamem_rd_en,
            dout           => rgb_data,
            empty          => open,
            underflow      => open,
            rd_rst_busy    => rst_busy_rd,
            prog_empty     => open,
            rd_data_count  => open,
            almost_empty   => open,
            data_valid     => open,
            sleep          => '0',
            injectsbiterr  => '0',
            injectdbiterr  => '0',
            sbiterr        => open,
            dbiterr        => open
        );

    -- Instantiate Pixel Clock NCO
    px_nco : nco36_o36
        port map (
            clk         => vga_clk,
            cntrl       => px_nco_cntrl,
            phase_shift => (others => '0'),
            phase       => px_nco_phase
        );

end architecture rtl;

-- Модуль NCO
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco36_o36 is
    port (
        clk         : in  std_logic;
        cntrl       : in  std_logic_vector(35 downto 0);
        phase_shift : in  std_logic_vector(35 downto 0);
        phase       : out std_logic_vector(35 downto 0)
    );
end entity nco36_o36;

architecture rtl of nco36_o36 is
    signal phase_acc : unsigned(35 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            phase_acc <= phase_acc + unsigned(cntrl);
            phase <= std_logic_vector(phase_acc + unsigned(phase_shift));
        end if;
    end process;
end architecture rtl;

