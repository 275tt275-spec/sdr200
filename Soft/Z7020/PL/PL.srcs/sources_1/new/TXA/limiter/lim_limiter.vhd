----------------------------------------------------------------------------------
-- Baseband envelope clipper
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lim_limiter is
    Port ( 
        m_axis_data_tdata : out STD_LOGIC_VECTOR (47 downto 0);
        m_axis_data_tvalid : out STD_LOGIC;
        s_axis_data_tdata : in STD_LOGIC_VECTOR (47 downto 0);
        s_axis_data_tvalid : in STD_LOGIC; 
        limit : in STD_LOGIC_VECTOR (15 downto 0);
        fir_reload_tdata : in STD_LOGIC_VECTOR(23 DOWNTO 0);
        fir_reload_tvalid : in STD_LOGIC;
        fir_reload_tlast : in STD_LOGIC;
        fir_config_tdata : in STD_LOGIC_VECTOR(7 DOWNTO 0);
        fir_config_tvalid : in STD_LOGIC;
        over : out STD_LOGIC_VECTOR(1 DOWNTO 0);
        divisor_dbg : out std_logic_vector(15 downto 0);  
        aclk : in STD_LOGIC
    );
end lim_limiter;

architecture Behavioral of lim_limiter is

    component lim_translate_cordic
        port (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
        );
    end component lim_translate_cordic;
    
    component blk_mem_32
        port (
            clka : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            clkb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
        );
    end component blk_mem_32;    
    
    COMPONENT lim_lpf_fir IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_data_tvalid : IN STD_LOGIC;
            s_axis_data_tready : OUT STD_LOGIC;
            s_axis_data_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
            s_axis_config_tvalid : IN STD_LOGIC;
            s_axis_config_tready : OUT STD_LOGIC;
            s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axis_reload_tvalid : IN STD_LOGIC;
            s_axis_reload_tready : OUT STD_LOGIC;
            s_axis_reload_tlast : IN STD_LOGIC;
            s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
            m_axis_data_tvalid : OUT STD_LOGIC;
            m_axis_data_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
            event_s_reload_tlast_missing : OUT STD_LOGIC;
            event_s_reload_tlast_unexpected : OUT STD_LOGIC
        );
    END COMPONENT  lim_lpf_fir;
    
    component lim_div is
    Port ( 
        s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
        out_over : OUT STD_LOGIC;
        aclk : in STD_LOGIC
    );
    end component lim_div;
     
    signal delay_addr_in: std_logic_vector(4 DOWNTO 0) := "10101"; 
    signal delay_addr_out: std_logic_vector(4 DOWNTO 0) := "00000";  
    signal delay_out_0, delay_out_1 : std_logic_vector(23 downto 0) := (others => '0');   
    signal dividend_tdata : std_logic_vector(47 downto 0) := (others => '0');  
    signal cordic_in: std_logic_vector(47 downto 0);
    signal cordic_out: std_logic_vector(31 downto 0);
    signal cordic_tvalid, cordic_tvalid_r : std_logic;
    signal divin_tvalid : std_logic := '0';  
    signal divisor : std_logic_vector(15 downto 0) := x"0001";  
    signal divout_0, divout_1 : std_logic_vector(23 downto 0); 
    signal divout_valid_0, divout_valid_1 : std_logic;
    signal div_over_0, div_over_1 : std_logic;
    signal fir_in_tdata : std_logic_vector(47 downto 0);
    signal fir_in_tvalid : std_logic;
    signal fir_out_tdata : std_logic_vector(63 downto 0);
    signal fir_out_tvalid : std_logic;
    
    -- Константа сдвига для компенсации затухания.
    -- GAIN_SHIFT = 0 -> срез (31 downto 8) [базовый]
    -- GAIN_SHIFT = 1 -> срез (30 downto 7) [+6 дБ усиления]
    -- GAIN_SHIFT = 2 -> срез (29 downto 6) [+12 дБ усиления] -- Выбрано по умолчанию
    -- GAIN_SHIFT = 3 -> срез (28 downto 5) [+18 дБ усиления]
    constant GAIN_SHIFT : integer := 7;     
    -- Промежуточные сигналы
    signal ch_a_24 : std_logic_vector(23 downto 0) := (others => '0');
    signal ch_b_24 : std_logic_vector(23 downto 0) := (others => '0');
    

begin

    divisor_dbg <= divisor;
    cordic_in <= s_axis_data_tdata(47) & s_axis_data_tdata(47 downto 25) & s_axis_data_tdata(23) & s_axis_data_tdata(23 downto 1);

mag_cordic_0 : lim_translate_cordic
    PORT MAP (
      aclk => aclk,
      s_axis_cartesian_tvalid => s_axis_data_tvalid,
      s_axis_cartesian_tdata => cordic_in, 
      m_axis_dout_tvalid => cordic_tvalid,
      m_axis_dout_tdata => cordic_out
    );
    
process(aclk)
begin
	if rising_edge(aclk) then  
	   divin_tvalid <= '0';
	   cordic_tvalid_r <= '0';
	   if s_axis_data_tvalid = '1' then
	       dividend_tdata <= s_axis_data_tdata;
	   end if;
	   if cordic_tvalid = '1' then
	       divisor <= std_logic_vector(abs(signed(cordic_out(15 downto 0))));
	       cordic_tvalid_r <= '1';
	   end if;  
       if cordic_tvalid = '1' then
           if divisor < limit then
	           divisor <= limit;
	       end if;    
	       divin_tvalid <= '1';
	   end if;      
	end if;
