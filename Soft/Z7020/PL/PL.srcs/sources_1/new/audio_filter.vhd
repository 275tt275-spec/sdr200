library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity audio_filter is
    Port ( 
        aclk          : in  STD_LOGIC;
        aresetn       : in  STD_LOGIC;  -- Добавлен сигнал сброса (активный низкий уровень)
        
        -- Входной AXI4-Stream поток данных
        s_axis_in_tdata   : in  STD_LOGIC_VECTOR (23 downto 0);
        s_axis_in_tvalid  : in  STD_LOGIC;
        
        -- Выходной AXI4-Stream поток данных
        m_axis_out_tdata  : out STD_LOGIC_VECTOR (23 downto 0);
        m_axis_out_tvalid : out STD_LOGIC;
        
        -- Интерфейс конфигурации (загрузка коэффициентов и настроек)
        cfg_addra : in  STD_LOGIC_VECTOR (7 downto 0);
        cfg_dina  : in  STD_LOGIC_VECTOR (31 downto 0);
        cfg_wr    : in  STD_LOGIC
    );
end audio_filter;

architecture Behavioral of audio_filter is

    COMPONENT fir_audio_lp IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tready : OUT STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_reload_tvalid : IN STD_LOGIC;
        s_axis_reload_tready : OUT STD_LOGIC;
        s_axis_reload_tlast : IN STD_LOGIC;
        s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        event_s_reload_tlast_missing : OUT STD_LOGIC;
        event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
    END COMPONENT fir_audio_lp;
    
    COMPONENT fir_audio_hp IS
    PORT (
        aclk : IN STD_LOGIC;
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_config_tvalid : IN STD_LOGIC;
        s_axis_config_tready : OUT STD_LOGIC;
        s_axis_config_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axis_reload_tvalid : IN STD_LOGIC;
        s_axis_reload_tready : OUT STD_LOGIC;
        s_axis_reload_tlast : IN STD_LOGIC;
        s_axis_reload_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        event_s_reload_tlast_missing : OUT STD_LOGIC;
        event_s_reload_tlast_unexpected : OUT STD_LOGIC
    );
    END COMPONENT fir_audio_hp;
    
    COMPONENT axis_shift_sat_round_32to24 is
    port (
        -- Глобальные сигналы тактирования и сброса
        aclk            : in  std_logic;
        aresetn         : in  std_logic; -- Активный низкий уровень
        
        -- Конфигурация величины сдвига влево
        shift           : in  natural; 
        
        -- Интерфейс S_AXIS (Входной поток: 32 бита / 4 байта)
        s_axis_tdata    : in  std_logic_vector(31 downto 0);
        s_axis_tvalid   : in  std_logic;
        s_axis_tready   : out std_logic;
        
        -- Интерфейс M_AXIS (Выходной поток: 24 бита / 3 байта)
        m_axis_tdata    : out std_logic_vector(24 - 1 downto 0);
        m_axis_tvalid   : out std_logic;
        m_axis_tready   : in  std_logic;
        
        -- Флаг переполнения (валиден только при m_axis_tvalid = '1')
        overflow        : out std_logic
    );
    end COMPONENT axis_shift_sat_round_32to24;
    
    -- Константы для управления задержками
    constant DELAY_AFTER_RELOAD : integer := 7680;  -- Задержка после перезагрузки коэффициентов
    
