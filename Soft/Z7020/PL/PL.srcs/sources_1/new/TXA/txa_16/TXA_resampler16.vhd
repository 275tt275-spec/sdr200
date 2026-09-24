

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use ieee.std_logic_signed.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TXA_resampler16 is
    Port ( 
        m_i_data : out STD_LOGIC_VECTOR (17 downto 0);
        m_q_data : out STD_LOGIC_VECTOR (17 downto 0);
        s_axis_modulator_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_modulator_tready : out STD_LOGIC;
        s_axis_modulator_tvalid : in STD_LOGIC;
        gain : in STD_LOGIC_VECTOR (17 downto 0);              -- := "00" & x"7FFF";   100%
        out_over : out STD_LOGIC;
        aresetn : in STD_LOGIC;
        aclk : in STD_LOGIC
    );
end TXA_resampler16;

architecture Behavioral of TXA_resampler16 is

   component fir_duc_inter5_16 is
        port (
            aclk : in STD_LOGIC;
            s_axis_data_tvalid : in STD_LOGIC;
            s_axis_data_tready : out STD_LOGIC;
            s_axis_data_tdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
            m_axis_data_tvalid : out STD_LOGIC;
            m_axis_data_tready : in STD_LOGIC;
            m_axis_data_tdata : out STD_LOGIC_VECTOR ( 47 downto 0 )
        );
    end component fir_duc_inter5_16;
    
   component fir_duc_ciccomp is
        port (
            aclk : in STD_LOGIC;
            s_axis_data_tvalid : in STD_LOGIC;
            s_axis_data_tready : out STD_LOGIC;
            s_axis_data_tdata : in STD_LOGIC_VECTOR ( 47 downto 0);
            m_axis_data_tvalid : out STD_LOGIC;
            m_axis_data_tready : in STD_LOGIC;
            m_axis_data_tdata : out STD_LOGIC_VECTOR ( 47 downto 0 )
        );
    end component fir_duc_ciccomp;
    
    component cic_txa IS
    port (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_data_tdata : IN STD_LOGIC_VECTOR(23 DOWNTO 0);
        s_axis_data_tvalid : IN STD_LOGIC;
        s_axis_data_tready : OUT STD_LOGIC;
        m_axis_data_tdata : OUT STD_LOGIC_VECTOR(79 DOWNTO 0);
        m_axis_data_tvalid : OUT STD_LOGIC
    );
    end component cic_txa;
    
    signal interpolator_tdata   : std_logic_vector(47 downto 0);
    signal interpolator_tvalid  : std_logic;
    signal interpolator_tready  : std_logic;
    signal cic_in_tdata         : std_logic_vector(47 downto 0);
    signal cic_in_tvalid        : std_logic;
    signal cic_in_tready        : std_logic;
    signal cic_in_tready_0      : std_logic;
    signal cic_in_tready_1      : std_logic;
    
    -- Сигналы для подключения Full Precision выходов CIC
    signal cic_out_tdata_0      : std_logic_vector(79 downto 0);
    signal cic_out_tdata_1      : std_logic_vector(79 downto 0);
    signal cic_out_tvalid_0     : std_logic;
    signal cic_out_tvalid_1     : std_logic;

    -- Промежуточные регистры чистых 24-битных сигналов после первого округления
    signal cic_pre_round_i      : signed(23 downto 0) := (others => '0');
    signal cic_pre_round_q      : signed(23 downto 0) := (others => '0');

    signal i_out_reg            : std_logic_vector(17 downto 0) := (others => '0');
    signal q_out_reg            : std_logic_vector(17 downto 0) := (others => '0');

begin
    
fir_interpolator: component fir_duc_inter5_16
    port map (
        aclk               => aclk,
        m_axis_data_tdata  => interpolator_tdata,
        m_axis_data_tvalid => interpolator_tvalid,
        m_axis_data_tready => interpolator_tready,
        s_axis_data_tdata  => s_axis_modulator_tdata,
        s_axis_data_tready => s_axis_modulator_tready,
        s_axis_data_tvalid => s_axis_modulator_tvalid
    );
    
fir_ciccomp: component fir_duc_ciccomp
    port map (
        aclk               => aclk,
        m_axis_data_tdata  => cic_in_tdata,
        m_axis_data_tready => cic_in_tready,
        m_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tdata  => interpolator_tdata,
        s_axis_data_tready => interpolator_tready,
        s_axis_data_tvalid => interpolator_tvalid
    );
    
    cic_in_tready <= cic_in_tready_0 and cic_in_tready_1;
    
