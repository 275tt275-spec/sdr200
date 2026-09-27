library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adc_corr is
  Port (
        aclk         : in std_logic;
        aresetn      : in std_logic;
        adc0_in      : in std_logic_vector(15 downto 0);
        adc1_in      : in std_logic_vector(15 downto 0);
        cfg_addra    : in STD_LOGIC_VECTOR (0 downto 0);
        cfg_dina     : in STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr       : in STD_LOGIC;
        adc0_out     : out std_logic_vector(15 downto 0); -- Задержка 1 такт относительно входа
        adc1_out     : out std_logic_vector(15 downto 0)  -- Задержка 1 такт относительно входа
   );
end adc_corr;

architecture Behavioral of adc_corr is

    -- Регистры конфигурации
    signal reg_gain        : signed(15 downto 0) := x"7FFF";
    signal reg_phase       : signed(15 downto 0) := x"0000";
    signal reg_dc_offset_i : signed(15 downto 0) := x"0000";
    signal reg_dc_offset_q : signed(15 downto 0) := x"0000";
    
    -- Промежуточные регистры конвейера (Latency = 1)
    signal r_i_scaled      : signed(15 downto 0) := (others => '0');
    signal r_q_dc_t1       : signed(16 downto 0) := (others => '0');

begin

    -- Конфигурация (Синхронная)
    p_config : process(aclk)
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                reg_gain        <= x"7FFF"; 
                reg_phase       <= x"0000";
                reg_dc_offset_i <= x"0000";
                reg_dc_offset_q <= x"0000";
            elsif cfg_wr = '1' then
                if cfg_addra = "0" then
                    reg_gain  <= signed(cfg_dina(15 downto 0));
                    reg_phase <= signed(cfg_dina(31 downto 16));
                else
                    reg_dc_offset_i <= signed(cfg_dina(15 downto 0));
                    reg_dc_offset_q <= signed(cfg_dina(31 downto 16));
                end if;
            end if;
        end if;
    end process p_config;

    -- Конвейеризированное ядро вычислений (Latency = 1 такт)
    p_core_pipeline : process(aclk)
        -- Переменные внутри такта
        variable v_i_dc          : signed(16 downto 0);
        variable v_q_dc          : signed(16 downto 0);
        variable v_mul_gain      : signed(32 downto 0);
        
        variable v_mul_phase     : signed(31 downto 0);
        variable v_q_shifted     : signed(31 downto 0);
        variable v_q_sub         : signed(31 downto 0);
        variable v_q_corr        : signed(16 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                r_i_scaled <= (others => '0');
                r_q_dc_t1  <= (others => '0');
                adc0_out   <= (others => '0');
                adc1_out   <= (others => '0');
            else
                ----------------------------------------------------------------
                -- ЭТАП 1: Вычисление Gain (Канал I)
                ----------------------------------------------------------------
                v_i_dc     := resize(signed(adc0_in), 17) - resize(reg_dc_offset_i, 17);
                v_q_dc     := resize(signed(adc1_in), 17) - resize(reg_dc_offset_q, 17);
                
                v_mul_gain := v_i_dc * reg_gain;
                
                -- Записываем в триггер отмасштабированный канал I (с округлением)
                r_i_scaled <= resize(shift_right(v_mul_gain + to_signed(16384, 33), 15), 16);
                -- Задерживаем канал Q на 1 такт для выравнивания с I
                r_q_dc_t1  <= v_q_dc;

                ----------------------------------------------------------------
                -- ЭТАП 2: Высокоточная коррекция фазы (Канал Q)
                ----------------------------------------------------------------
                -- Умножаем r_i_scaled (16 бит) на фазу (16 бит) = 32 бита.
                -- Младшие биты теперь бережно сохраняются!
                v_mul_phase := r_i_scaled * reg_phase;
                
                -- Приводим задержанный Q к тому же масштабу 32 бит (сдвигаем влево на 15 бит)
                v_q_shifted := shift_left(resize(r_q_dc_t1, 32), 15);
                
                -- Вычитаем фазовую утечку в 32-битной сетке
                v_q_sub := v_q_shifted - v_mul_phase;
                
                -- И ТОЛЬКО ТЕПЕРЬ делаем финальное округление и сдвиг всей конструкции назад к 17 битам
                v_q_corr := resize(shift_right(v_q_sub + to_signed(16384, 32), 15), 17);

                -- Выходной порт I 
                adc0_out <= std_logic_vector(r_i_scaled);
                
                -- Выходной порт Q с защитой от переполнения
                if v_q_corr > 32767 then
                    adc1_out <= std_logic_vector(to_signed(32767, 16));
                elsif v_q_corr < -32768 then
                    adc1_out <= std_logic_vector(to_signed(-32768, 16));
                else
                    adc1_out <= std_logic_vector(v_q_corr(15 downto 0));
                end if;
                
            end if;
        end if;
    end process p_core_pipeline;


end Behavioral;