-- Сигналы управления LPF
    signal config_lp_tvalid : STD_LOGIC := '0';
    signal config_lp_tready : STD_LOGIC;
    signal reload_lp_tvalid : STD_LOGIC := '0';
    signal reload_lp_tready : STD_LOGIC;
    
    -- Сигналы управления HPF
    signal config_hp_tvalid : STD_LOGIC := '0';
    signal config_hp_tready : STD_LOGIC;
    signal reload_hp_tvalid : STD_LOGIC := '0';
    signal reload_hp_tready : STD_LOGIC;
    
    -- Общие сигналы конфигурации
    signal config_tdata  : STD_LOGIC_VECTOR(7 DOWNTO 0) := (others => '0');
    signal reload_tdata  : STD_LOGIC_VECTOR(23 DOWNTO 0) := (others => '0');
    signal reload_tlast  : STD_LOGIC := '0';
    
    -- Счетчики коэффициентов (раздельные для LPF и HPF)
    signal idx_lp : integer range 0 to 32 := 0; -- Счетчик текущего коэф. LPF (0-31 значащие, 32 - сброс)
    signal idx_hp : integer range 0 to 64 := 0; -- Счетчик текущего коэф. HPF (0-63 значащие, 64 - сброс)
    
    -- Счетчики задержек после загрузки
    signal delay_count_lp : integer range 0 to DELAY_AFTER_RELOAD := 0;
    signal delay_count_hp : integer range 0 to DELAY_AFTER_RELOAD := 0;
    
    -- Выходные сигналы фильтров
    signal lp_out_tdata  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal lp_out_tvalid : STD_LOGIC;
    signal lp_in_tdata   : STD_LOGIC_VECTOR(23 DOWNTO 0);
    signal lp_in_tvalid  : STD_LOGIC;
    signal hp_out_tdata  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal hp_out_tvalid : STD_LOGIC;
    
    signal lp_shift : integer range 0 to 16 := 6;
    signal hp_shift : integer range 0 to 16 := 6;
     
begin

-- ==============================================
    -- БЛОК УПРАВЛЕНИЯ ЗАГРУЗКОЙ КОЭФФИЦИЕНТОВ
    -- ==============================================
    process(aclk)
    begin
        if rising_edge(aclk) then
            -- Сброс (активный низкий уровень)
            if aresetn = '0' then
                -- Сброс всех управляющих сигналов и счетчиков
                config_lp_tvalid <= '0';
                config_hp_tvalid <= '0';
                reload_lp_tvalid <= '0';
                reload_hp_tvalid <= '0';
                reload_tlast <= '0';
                reload_tdata <= (others => '0');                
                idx_lp <= 0;
                idx_hp <= 0;
                delay_count_lp <= 0;
                delay_count_hp <= 0;                
                lp_shift <= 6;
                hp_shift <= 6;
                                
                config_tdata <= (others => '0');
                
            else
                -- Сброс импульсных сигналов на каждом такте
                reload_lp_tvalid <= '0';
                reload_hp_tvalid <= '0';
                reload_tlast <= '0';
                
                -- ========================================
                -- УПРАВЛЕНИЕ ЗАДЕРЖКАМИ ПОСЛЕ ЗАГРУЗКИ
                -- ========================================
                
                -- Задержка для LPF
                if delay_count_lp > 0 then
                    delay_count_lp <= delay_count_lp - 1;
                    if delay_count_lp = 1 then
                        -- По окончании задержки активируем сигнал конфигурации
                        config_lp_tvalid <= '1';
                    end if;
                elsif config_lp_tready = '1' then
                    config_lp_tvalid <= '0';
                end if;
                
                -- Задержка для HPF
                if delay_count_hp > 0 then
                    delay_count_hp <= delay_count_hp - 1;
                    if delay_count_hp = 1 then
                        -- По окончании задержки активируем сигнал конфигурации
                        config_hp_tvalid <= '1';
                    end if;
                elsif config_hp_tready = '1' then
                    config_hp_tvalid <= '0';
                end if;
                
                -- ========================================
                -- ОБРАБОТКА КОМАНД КОНФИГУРАЦИИ
                -- ========================================
                if cfg_wr = '1' then
                    case cfg_addra is
                        when x"0E" =>  -- Загрузка коэффициентов для LPF
                            reload_tdata <= cfg_dina(23 downto 0);
                            reload_lp_tvalid <= '1';
                            
                            -- Проверка флага принудительного сброса в 31-м бите
                            if cfg_dina(31) = '1' then
                                -- Начинаем новую загрузку
                                idx_lp <= 1;
                            else
                                if idx_lp = 31 then
                                    -- 32-й коэффициент (индекс 31) - последний для симметричного фильтра
                                    -- Устанавливаем tlast и запускаем задержку
                                    reload_tlast <= '1';
                                    delay_count_lp <= DELAY_AFTER_RELOAD;
                                    idx_lp <= 0; -- Сброс индекса для следующей сессии
                                else
                                    idx_lp <= idx_lp + 1;       -- Автоинкремент адреса
                                end if;
                            end if;
                            
                        when x"0F" =>  -- Загрузка коэффициентов для HPF
                            reload_tdata <= cfg_dina(23 downto 0);
                            reload_hp_tvalid <= '1';
                            
                            -- Проверка флага принудительного сброса в 31-м бите
                            if cfg_dina(31) = '1' then
                                idx_hp <= 1; -- Сбрасываем указатель и считаем этот коэф. первым (индекс 1)
                            else
                                if idx_hp = 63 then
                                    reload_tlast   <= '1';              -- Последний коэффициент пакета HPF
                                    delay_count_hp <= DELAY_AFTER_RELOAD; -- Старт таймера применения коэф.
                                    idx_hp         <= 0;                -- Сброс индекса для следующей сессии
                                else
                                    idx_hp         <= idx_hp + 1;       -- Автоинкремент адреса
                                end if;
                            end if;
                            
                        when x"10" =>  -- Настройка коррекции усиления
                            lp_shift <= to_integer(unsigned(cfg_dina));
                            hp_shift <= to_integer(unsigned(cfg_dina));                            
                        when others => null;  -- Игнорируем неизвестные адреса
                    end case;
                end if;
            end if;
        end if;
    end process;
    
