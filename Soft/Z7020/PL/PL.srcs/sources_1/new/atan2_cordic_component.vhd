library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL; -- Используется для генерации констант arctan на этапе синтеза

entity atan2_cordic is
    generic (
        DATA_WIDTH  : natural := 16; -- Разрядность входных I/Q
        ANGLE_WIDTH : natural := 16; -- Разрядность выходного угла
        ITERATIONS  : natural := 14  -- Количество итераций (точность)
    );
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        i_in    : in  SIGNED (DATA_WIDTH - 1 downto 0); -- Вход X (R)
        q_in    : in  SIGNED (DATA_WIDTH - 1 downto 0); -- Вход Y (X)
        angle_out : out SIGNED (ANGLE_WIDTH - 1 downto 0) -- Выход Z (угол atan2)
    );
end atan2_cordic;

architecture arch of atan2_cordic is

    -- Типы для массивов сигналов для конвейерной обработки
    type fixed_point_array is array (0 to ITERATIONS) of SIGNED (DATA_WIDTH downto 0);
    type angle_array is array (0 to ITERATIONS) of SIGNED (ANGLE_WIDTH downto 0);

    signal x, y : fixed_point_array;
    signal z    : angle_array; -- Угол аккумулируется здесь

    -- Предрассчитанные константы atan(2^-i) для CORDIC (используется MATH_REAL)
    function calculate_atan_constants (iterations_g : natural) return angle_array is
        variable result : angle_array;
    begin
        for i in 0 to iterations_g - 1 loop
            -- Константы должны быть в формате фиксированной точки
            -- Примерное преобразование (нужно адаптировать под ваш формат):
            result(i) := to_signed(integer(round(arctan(2.0**(-real(i))) * (2.0**(ANGLE_WIDTH-2)) / MATH_PI_OVER_2)), ANGLE_WIDTH);
        end loop;
        return result;
    end function calculate_atan_constants;

    constant atan_table : angle_array := calculate_atan_constants(ITERATIONS);

begin

    -- Инициализация первого каскада
    x(0) <= resize(i_in, DATA_WIDTH + 1);
    y(0) <= resize(q_in, DATA_WIDTH + 1);
    z(0) <= (others => '0'); -- Начальный угол 0

    -- Генерация итераций CORDIC (конвейерная реализация, 1 такт на итерацию в симуляции)
    CORDIC_STAGES: for i in 0 to ITERATIONS - 1 generate
        signal direction : STD_LOGIC; -- Направление вращения (определяется знаком Y)
    begin
        direction <= '1' when y(i) < 0 else '0'; -- Если Y отрицателен, вращаем против часовой стрелки

        process(clk, reset)
        begin
            if reset = '1' then
                x(i+1) <= (others => '0');
                y(i+1) <= (others => '0');
                z(i+1) <= (others => '0');
            elsif rising_edge(clk) then
                -- Основные операции CORDIC: сдвиг и сложение/вычитание
                if direction = '1' then
                    -- Вращение против часовой стрелки
                    x(i+1) <= x(i) + shift_right(y(i), i);
                    y(i+1) <= y(i) - shift_right(x(i), i);
                    z(i+1) <= z(i) - atan_table(i);
                else
                    -- Вращение по часовой стрелке
                    x(i+1) <= x(i) - shift_right(y(i), i);
                    y(i+1) <= y(i) + shift_right(x(i), i);
                    z(i+1) <= z(i) + atan_table(i);
                end if;
            end if;
        end process;
    end generate CORDIC_STAGES;

    -- Выходной угол берется из последнего каскада
    -- Может потребоваться масштабирование или постобработка, т.к. CORDIC имеет коэффициент усиления
    angle_out <= resize(z(ITERATIONS), ANGLE_WIDTH);

end arch;