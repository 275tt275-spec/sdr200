----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 18.11.2022 15:34:11

----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity serializer is
    Generic(
        ACLK_FREQ : natural := 122880000;
        -- Длительность удержания ser_init в тактах clk_ser (например, 20 тактов)
        INIT_HOLD_CYCLES : natural := 20 
    );
    Port (
        aclk : in STD_LOGIC;
        
        s_axis_wb_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_wb_tvalid : in STD_LOGIC;
        s_axis_ch2_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_ch2_tvalid : in STD_LOGIC;
        
        gpio_in : in STD_LOGIC_VECTOR (6 downto 0);
        
        RF_DATAOUT_N : out std_logic;
        RF_DATAOUT_P : out std_logic;  
        RF_CLOCKOUT_N : out std_logic;
        RF_CLOCKOUT_P : out std_logic  
    );
end serializer;

architecture Behavioral of serializer is

    type T_STATE is (S0, S1, S2, S3, S4, S5);
    signal state : T_STATE := S0;
    
    type T_STATE_IN is (IDLE, S0_IN);
    signal state_in : T_STATE_IN := IDLE;
    
    constant CLK_DIVIDER : unsigned(3 downto 0) := to_unsigned(5, 4); -- out 10.240 MHz
    
    signal shift_reg : std_logic_vector(11 downto 0);
    signal data_ddr, ddr_d1, ddr_d2 : std_logic;
    
    -- Сигналы блока инициализации
    signal init_pulse_in : STD_LOGIC; 
    signal ser_init : std_logic := '1'; -- Изначально в '1' до первого сброса
    signal init_hold_cnt : natural range 0 to INIT_HOLD_CYCLES := 0;
    signal init_pulse_sync_r : std_logic_vector(2 downto 0) := (others => '0');
    signal init_pulse_detected : std_logic := '0';
    
    signal ser_rfd : std_logic := '0';
    signal din : std_logic_vector(9 downto 0);
    signal spi0_cs : std_logic := '1';
    signal spi1_cs : std_logic := '1';    
    signal bit_cnt : unsigned(7 downto 0) := (others => '0');
    signal rx_data_valid : std_logic_vector(1 downto 0) := (others => '0');
    signal rx_rdy_r, rx_rdy_r1, data_fmt_nd, rx_rdy_toggle : std_logic := '0';
    
    -- Тактовые сигналы
    signal clk_ser_raw : std_logic := '0';
    signal clk_ser     : std_logic;
    signal clk_out     : std_logic := '0';
    signal clk_cnt     : unsigned(3 downto 0) := (others => '0');
    
    signal rx_data_0r, rx_data_1r : std_logic_vector(31 downto 0) := (others => '0');
    signal rx_data_0, rx_data_1 : std_logic_vector(31 downto 0) := (others => '0');  

begin
    
    din(0) <= spi0_cs;
    din(1) <= rx_data_0(31);
    din(2) <= spi1_cs;
    din(3) <= rx_data_1(31);
    din(9 downto 4) <= gpio_in(5 downto 0);
    init_pulse_in <= gpio_in(6);

    ddr_d1 <= not shift_reg(0);
    ddr_d2 <= not shift_reg(1);
    
    -- Пропускаем сгенерированный clk_ser через BUFG, чтобы убрать фазовый перекос
    bufg_clk_ser : BUFG
    port map (
        I => clk_ser_raw,
        O => clk_ser
    );

out_ddr : ODDR
   generic map(
      DDR_CLK_EDGE => "SAME_EDGE", 
      INIT => '0',   -- Initial value for Q port ('1' or '0')
      SRTYPE => "SYNC") -- Reset Type ("ASYNC" or "SYNC")
   port map (
      Q => data_ddr,   -- 1-bit DDR output
      C => clk_ser,  -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D1 => ddr_d1,  -- 1-bit data input (positive edge)
      D2 => ddr_d2,  -- 1-bit data input (negative edge)
      R => '0',    -- 1-bit reset input
      S => '0'     -- 1-bit set input
   );

out_buf : OBUFDS
   port map (
      O => RF_DATAOUT_P,
      OB => RF_DATAOUT_N,
      I => data_ddr      -- Buffer input 
   );
 
-- 122.880 MHz   
out_clk : OBUFDS
   port map (
      O => RF_CLOCKOUT_P,
      OB => RF_CLOCKOUT_N,
      I => clk_out      -- Buffer input 
   );
   
