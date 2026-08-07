----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.08.2026 10:13:48
-- Design Name: 
-- Module Name: lcd_dctrl - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity lcd_dctrl_en is
     Port ( 
        clk : in STD_LOGIC;
        lcd_en : out STD_LOGIC; 
        lcd_dctrl : out STD_LOGIC
     );
end lcd_dctrl_en;

architecture Behavioral of lcd_dctrl_en is

    -- 1. Расчет базовой частоты ШИМ (200 Гц)
    -- Период ШИМ = 1 / 200 Гц = 5,000,000 нс.
    -- При тактовой частоте 100 МГц (такт = 10 нс) полный период ШИМ равен: 
    -- 5,000,000 нс / 10 нс = 500,000 тактов.
    constant PWM_PERIOD : integer := 500000;
    
    -- Счетчик для формирования периода ШИМ (от 0 до 499,999)
    signal pwm_counter : integer range 0 to PWM_PERIOD - 1 := 0;

    -- 2. Управление яркостью (Разрядность задает плавность)
    -- Возьмем 8-битное разрешение (0-255 уровней яркости).
    -- Шаг изменения скважности = PWM_PERIOD / 256 = 500000 / 256 = 1953 такта на один шаг.
    signal brightness : unsigned(7 downto 0) := x"80"; -- Начальное значение: 128 (50% яркости)
    
    -- Порог переключения (скважность), вычисляемый динамически
    signal duty_cycle_limit : integer range 0 to PWM_PERIOD := 0;
    
begin

    -- Постоянно держим LCD включенным (или привяжите к вашей внутренней логике)
    lcd_en <= '1'; 

    -- Вычисление порога скважности (яркость * шагов_на_уровень)
    -- Умножение на константу оптимизируется синтезатором в сдвиги и сложения
    duty_cycle_limit <= to_integer(brightness) * 1953;
    
process(clk)
    begin
        if rising_edge(clk) then
            -- Основной счетчик ШИМ-периода
            if pwm_counter < PWM_PERIOD - 1 then
                pwm_counter <= pwm_counter + 1;
            else
                pwm_counter <= 0;
            end if;

            -- Формирование ШИМ-сигнала на выходе dctrl
            if pwm_counter < duty_cycle_limit then
                lcd_dctrl <= '1'; -- Сигнал активен (диоды горят)
            else
                lcd_dctrl <= '0'; -- Сигнал пассивен
            end if;
        end if;
    end process;

end Behavioral;