txa_cic_0 : cic_txa
    PORT MAP (
        aclk               => aclk,
        aresetn            => aresetn,
        s_axis_data_tdata  => cic_in_tdata(23 downto 0),
        s_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tready => cic_in_tready_0,
        m_axis_data_tdata  => cic_out_tdata_0,
        m_axis_data_tvalid => cic_out_tvalid_0
    );
    
txa_cic_1 : cic_txa
    PORT MAP (
        aclk               => aclk,
        aresetn            => aresetn,
        s_axis_data_tdata  => cic_in_tdata(47 downto 24),
        s_axis_data_tvalid => cic_in_tvalid,
        s_axis_data_tready => cic_in_tready_1,
        m_axis_data_tdata  => cic_out_tdata_1,
        m_axis_data_tvalid => cic_out_tvalid_1
    );

----------------------------------------------------------------------------------
-- Двухстадийный прецизионный конвейер вычислений
----------------------------------------------------------------------------------
process(aclk)
    -- Переменные Стадии 1 (Округление CIC 77 -> 24 бит)
    variable i_cic_val       : signed(76 downto 0);
    variable q_cic_val       : signed(76 downto 0);
    variable i_cic_ext       : signed(77 downto 0);
    variable q_cic_ext       : signed(77 downto 0);
    constant CIC_ROUND_CONST : signed(77 downto 0) := (52 => '1', others => '0'); -- Единица в 52-й бит
    
    -- Переменные Стадии 2 (Умножение 24x18 и Округление до 18 бит)
    variable i_mult          : signed(41 downto 0);
    variable q_mult          : signed(41 downto 0);
    variable i_round         : signed(42 downto 0); 
    variable q_round         : signed(42 downto 0);
    
    constant MULT_ROUND_CONST: signed(42 downto 0) := (18 => '1', others => '0');
    
    variable ovf_i, ovf_q    : std_logic;
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            cic_pre_round_i <= (others => '0');
            cic_pre_round_q <= (others => '0');
            i_out_reg       <= (others => '0');
            q_out_reg       <= (others => '0');
            out_over        <= '0';
        else
            -- === СТАДИЯ 1: Высокоточное округление 77-битного выхода CIC до 24 бит ===
            if cic_out_tvalid_0 = '1' and cic_out_tvalid_1 = '1' then
                i_cic_val := signed(cic_out_tdata_0(76 downto 0));
                q_cic_val := signed(cic_out_tdata_1(76 downto 0));

                i_cic_ext := resize(i_cic_val, 78) + CIC_ROUND_CONST;
                q_cic_ext := resize(q_cic_val, 78) + CIC_ROUND_CONST;
                
                cic_pre_round_i <= i_cic_ext(76 downto 53);
                cic_pre_round_q <= q_cic_ext(76 downto 53);
            end if;

            -- === СТАДИЯ 2: Масштабирование на Gain, точный срез и контроль насыщения ===
            i_mult := cic_pre_round_i * signed(gain);
            q_mult := cic_pre_round_q * signed(gain);

            i_round := resize(i_mult, 43) + MULT_ROUND_CONST;
            q_round := resize(q_mult, 43) + MULT_ROUND_CONST;

            ovf_i := '0';
            ovf_q := '0';

            if (i_round(42) = '0' and (i_round(41 downto 36) /= (41 downto 36 => '0'))) then
                i_out_reg <= "01" & x"FFFF"; -- Положительное насыщение (x"1FFFF")
                ovf_i     := '1';
            elsif (i_round(42) = '1' and (i_round(41 downto 36) /= (41 downto 36 => '1'))) then
                i_out_reg <= "10" & x"0000"; -- Отрицательное насыщение (x"20000")
                ovf_i     := '1';
            else
                -- ИСПРАВЛЕНО: Забираем идеальный по амплитуде диапазон 18 бит
                i_out_reg <= std_logic_vector(i_round(36 downto 19));
            end if;

            -- Точно такой же контроль для канала Q
            if (q_round(42) = '0' and (q_round(41 downto 36) /= (41 downto 36 => '0'))) then
                q_out_reg <= "01" & x"FFFF";
                ovf_q     := '1';
            elsif (q_round(42) = '1' and (q_round(41 downto 36) /= (41 downto 36 => '1'))) then
                q_out_reg <= "10" & x"0000";
                ovf_q     := '1';
            else
                q_out_reg <= std_logic_vector(q_round(36 downto 19));
            end if;

            out_over <= ovf_i or ovf_q;
        end if;
    end if;
end process;

    m_i_data <= i_out_reg;
    m_q_data <= q_out_reg;

end Behavioral;
