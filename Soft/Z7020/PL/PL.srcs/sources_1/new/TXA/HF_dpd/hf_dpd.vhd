library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity hf_dpd is
    Port ( 
        s_axis_iq_tdata : in  STD_LOGIC_VECTOR (47 downto 0);  -- iq in 122.88 MHz
        s_axis_adc_tdata : in  STD_LOGIC_VECTOR (15 downto 0); -- adc in 122.88 MHz
        m_axis_iq_tdata : out  STD_LOGIC_VECTOR (31 downto 0); -- iq out 122.88 MHz
        aclk : in  STD_LOGIC; -- 122.88 MHz
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (4 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0); -- dds in 122.88 MHz
        m_cfg_dout : out  STD_LOGIC_VECTOR (31 downto 0);
        m_ovf : out std_logic_vector(3 downto 0)
    );
end hf_dpd;

architecture Behavioral of hf_dpd is

    component hf_dpd_ddc_block
        Port (
            aclk              : in  STD_LOGIC;                     -- 122.88 MHz
            s_axis_adc_tdata  : in  STD_LOGIC_VECTOR (15 downto 0);
            s_axis_dds_tdata  : in  STD_LOGIC_VECTOR (31 downto 0);
            m_axis_bb_i       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
            m_axis_bb_q       : out signed (15 downto 0);          -- Выход Baseband (60 kHz)
            m_axis_bb_valid   : out STD_LOGIC                      -- Строб готовности данных (1 такт из 2048)
        );
    end component;

    -- Параметры LUT (Память предискажений)
    constant LUT_DEPTH : integer := 256;
    type lut_type is array (0 to LUT_DEPTH-1) of std_logic_vector(31 downto 0); -- 16-бит Re, 16-бит Im
    shared variable dpd_lut : lut_type := (others => x"40000000"); -- Инициализация: Re=1.0, Im=0.0 (Q14)

    -------------------------------------------------------------------------
    -- СИГНАЛЫ ТРАКТА ПЕРЕДАЧИ (TX PATH)
    -------------------------------------------------------------------------
    signal tx_i, tx_q         : signed(23 downto 0);
    signal tx_i_reg, tx_q_reg : signed(23 downto 0);
    signal tx_i_del, tx_q_del : signed(23 downto 0);
    signal tx_mag_sq          : unsigned(47 downto 0);
    signal lut_rd_addr        : unsigned(7 downto 0);
    
    signal lut_coeff          : std_logic_vector(31 downto 0);
    signal coeff_r, coeff_i   : signed(15 downto 0);
    signal tx_out_i, tx_out_p : signed(39 downto 0);

    signal rx_bb_i, rx_bb_q   : signed(15 downto 0);

    -------------------------------------------------------------------------
    -- СИГНАЛЫ АДАПТАЦИИ И ВЫРАВНИВАНИЯ ЗАДЕРЖКИ
    -------------------------------------------------------------------------
    -- Линия задержки для Тх (имитация группового времени задержки тракта)
    type delay_pipeline is array (0 to 15) of signed(15 downto 0);
    signal tx_ref_i_pipe      : delay_pipeline := (others => (others => '0'));
    signal tx_ref_q_pipe      : delay_pipeline := (others => (others => '0'));
    
    signal tx_ref_i, tx_ref_q : signed(15 downto 0);
    signal err_i, err_q       : signed(15 downto 0);
    
    signal lut_wr_addr        : unsigned(7 downto 0);
    signal lut_wr_data        : std_logic_vector(31 downto 0);
    signal lut_wr_en          : std_logic := '0';
    
    constant MU               : signed(7 downto 0) := x"02"; -- Шаг адаптации LMS

