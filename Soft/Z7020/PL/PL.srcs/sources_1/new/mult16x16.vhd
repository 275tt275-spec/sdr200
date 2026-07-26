
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity mult16x16 is
    port (
        aclk            : in  std_logic;
        aresetn         : in  std_logic;
        txa_on          : in  std_logic;
        mult_in_tdata   : in  std_logic_vector(31 downto 0);
        dds_in_tdata    : in  std_logic_vector(47 downto 0);
        dac_tdata       : out std_logic_vector(15 downto 0)
    );
end mult16x16;

architecture Behavioral of mult16x16 is

    component cmpy_16x16r IS
    PORT (
        aclk : IN STD_LOGIC;
        aresetn : IN STD_LOGIC;
        s_axis_a_tvalid : IN STD_LOGIC;
        s_axis_a_tdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        s_axis_b_tvalid : IN STD_LOGIC;
        s_axis_b_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
        s_axis_ctrl_tvalid : IN STD_LOGIC;
        s_axis_ctrl_tdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(47 DOWNTO 0)
    );
    END component cmpy_16x16r;
    
    signal mult_out_tdata : std_logic_vector(47 downto 0) := (others => '0');
    signal mult_i_24    : signed(23 downto 0);
    signal mult_q_24    : signed(23 downto 0);
    signal ctrl_tdata : std_logic_vector(7 downto 0);
    signal lfsr_reg : std_logic_vector(15 downto 0) := x"A5A5"; -- Стартовое число (не 0)
    signal iq_sum_25    : signed(24 downto 0); 
    signal dac_tdata_reg : std_logic_vector(15 downto 0);
    signal scaled_sum_26  : signed(25 downto 0);
    signal dither_val     : signed(25 downto 0);
    signal final_sum_26 : signed(25 downto 0); 

begin

    ctrl_tdata <= "0000000" & lfsr_reg(0);

cmply_0 : cmpy_16x16r
   PORT MAP (
        aclk => aclk,
        aresetn => aresetn,
        s_axis_a_tvalid => '1',
        s_axis_a_tdata  => mult_in_tdata,
        s_axis_b_tvalid => '1',
        s_axis_b_tdata => dds_in_tdata,
        s_axis_ctrl_tvalid => '1',
        s_axis_ctrl_tdata => ctrl_tdata,
        m_axis_dout_tvalid => open,
        m_axis_dout_tdata => mult_out_tdata
    );
    
    -- 1. Разделение каналов
    mult_q_24 <= signed(mult_out_tdata(47 downto 24));
    mult_i_24 <= signed(mult_out_tdata(23 downto 0));

    -- 2. Чистое сложение/вычитание (выдает пик 23170)
    iq_sum_25 <= resize(mult_i_24, 25) - resize(mult_q_24, 25);

    -- 3. Комбинаторное умножение на 1.414 через Shift-and-Add (0 тактов задержки!)
    -- Формула: X + X/4 + X/8 + X/32. Расширяем до 26 бит, чтобы не потерять старший бит знака.
    scaled_sum_26 <= resize(iq_sum_25, 26) + 
                     resize(shift_right(iq_sum_25, 2), 26) + 
                     resize(shift_right(iq_sum_25, 3), 26) + 
                     resize(shift_right(iq_sum_25, 5), 26);
    dither_val <= to_signed(48, 26) when (lfsr_reg(0) = '1') else to_signed(16, 26);
    final_sum_26 <= scaled_sum_26 + dither_val;  
   
process(aclk)
begin
    if rising_edge(aclk) then
        if aresetn = '0' then
            lfsr_reg       <= x"A5A5";
            dac_tdata_reg  <= (others => '0');
        elsif txa_on = '1' then
            
            -------------------------------------------------------------------
            -- ТАКТ 1: Теперь сложение абсолютно корректно (нет DC-смещения!)
            -------------------------------------------------------------------
            lfsr_reg       <= (lfsr_reg(0) xor lfsr_reg(2) xor lfsr_reg(3) xor lfsr_reg(5)) & lfsr_reg(15 downto 1);                  
            
            if (final_sum_26(25 downto 21) /= "00000") and (final_sum_26(25 downto 21) /= "11111") then
                if final_sum_26(25) = '0' then 
                    dac_tdata_reg <= x"7fff"; -- Положительное насыщение (+32767)                
                else
                    dac_tdata_reg <= x"8000"; -- Отрицательное насыщение (-32768)   
                end if;                 
            else
                -- Переполнения нет -> забираем честные, идеально дотянутые 16 бит
                dac_tdata_reg <= std_logic_vector(final_sum_26 (21 downto 6));
            end if;
        else
            dac_tdata_reg <= (others => '0');
        end if;
    end if;
end process;

    dac_tdata <= dac_tdata_reg;

end Behavioral;