end process;
    
    
div_0 : lim_div
    PORT MAP (
        s_axis_divisor_tvalid => '1',
        s_axis_divisor_tdata => divisor,
        s_axis_dividend_tvalid => divin_tvalid,
        s_axis_dividend_tdata => dividend_tdata(47 downto 24),
        m_axis_dout_tvalid => divout_valid_0,
        m_axis_dout_tdata => divout_0,
        out_over => div_over_0,
        aclk => aclk
    );
    
div_1 : lim_div
    PORT MAP (
        s_axis_divisor_tvalid => '1',
        s_axis_divisor_tdata => divisor,
        s_axis_dividend_tvalid => divin_tvalid,
        s_axis_dividend_tdata => dividend_tdata(23 downto 0),
        m_axis_dout_tvalid => divout_valid_1,
        m_axis_dout_tdata => divout_1,
        out_over => div_over_1,
        aclk => aclk
    );

    fir_in_tdata <= (0-divout_0) & (0-divout_1);
    fir_in_tvalid <= divout_valid_0;
    over(0) <= div_over_0 or div_over_1;
     
fir_0 : lim_lpf_fir
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => fir_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => fir_in_tdata,
        s_axis_config_tvalid => fir_config_tvalid,
        s_axis_config_tready => open,
        s_axis_config_tdata => fir_config_tdata,
        s_axis_reload_tvalid => fir_reload_tvalid,
        s_axis_reload_tready => open,
        s_axis_reload_tlast => fir_reload_tlast,
        s_axis_reload_tdata => fir_reload_tdata,
        m_axis_data_tvalid => fir_out_tvalid,
        m_axis_data_tdata => fir_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
process(aclk)
    -- Временные буферные переменные для каналов, чтобы код легко читался
    variable val_a : std_logic_vector(31 downto 0);
    variable val_b : std_logic_vector(31 downto 0);
    
    -- Знаковые биты каждого канала
    variable sign_a : std_logic;
    variable sign_b : std_logic;
    
    -- Переменные-флаги переполнения
    variable overflow_a : boolean;
    variable overflow_b : boolean;
begin
    if rising_edge(aclk) then
        -- По умолчанию сбрасываем валидность шины Stream
        m_axis_data_tvalid <= '0';
        over(1) <= '0';

        if fir_out_tvalid = '1' then
            m_axis_data_tvalid <= '1';
            -- Выделяем каналы по 32 бита во временные переменные
            val_a := fir_out_tdata(63 downto 32);
            val_b := fir_out_tdata(31 downto 0);            
            -- Запоминаем исходные знаковые биты
            sign_a := val_a(31);
            sign_b := val_b(31);
            -- ====================================================================
            -- 1. АППАРАТНАЯ ПРОВЕРКА ПЕРЕПОЛНЕНИЯ ДЛЯ КАНАЛА А
            -- ====================================================================
            -- Целевое 24-битное окно при GAIN_SHIFT = 2 - это биты (29 downto 6).
            -- Значит, все старшие биты от 31 до 29 (включая 29) должны быть равны знаку.
            -- Проверяем биты с 31 по 29. Если хотя бы один из них отличается от знака - это переполнение.
            
            overflow_a := false;
            for i in 31 downto (31 - GAIN_SHIFT) loop
                if val_a(i) /= sign_a then
                    overflow_a := true;
                end if;
            end loop;
            if overflow_a then
                -- Жестко ограничиваем (сатурируем) сигнал
                over(1) <= '1';
                if sign_a = '0' then
                    ch_a_24 <= x"7FFFFF"; -- Максимум в плюс
                else
                    ch_a_24 <= x"800000"; -- Максимум в минус
                end if;
            else
                -- Переполнения нет, вырезаем окно данных с нужным сдвигом усиления
                ch_a_24 <= val_a((31 - GAIN_SHIFT) downto (8 - GAIN_SHIFT));
            end if;
            -- ====================================================================
            -- 2. АППАРАТНАЯ ПРОВЕРКА ПЕРЕПОЛНЕНИЯ ДЛЯ КАНАЛА Б
            -- ====================================================================
            overflow_b := false;
            for i in 31 downto (31 - GAIN_SHIFT) loop
                if val_b(i) /= sign_b then
                    overflow_b := true;
                end if;
            end loop;
            if overflow_b then
                -- Жестко ограничиваем (сатурируем) сигнал
                over(1) <= '1';
                if sign_b = '0' then
                    ch_b_24 <= x"7FFFFF";
                else
                    ch_b_24 <= x"800000";
                end if;
            else
                -- Переполнения нет, вырезаем окно данных с нужным сдвигом усиления
                ch_b_24 <= val_b((31 - GAIN_SHIFT) downto (8 - GAIN_SHIFT));
            end if;
        end if;
        -- 3. Плотная склейка двух каналов в 48-битную шину TDATA
        m_axis_data_tdata <= ch_a_24 & ch_b_24;
    end if;
end process;
    
--    m_axis_data_tdata <= fir_out_tdata(63) & fir_out_tdata(56 downto 34) & fir_out_tdata(31) & fir_out_tdata(24 downto 2);

end Behavioral;
