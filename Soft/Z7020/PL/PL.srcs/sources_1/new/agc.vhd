----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.12.2025 11:02:28
-- Design Name: 
-- Module Name: agc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use ieee.std_logic_signed.all;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity agc is
    Port (
        aclk : in STD_LOGIC;
        s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_tuser : in STD_LOGIC_VECTOR (0 downto 0);
        s_axis_tvalid : in std_logic;
        m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
        m_axis_tuser : out STD_LOGIC_VECTOR (0 downto 0);
        m_axis_tvalid : out std_logic;
        cfg_addra : in STD_LOGIC_VECTOR (2 downto 0);
        cfg_dina : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr : in STD_LOGIC
    );
end agc;

architecture Behavioral of agc is

    COMPONENT cordic_rssi IS
        PORT (
            aclk : IN STD_LOGIC;
            s_axis_cartesian_tvalid : IN STD_LOGIC;
            s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
            m_axis_dout_tvalid : OUT STD_LOGIC;
            m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
        );
    END COMPONENT cordic_rssi;
    
     COMPONENT ram_max_finder IS
        GENERIC (
            DATA_WIDTH  : positive := 32;
            WINDOW_SIZE : positive := 64
        );
        PORT (
            aclk           : in  std_logic;
            data_in        : in  std_logic_vector(31 downto 0);
            data_in_valid  : in  std_logic;
            max_out        : out std_logic_vector(31 downto 0);
            max_out_valid  : out std_logic
        );
    END COMPONENT;

    signal s_axis_cartesian_tvalid : STD_LOGIC;
    signal s_axis_cartesian_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0) := (others => '0');
    signal s_tuser_r : STD_LOGIC_VECTOR (0 downto 0);
    signal s_tvalid_r : std_logic;
    signal m_axis_dout_tvalid : STD_LOGIC;
    signal m_axis_dout_tdata : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axis_rssi_tdata : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
    signal m_axis_rssi_tvalid : STD_LOGIC;
    signal gain_tdata : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');

    signal gain_data : STD_LOGIC_VECTOR (47 downto 0) := (others => '0');
    signal rssi_max : STD_LOGIC_VECTOR (31 downto 0) := x"10000000";
    signal rssi_max_fast : STD_LOGIC_VECTOR (31 downto 0) := x"20000000";
    signal rssi_min : STD_LOGIC_VECTOR (31 downto 0) := x"10000000";
    signal rssi_min_fast : STD_LOGIC_VECTOR (31 downto 0) := x"20000000";
    signal wr_addr : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal rd_addr : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
    signal rssi_rd : STD_LOGIC_VECTOR (31 downto 0);
    signal rssi_max_value : STD_LOGIC_VECTOR (31 downto 0) := (others => '0');
--    signal rssi_max_valid : STD_LOGIC := '1';
    signal agc_on : STD_LOGIC := '1';
    signal rf_gain : STD_LOGIC_VECTOR (15 downto 0) := x"0020";
    signal rf_gain_old : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
    
    signal gain : signed (17 downto 0) := (others => '0');
    signal gain_inc : signed (15 downto 0) := x"0001";
    signal gain_dec : signed (15 downto 0) := x"0001";
    signal gain_inc_fast : signed (15 downto 0) := x"0002";
    signal gain_dec_fast : signed (15 downto 0) := x"0002";
    
    -- Новые сигналы для разгрузки таймингов (конвейер АРУ)
    signal rssi_gt_max_fast : std_logic := '0';
    signal rssi_gt_max      : std_logic := '0';
    signal rssi_lt_min_fast : std_logic := '0';
    signal rssi_lt_min      : std_logic := '0';
    
    -- Регистр для хранения настроек времени удержания (задается из PS)
    signal agc_hold_cfg : unsigned(15 downto 0) := x"0064"; -- по умолчанию 100 тактов    
    -- Текущий счетчик тактов удержания
    signal hold_counter : unsigned(15 downto 0) := (others => '0');    
    -- Разрешение на увеличение усиления
    signal gain_inc_allowed : std_logic := '0';

begin

--    gain_data <= s_axis_tdata * gain(17 downto 2);   

    
cmd_process : process (aclk) is
begin 
   if rising_edge(aclk) then
        if cfg_wr = '1' then 
            if cfg_addra = "000" then
                rf_gain <= cfg_dina(15 downto 0); 
            elsif cfg_addra = "001" then
                agc_on <= cfg_dina(0);    
                agc_hold_cfg <= unsigned(cfg_dina(31 downto 16)); 
            elsif cfg_addra = "010" then
                rssi_max <= cfg_dina;
            elsif cfg_addra = "011" then
                rssi_max_fast <= cfg_dina;      
            elsif cfg_addra = "100" then
                rssi_min <= cfg_dina;     
            elsif cfg_addra = "101" then
                rssi_min_fast <= cfg_dina; 
            elsif cfg_addra = "110" then
                gain_inc_fast <= signed(cfg_dina(31 downto 16)); 
                gain_inc <= signed(cfg_dina(15 downto 0)); 
            elsif cfg_addra = "111" then
                gain_dec_fast <= signed(cfg_dina(31 downto 16)); 
                gain_dec <= signed(cfg_dina(15 downto 0)); 
            end if; 
        end if;
   end if;
end process cmd_process;

