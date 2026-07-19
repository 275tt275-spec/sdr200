library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity ram_max_finder is
    port (
        aclk           : in  std_logic;
        data_in        : in  std_logic_vector(31 downto 0);
        data_in_valid  : in  std_logic;
        max_out        : out std_logic_vector(31 downto 0);
        max_out_valid  : out std_logic
    );
end ram_max_finder;

architecture Behavioral of ram_max_finder is
    -- Адреса кольцевого буфера
    signal wr_addr     : unsigned(5 downto 0) := (others => '0');
    signal rd_addr     : unsigned(5 downto 0) := (others => '0');
    
    -- Промежуточные сигналы типа std_logic_vector для адресов RAM
    signal wr_addr_vec : std_logic_vector(5 downto 0);
    signal rd_addr_vec : std_logic_vector(5 downto 0);
    
    -- Сигналы памяти
    signal ram_data_out : std_logic_vector(31 downto 0);
    signal current_max  : unsigned(31 downto 0) := (others => '0');
    signal valid_reg    : std_logic := '0';
begin

    -- Присваиваем векторы (теперь Vivado сможет проиндексировать каждый бит без ошибок)
    wr_addr_vec <= std_logic_vector(wr_addr);
    rd_addr_vec <= std_logic_vector(rd_addr);

    -- Генерируем 32 параллельных примитива RAM64X1D
    ram_gen : for i in 0 to 31 generate
        RAM64X1D_inst : RAM64X1D
        port map (
            DPO   => ram_data_out(i), 
            SPO   => open,
            A0    => wr_addr_vec(0), -- Ошибка ушла: индексируем чистый вектор
            A1    => wr_addr_vec(1),
            A2    => wr_addr_vec(2),
            A3    => wr_addr_vec(3),
            A4    => wr_addr_vec(4),
            A5    => wr_addr_vec(5),
            D     => data_in(i),                   
            DPRA0 => rd_addr_vec(0), 
            DPRA1 => rd_addr_vec(1),
            DPRA2 => rd_addr_vec(2),
            DPRA3 => rd_addr_vec(3),
            DPRA4 => rd_addr_vec(4),
            DPRA5 => rd_addr_vec(5),
            WCLK  => aclk,
            WE    => data_in_valid
        );
    end generate;

    -- Логика слежения за максимумом
    process(aclk)
    begin
        if rising_edge(aclk) then
            if data_in_valid = '1' then
                wr_addr <= wr_addr + 1;
                rd_addr <= wr_addr + 2; 

                if unsigned(data_in) >= current_max then
                    current_max <= unsigned(data_in);
                elsif current_max = unsigned(ram_data_out) then
                    current_max <= unsigned(data_in);
                end if;
                
                valid_reg <= '1';
            else
                valid_reg <= '0';
            end if;
        end if;
    end process;

    max_out       <= std_logic_vector(current_max);
    max_out_valid <= valid_reg;

end Behavioral;