------------------------------------------------------------------------------
-- Логика деления и генерации частот
------------------------------------------------------------------------------
process(aclk)
begin
    if rising_edge(aclk) then    
        -- Генерация clk_ser_raw (делим на 2)
        clk_ser_raw <= not clk_ser_raw;
        
        -- Генерация clk_out (10.24 МГц)
        if clk_cnt = CLK_DIVIDER then
            clk_cnt <= (others => '0');
            clk_out <= not clk_out;
        else
            clk_cnt <= clk_cnt + 1;
        end if;
    end if;
end process;
    
------------------------------------------------------------------------------
-- БЛОК ИНИЦИАЛИЗАЦИИ И СИНХРОНИЗАЦИИ ИМПУЛЬСА (В домене clk_ser)
------------------------------------------------------------------------------
process(clk_ser)
begin
    if rising_edge(clk_ser) then
        -- 3-ступенчатый сдвиговый регистр для безопасного CDC перехода импульса
        init_pulse_sync_r <= init_pulse_sync_r(1 downto 0) & init_pulse_in;
        
        -- Детектор переднего фронта импульса
        if init_pulse_sync_r(1) = '1' and init_pulse_sync_r(2) = '0' then
            init_pulse_detected <= '1';
        else
            init_pulse_detected <= '0';
        end if;

        -- Автомат расширителя импульса (Pulse Extender) для ser_init
        if init_pulse_detected = '1' then
            ser_init      <= '1';
            init_hold_cnt <= INIT_HOLD_CYCLES; -- Загружаем счетчик удержания
        elsif init_hold_cnt > 0 then
            ser_init      <= '1';
            init_hold_cnt <= init_hold_cnt - 1; -- Считаем такты вниз
        else
            ser_init      <= '0'; -- Время удержания истекло, разрешаем работу
        end if;
    end if;
end process;

------------------------------------------------------------------------------
-- Основной автомат сериализатора (Передатчик)
------------------------------------------------------------------------------
process(clk_ser)
begin
	if rising_edge(clk_ser) then
        case state is
        when S0 =>
             if ser_init = '0' then
                shift_reg <= '0' & din & '1'; -- Отправка реальных данных
             else
                shift_reg <= "000000000001";  -- Режим инициализации/покоя  
             end if;   
             ser_rfd <= '1';
             state <= S1;
        when S1 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            ser_rfd <= '0';
            state <= S2;
        when S2 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S3;
        when S3 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S4;
        when S4 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S5;
        when S5 => 
            shift_reg(9 downto 0) <= shift_reg(11 downto 2);
            state <= S0;
        end case;
    end if;
end process;

------------------------------------------------------------------------------
-- Приемник входных данных (Формирователь кадра)
------------------------------------------------------------------------------
process(clk_ser)
begin
    if rising_edge(clk_ser) then
        case state_in is
        when IDLE =>
            if data_fmt_nd = '1' then
                rx_data_0 <= rx_data_0r;
                rx_data_1 <= rx_data_1r;
                spi0_cs <= '0';
                spi1_cs <= '0';
                bit_cnt <= (others => '0');
                state_in <= S0_IN;
            else
                spi0_cs <= '1';
                spi1_cs <= '1';
            end if;
        when S0_IN =>
            if ser_rfd = '1' then
                rx_data_0(31 downto 1) <= rx_data_0(30 downto 0);
                rx_data_1(31 downto 1) <= rx_data_1(30 downto 0);
                if bit_cnt = 31 then
                    state_in <= IDLE;
                else
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end case;
        
        -- Безопасный синхронизатор CDC для флага готовности данных
        rx_rdy_r  <= rx_rdy_toggle;
        rx_rdy_r1 <= rx_rdy_r;
        if rx_rdy_r /= rx_rdy_r1 then
            data_fmt_nd <= '1';
        else
            data_fmt_nd <= '0';
        end if;    
    end if;
end process;

------------------------------------------------------------------------------
-- Защелка интерфейса AXI-Stream (В домене aclk)
------------------------------------------------------------------------------
process(aclk)
begin
    if rising_edge(aclk) then
        if s_axis_wb_tvalid = '1' then 
           rx_data_0r <= s_axis_wb_tdata;
           rx_data_valid(0) <= '1';
        end if;  
        if s_axis_ch2_tvalid = '1' then 
           rx_data_1r <= s_axis_ch2_tdata;
           rx_data_valid(1) <= '1';
        end if; 
        
        if rx_data_valid = "11" then
           rx_rdy_toggle <= not rx_rdy_toggle;
           rx_data_valid <= (others => '0');    
        end if;            
    end if;
end process;
		
end Behavioral;
