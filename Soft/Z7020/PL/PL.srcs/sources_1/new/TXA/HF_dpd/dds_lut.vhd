library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity dds_lut is
    Port (
        clk      : in  STD_LOGIC;
        phase    : in  unsigned(7 downto 0);
        sin_out  : out signed(15 downto 0);
        cos_out  : out signed(15 downto 0)
    );
end dds_lut;

architecture Behavioral of dds_lut is
    type lut_array is array (0 to 255) of signed(15 downto 0);
    signal sin_lut, cos_lut : lut_array;
begin
    
    -- Генерация LUT при компиляции
    process
        variable angle : real;
    begin
        for i in 0 to 255 loop
            angle := 2.0 * MATH_PI * real(i) / 256.0;
            sin_lut(i) <= to_signed(integer(round(32767.0 * sin(angle))), 16);
            cos_lut(i) <= to_signed(integer(round(32767.0 * cos(angle))), 16);
        end loop;
        wait; -- Останавливаем процесс после инициализации
    end process;
    
    -- Чтение из LUT
    process(clk)
    begin
        if rising_edge(clk) then
            sin_out <= sin_lut(to_integer(phase));
            cos_out <= cos_lut(to_integer(phase));
        end if;
    end process;
    
end Behavioral;