process(aclk)
begin
	if rising_edge(aclk) then	
	    s_tvalid_r <= s_axis_tvalid;
        s_tuser_r <= s_axis_tuser;
		if s_axis_tvalid = '1' then
		    gain_data <= std_logic_vector(signed(s_axis_tdata) * signed(gain(17 downto 2)));          
		end if;  
	end if;
end process;

process(aclk)
begin
	if rising_edge(aclk) then	
	    s_axis_cartesian_tvalid <= '0';	
		if s_tvalid_r = '1' then
		    if s_tuser_r = "0" then				   		
			    s_axis_cartesian_tdata(31 downto 0) <= gain_tdata(31) & gain_tdata(31 downto 1);  
			else
			    s_axis_cartesian_tdata(63 downto 32) <= gain_tdata(31) & gain_tdata(31 downto 1);
			    s_axis_cartesian_tvalid <= '1';
			end if;    	           
		end if;  
	end if;
end process;

rssi_0 : cordic_rssi
    PORT MAP(
        aclk => aclk,
        s_axis_cartesian_tvalid => s_axis_cartesian_tvalid,
        s_axis_cartesian_tdata => s_axis_cartesian_tdata,
        m_axis_dout_tvalid => m_axis_dout_tvalid,
        m_axis_dout_tdata => m_axis_dout_tdata
    );
    
process(aclk)
begin
    if rising_edge(aclk) then
        if m_axis_dout_tvalid = '1' then
            -- 1 такт: берем модуль значения
            m_axis_rssi_tdata     <= std_logic_vector(abs(signed(m_axis_dout_tdata(31 downto 0))));
            m_axis_rssi_tvalid    <= '1';
        else
            m_axis_rssi_tvalid    <= '0';
        end if;
    end if;
end process;

max_tree_inst : ram_max_finder
        GENERIC MAP (
            DATA_WIDTH  => 32,
            WINDOW_SIZE => 64
        )
        PORT MAP (
            aclk           => aclk,
            data_in        => m_axis_rssi_tdata,
            data_in_valid  => m_axis_rssi_tvalid,
            max_out        => rssi_max_value,
            max_out_valid  => open
        );
    
--    m_axis_rssi_tdata <= std_logic_vector(abs(signed(m_axis_dout_tdata(31 downto 0)))); 
    m_axis_tdata <= gain_tdata;
    
process(aclk)
begin
    if rising_edge(aclk) then
        -- Выполняем сравнения на такт раньше и сохраняем в однобитные триггеры
        if m_axis_rssi_tdata > rssi_max_fast then rssi_gt_max_fast <= '1'; else rssi_gt_max_fast <= '0'; end if;
        if m_axis_rssi_tdata > rssi_max      then rssi_gt_max <= '1';      else rssi_gt_max <= '0';      end if;
        if rssi_max_value < rssi_min_fast    then rssi_lt_min_fast <= '1'; else rssi_lt_min_fast <= '0'; end if;
        if rssi_max_value < rssi_min         then rssi_lt_min <= '1';      else rssi_lt_min <= '0';      end if;
    end if;
end process;

hold_timer_process : process (aclk) is
begin
    if rising_edge(aclk) then
        -- Если сигнал в норме или превышен, сбрасываем таймер удержания
        if (rssi_gt_max = '1') or (rssi_gt_max_fast = '1') or (rssi_lt_min = '0') then
            hold_counter     <= (others => '0');
            gain_inc_allowed <= '0';
        else
            -- Если сигнал стабильно слабый, считаем такты
            if hold_counter < agc_hold_cfg then
                hold_counter     <= hold_counter + 1;
                gain_inc_allowed <= '0';
            else
                -- Время удержания истекло, разрешаем поднять Gain
                gain_inc_allowed <= '1';
            end if;
        end if;
    end if;
end process hold_timer_process;

agc_process : process (aclk) is
begin
    if rising_edge(aclk) then
        m_axis_tvalid <= s_tvalid_r;
        m_axis_tuser <= s_tuser_r;
        
        if s_tvalid_r = '1' then
            if gain_data(47 downto 34) = "11111111111111" or gain_data(47 downto 34) = "00000000000000" then
                gain_tdata <= gain_data(35 downto 4);
                
                if agc_on = '0' then
                    if rf_gain_old /= rf_gain then
                        gain <= signed(rf_gain & "00");
                        rf_gain_old <= rf_gain;
                    end if;
                elsif s_tuser_r = "1" then
                    rf_gain_old <= (others => '0');
                    
                    if (rssi_gt_max_fast = '1') and (gain >= gain_dec_fast) then
                        gain <= gain - gain_dec_fast;
                    elsif (rssi_gt_max = '1') and (gain >= gain_dec) then
                        gain <= gain - gain_dec;
                    else 
                        if gain_inc_allowed = '1' then
                            if (rssi_lt_min_fast = '1') and (gain < ("01" & x"FFFF" - gain_inc_fast)) then
                                gain <= gain + gain_inc_fast;
                            elsif (rssi_lt_min = '1') and (gain < ("01" & x"FFFF" - gain_inc)) then
                                gain <= gain + gain_inc;
                            end if;
                        end if;
                    end if;
                end if;
            else
                gain <= "000" & gain(17 downto 3);
                
                if gain_data(47) = '0' then
                    gain_tdata <= x"7FFFFFFF";
                else
                    gain_tdata <= x"80000000";
                end if;
            end if;
        end if;
    end if;
end process agc_process;

end Behavioral;