begin

    -- Разбор входных интерфейсов
    tx_i   <= signed(s_axis_iq_tdata(23 downto 0));
    tx_q   <= signed(s_axis_iq_tdata(47 downto 24));
    
    DDC_INST : hf_dpd_ddc_block
    port map (
        aclk             => aclk,
        s_axis_adc_tdata => s_axis_adc_tdata,
        s_axis_dds_tdata => s_axis_dds_tdata,
        m_axis_bb_i      => rx_bb_i,
        m_axis_bb_q      => rx_bb_q
    );

    -------------------------------------------------------------------------
    -- 2. ТРАКТ ПРЕДИСКАЖЕНИЯ (TX PATH - ПОРТ А LUT)
    -------------------------------------------------------------------------
    process(aclk)
    begin
        if rising_edge(aclk) then
            -- Такт 1: Мощность входного сигнала
            tx_mag_sq <= unsigned((tx_i * tx_i) + (tx_q * tx_q));
            
            tx_i_reg  <= tx_i;
            tx_q_reg  <= tx_q;
            tx_i_del  <= tx_i_reg;
            tx_q_del  <= tx_q_reg;

            -- Такт 2: Индексация адреса LUT
            lut_rd_addr <= tx_mag_sq(45 downto 38);

            -- Такт 3: Выборка коэффициентов (Port A BRAM)
            lut_coeff <= dpd_lut(to_integer(lut_rd_addr));
            coeff_r   <= signed(lut_coeff(31 downto 16));
            coeff_i   <= signed(lut_coeff(15 downto 0));

            -- Такт 4: Комплексное умножение (Искажение сигнала)
            tx_out_i <= (tx_i_del * coeff_r) - (tx_q_del * coeff_i);
            tx_out_p <= (tx_i_del * coeff_i) + (tx_q_del * coeff_r);

            -- Такт 5: Выход на ЦАП (16 бит I, 16 бит Q)
            m_axis_iq_tdata(15 downto 0)  <= std_logic_vector(tx_out_i(31 downto 16));
            m_axis_iq_tdata(31 downto 16) <= std_logic_vector(tx_out_p(31 downto 16));
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 3. БЛОК АДАПТАЦИИ И ОБНОВЛЕНИЯ LUT (LMS - ПОРТ B LUT)
    -------------------------------------------------------------------------
    process(aclk)
        variable next_r, next_i : signed(15 downto 0);
        variable curr_val       : std_logic_vector(31 downto 0);
    begin
        if rising_edge(aclk) then
            -- Сдвиговый регистр задержки опорного сигнала Tx
            -- Выравнивает Tx по времени с моментом прихода отклика с АЦП (DDC Rx)
            tx_ref_i_pipe(0) <= tx_i_del(23 downto 8);
            tx_ref_q_pipe(0) <= tx_q_del(23 downto 8);
            for i in 1 to 15 loop
                tx_ref_i_pipe(i) <= tx_ref_i_pipe(i-1);
                tx_ref_q_pipe(i) <= tx_ref_q_pipe(i-1);
            end loop;

            -- Опорный задержанный сигнал
            tx_ref_i <= tx_ref_i_pipe(15);
            tx_ref_q <= tx_ref_q_pipe(15);

            -- Вычисление комплексной ошибки: E = Tx_ref - Rx_baseband
            err_i <= tx_ref_i - rx_bb_i;
            err_q <= tx_ref_q - rx_bb_q;

            -- Обновление LUT по алгоритму LMS (при наличии сигнала валидности)
            if s_axis_cfg_tvalid = '1' and s_axis_cfg_tdest = "01010" then
                -- Вычисляем адрес ячейки, соответствующий мощности задержанного сигнала
                lut_wr_addr <= tx_mag_sq(45 downto 38); -- В продакшене эту шину адреса тоже нужно задержать на длину pipe!

                -- Чтение текущего состояния ячейки (Port B BRAM)
                curr_val := dpd_lut(to_integer(lut_wr_addr));
                next_r   := signed(curr_val(31 downto 16));
                next_i   := signed(curr_val(15 downto 0));

                -- LMS обновление комплексного веса: W = W + mu * E * X*
                next_r := next_r + resize((err_i * MU), 16);
                next_i := next_i + resize((err_q * MU), 16);

                lut_wr_data <= std_logic_vector(next_r) & std_logic_vector(next_i);
                lut_wr_en   <= '1';
            else
                lut_wr_en   <= '0';
            end if;

            -- Синхронная запись в RAM
            if lut_wr_en = '1' then
                dpd_lut(to_integer(lut_wr_addr)) := lut_wr_data;
            end if;
        end if;
    end process;

    -- Неиспользуемые интерфейсы
    m_cfg_dout <= s_axis_cfg_tdata;
    m_ovf      <= (others => '0');

end Behavioral;