audio_hp :  fir_audio_hp
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => s_axis_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => s_axis_in_tdata,
        s_axis_config_tvalid => config_hp_tvalid,
        s_axis_config_tready => config_hp_tready,
        s_axis_config_tdata => config_tdata,
        s_axis_reload_tvalid => reload_hp_tvalid,
        s_axis_reload_tready => reload_hp_tready,
        s_axis_reload_tlast => reload_tlast,
        s_axis_reload_tdata => reload_tdata,
        m_axis_data_tvalid => hp_out_tvalid,
        m_axis_data_tdata => hp_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
 round_hp : axis_shift_sat_round_32to24
    port map (
        aclk => aclk,
        aresetn => aresetn,
        shift => hp_shift,
        s_axis_tdata => hp_out_tdata,
        s_axis_tvalid => hp_out_tvalid,
        s_axis_tready => open,
        m_axis_tdata => lp_in_tdata,
        m_axis_tvalid => lp_in_tvalid,
        m_axis_tready => '1',
        overflow => open
    );
    
audio_lp :  fir_audio_lp
    PORT MAP (
        aclk => aclk,
        s_axis_data_tvalid => lp_in_tvalid,
        s_axis_data_tready => open,
        s_axis_data_tdata => lp_in_tdata,
        s_axis_config_tvalid => config_lp_tvalid,
        s_axis_config_tready => config_lp_tready,
        s_axis_config_tdata => config_tdata,
        s_axis_reload_tvalid => reload_lp_tvalid,
        s_axis_reload_tready => reload_lp_tready,
        s_axis_reload_tlast => reload_tlast,
        s_axis_reload_tdata => reload_tdata,
        m_axis_data_tvalid => lp_out_tvalid,
        m_axis_data_tdata => lp_out_tdata,
        event_s_reload_tlast_missing => open,
        event_s_reload_tlast_unexpected => open
    );
    
round_lp : axis_shift_sat_round_32to24
    port map (
        aclk => aclk,
        aresetn => aresetn,
        shift => lp_shift,
        s_axis_tdata => lp_out_tdata,
        s_axis_tvalid  => lp_out_tvalid,
        s_axis_tready => open,
        m_axis_tdata => m_axis_out_tdata,
        m_axis_tvalid => m_axis_out_tvalid,
        m_axis_tready => '1',
        overflow => open
    );

end Behavioral;
