----------------------------------------------------------------------------------
-- Create Date:    18:00:47 06/29/2010 
-- Module Name:    corr_measure - Behavioral 
--
-- addr			       WR                   RD
--  00       reset byte_cnt, latch I, Q   read byte (one from 17) from latch
--  01       write byte (one from 17)     read byte (one from 17) from latch
--  10   	 write K (bits 2 dowto 0)
--  							
-- 
-- K: 0=17 shifts, ..., 6=23 shifts
-- 
-- Write byte order: I_lsb, ..., I_msb, Q_lsb, ..., Q_msb, PHI_lsb, ..., PHI_msb 
--                        7 bytes          7 bytes        3 bytes (actually, 18 bits)
-- Read byte order: I_lsb, ..., I_msb, Q_lsb, ..., Q_msb, PHI_lsb, ..., PHI_msb
--                       7 bytes          7 bytes         3 bytes (actually, 18 bits)
-- PHI - normalized (20000...1FFFF)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;


entity corr_measure is
    Port ( i1 : in  STD_LOGIC_VECTOR (15 downto 0);
           q1 : in  STD_LOGIC_VECTOR (15 downto 0);
           i2 : in  STD_LOGIC_VECTOR (15 downto 0);
           q2 : in  STD_LOGIC_VECTOR (15 downto 0);
           clk : in  STD_LOGIC;
           ce : in  STD_LOGIC;
           clr : in  STD_LOGIC;
           din : in  STD_LOGIC_VECTOR (7 downto 0);
           addr : in  STD_LOGIC_VECTOR (1 downto 0);
			  rd : in  STD_LOGIC;
			  wr : in  STD_LOGIC;
			  cs : in  STD_LOGIC;
			  slow : in  STD_LOGIC;
           dout : out  STD_LOGIC_VECTOR (7 downto 0);
           phi_out : OUT  std_logic_vector(17 downto 0)	-- phase -1..+1
			 );
end corr_measure;

architecture Behavioral of corr_measure is
COMPONENT m1_31
	PORT(
		a1 : IN std_logic_vector(17 downto 0);
		b1 : IN std_logic_vector(17 downto 0);
		a2 : IN std_logic_vector(17 downto 0);
		b2 : IN std_logic_vector(17 downto 0);
		op_minus : IN std_logic;
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;          
		dout : OUT std_logic_vector(30 downto 0)
		);
	END COMPONENT;

--component corr_atn
--	port (
--	x_in: IN std_logic_VECTOR(16 downto 0);
--	y_in: IN std_logic_VECTOR(16 downto 0);
--	phase_out: OUT std_logic_VECTOR(17 downto 0);
--	clk: IN std_logic;
--	ce: IN std_logic;
--	sclr: IN std_logic
--	);
--end component;

COMPONENT corr_atn
  PORT (
    aclk : IN STD_LOGIC;
    aclken : IN STD_LOGIC;
    aresetn : IN STD_LOGIC;
    s_axis_cartesian_tvalid : IN STD_LOGIC;
    s_axis_cartesian_tdata : IN STD_LOGIC_VECTOR(47 DOWNTO 0);
    m_axis_dout_tvalid : OUT STD_LOGIC;
    m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
  );
END COMPONENT;
signal i1_18, q1_18, i2_18, q2_18, phi : std_logic_vector(17 downto 0);
signal di_1Q15, dq_1Q15 : std_logic_vector(16 downto 0);
signal dout_i, dout_q : std_logic_vector(30 downto 0);

signal acc_i, acc_q, dif_i, dif_q, set_i, set_q, latch_i, latch_q: std_logic_vector(55 downto 0) := (others => '0');
signal tmp_i, tmp_q: std_logic_vector(55 downto 0) := (others => '0');
signal d_i_56, d_q_56 : std_logic_vector(55 downto 0);
signal kreg : std_logic_vector(2 downto 0):= "101";
signal byte_cnt : std_logic_vector(4 downto 0):= (others => '0');
signal wr_accs, prev_rd, prev_wr : std_logic := '0';
signal rds, wrs : std_logic := '0';
signal norm24_i, norm24_q: std_logic_vector(23 downto 0) := (others => '0');
signal norm_i, norm_q: std_logic_vector(15 downto 0) := (others => '0');
signal latch_phi, set_phi, phi_norm : std_logic_vector(17 downto 0) := (others => '0');
signal phi_acc, phi_dif: std_logic_vector(31 downto 0) := (others => '0');
signal m: std_logic_vector(35 downto 0) := (others => '0');

signal in_tdata : std_logic_vector(47 downto 0);
signal out_tdata : std_logic_vector(23 downto 0);
signal aresetn : std_logic;

begin

--
-- sign extend and use 16 lsbs to avoid overflow in adder/subtractor
--
i1_18 <= i1(15) & i1(15) & i1;
q1_18 <= q1(15) & q1(15) & q1;
i2_18 <= i2(15) & i2(15) & i2;
q2_18 <= q2(15) & q2(15) & q2;

d_i_56 <= dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & 
          dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & 
			 dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & 
			 dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & 
			 dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30) & dout_i(30 downto 0); 
d_q_56 <= dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & 
          dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & 
			 dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & 
			 dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & 
			 dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30) & dout_q(30 downto 0); 

m1_2: m1_31 PORT MAP(
		a1 => i1_18,
		b1 => i2_18,
		a2 => q1_18,
		b2 => q2_18,
		op_minus => '0',
		clk => clk,
		ce => ce,
		clr => clr,
		dout => dout_i
	);

m2_3: m1_31 PORT MAP(
		a1 => i1_18,
		b1 => q2_18,
		a2 => q1_18,
		b2 => i2_18,
		op_minus => '1',
		clk => clk,
		ce => ce,
		clr => clr,
		dout => dout_q
	);

di_1Q15 <= norm_i(15) & norm_i;	-- CORDIC needs 1Q15 number format
dq_1Q15 <= norm_q(15) & norm_q;

--atn : corr_atn
--		port map (
--			x_in => di_1Q15,
--			y_in => dq_1Q15,
--			phase_out => phi,	-- phase has 2Q15 format
--			clk => clk,
--			ce => ce,
--			sclr => clr
--		);

aresetn <= not clr;
in_tdata(23 downto 0) <= "0000000" & di_1Q15;
in_tdata(47 downto 24) <= "0000000" & dq_1Q15;
phi <= out_tdata(17 downto 0);
		
atn : corr_atn
  PORT MAP (
    aclk => clk,
    aclken => ce,
    aresetn => aresetn,
    s_axis_cartesian_tvalid => '1',
    s_axis_cartesian_tdata => in_tdata,
    m_axis_dout_tvalid => open,
    m_axis_dout_tdata => out_tdata
  );


dout <= latch_i(7 downto 0)   when byte_cnt = "00000" else
        latch_i(15 downto 8)  when byte_cnt = "00001" else
        latch_i(23 downto 16) when byte_cnt = "00010" else
        latch_i(31 downto 24) when byte_cnt = "00011" else
        latch_i(39 downto 32) when byte_cnt = "00100" else
        latch_i(47 downto 40) when byte_cnt = "00101" else
        latch_i(55 downto 48) when byte_cnt = "00110" else
		  latch_q(7 downto 0)   when byte_cnt = "00111" else
        latch_q(15 downto 8)  when byte_cnt = "01000" else
        latch_q(23 downto 16) when byte_cnt = "01001" else
        latch_q(31 downto 24) when byte_cnt = "01010" else
        latch_q(39 downto 32) when byte_cnt = "01011" else
        latch_q(47 downto 40) when byte_cnt = "01100" else
        latch_q(55 downto 48) when byte_cnt = "01101" else
		  latch_phi(7 downto 0) when byte_cnt = "01110" else
        latch_phi(15 downto 8) when byte_cnt = "01111" else
        latch_phi(17) & latch_phi(17) & latch_phi(17) & latch_phi(17) & latch_phi(17) & latch_phi(17) & latch_phi(17 downto 16) ;

phi_out <= phi_acc(31 downto 14);
		  
bus_proc : process(clk)
begin

	if rising_edge(clk) then
		rds <= rd and cs;
		wrs <= wr and cs;

		if wr_accs = '1' then
			wr_accs <= '0';
		end if;

		prev_rd <= rds;
		prev_wr <= wrs;
		if rds = '0' and prev_rd = '1' then
			byte_cnt <= byte_cnt + 1;
		elsif wrs = '1' then
			if addr = "00" then
				byte_cnt <= (others => '0');
				latch_i <= acc_i;
				latch_q <= acc_q;
				latch_phi <= phi_acc(31 downto 14);
			elsif addr = "01" then
				case byte_cnt is
				when "00000" =>
					set_i(7 downto 0) <= din;
				when "00001" =>
					set_i(15 downto 8) <= din;
				when "00010" =>
					set_i(23 downto 16) <= din;
				when "00011" =>
					set_i(31 downto 24) <= din;
				when "00100" =>
					set_i(39 downto 32) <= din;
				when "00101" =>
					set_i(47 downto 40) <= din;
				when "00110" =>
					set_i(55 downto 48) <= din;
				when "00111" =>
					set_q(7 downto 0) <= din;
				when "01000" =>
					set_q(15 downto 8) <= din;
				when "01001" =>
					set_q(23 downto 16) <= din;
				when "01010" =>
					set_q(31 downto 24) <= din;
				when "01011" =>
					set_q(39 downto 32) <= din;
				when "01100" =>
					set_q(47 downto 40) <= din;
				when "01101" =>
					set_q(55 downto 48) <= din;
				when "01110" =>
					set_phi(7 downto 0) <= din;
				when "01111" =>
					set_phi(15 downto 8) <= din;
				when "10000" =>
					set_phi(17 downto 16) <= din(1 downto 0);
					wr_accs <= '1';
				when others =>
					null;
				end case;
			elsif addr = "10" then
				kreg <= din(2 downto 0);
			end if;
		elsif wrs = '0' and prev_wr = '1' and addr = "01" then
			byte_cnt <= byte_cnt + 1;
		end if;
	end if;
end process bus_proc;

proc : process(clk)
begin

	if rising_edge(clk) then
		if clr = '1' then
			acc_i <= (others => '0');
			acc_q <= (others => '0');
			dif_i <= (others => '0');
			dif_q <= (others => '0');
			tmp_i <= (others => '0');
			tmp_q <= (others => '0');
		else
			if ce = '1' then
				case kreg is
				when "000" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55 downto 17);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55 downto 17);
				when "001" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55 downto 18);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55 downto 18);
				when "010" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55 downto 19);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55 downto 19);
				when "011" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55 downto 20);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55 downto 20);
				when "100" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55 downto 21);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55 downto 21);
				when "101" =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55 downto 22);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55 downto 22);
				when others =>
					dif_i <= acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
					         acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55) & 
								acc_i(55) & acc_i(55) & acc_i(55) & acc_i(55 downto 23);
					dif_q <= acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
					         acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55) & 
								acc_q(55) & acc_q(55) & acc_q(55) & acc_q(55 downto 23);
				end case;
				
				tmp_i <= d_i_56 - dif_i; -- 11.10.2010
				tmp_q <= d_q_56 - dif_q;
				
				if wr_accs = '1' then
					acc_i <= set_i;
					acc_q <= set_q;
				else
-- 11.10.2010					acc_i <= acc_i + d_i_56 - dif_i;
-- 11.10.2010					acc_q <= acc_q + d_q_56 - dif_q;
					acc_i <= acc_i + tmp_i;
					acc_q <= acc_q + tmp_q;
				end if;
--
-- Normalization
--
-- 1st stage - from 56 to 24 bits
				if (acc_i(55 downto 47) /= "000000000" and acc_i(55 downto 47) /= "111111111") or 
				   (acc_q(55 downto 47) /= "000000000" and acc_q(55 downto 47) /= "111111111") then
					norm24_i <= acc_i(55 downto 32);
					norm24_q <= acc_q(55 downto 32);
				elsif (acc_i(47 downto 39) /= "000000000" and acc_i(47 downto 39) /= "111111111") or 
				      (acc_q(47 downto 39) /= "000000000" and acc_q(47 downto 39) /= "111111111") then
					norm24_i <= acc_i(47 downto 24);
					norm24_q <= acc_q(47 downto 24);
				elsif (acc_i(39 downto 31) /= "000000000" and acc_i(39 downto 31) /= "111111111") or 
				      (acc_q(39 downto 31) /= "000000000" and acc_q(39 downto 31) /= "111111111") then
					norm24_i <= acc_i(39 downto 16);
					norm24_q <= acc_q(39 downto 16);
				elsif (acc_i(31 downto 23) /= "000000000" and acc_i(31 downto 23) /= "111111111") or 
				      (acc_q(31 downto 23) /= "000000000" and acc_q(31 downto 23) /= "111111111") then
					norm24_i <= acc_i(31 downto 8);
					norm24_q <= acc_q(31 downto 8);
				else
					norm24_i <= acc_i(23 downto 0);
					norm24_q <= acc_q(23 downto 0);
				end if;
				
-- 2nd stage - from 24 to 16 bits
				if (norm24_i(23 downto 22) /= "00" and norm24_i(23 downto 22) /= "11") or
				   (norm24_q(23 downto 22) /= "00" and norm24_q(23 downto 22) /= "11") then
					norm_i <= norm24_i(23 downto 8);
					norm_q <= norm24_q(23 downto 8);
				elsif (norm24_i(22 downto 21) /= "00" and norm24_i(22 downto 21) /= "11") or
				      (norm24_q(22 downto 21) /= "00" and norm24_q(22 downto 21) /= "11") then
					norm_i <= norm24_i(22 downto 7);
					norm_q <= norm24_q(22 downto 7);
				elsif (norm24_i(21 downto 20) /= "00" and norm24_i(21 downto 20) /= "11") or
				      (norm24_q(21 downto 20) /= "00" and norm24_q(21 downto 20) /= "11") then
					norm_i <= norm24_i(21 downto 6);
					norm_q <= norm24_q(21 downto 6);
				elsif (norm24_i(20 downto 19) /= "00" and norm24_i(20 downto 19) /= "11") or
				      (norm24_q(20 downto 19) /= "00" and norm24_q(20 downto 19) /= "11") then
					norm_i <= norm24_i(20 downto 5);
					norm_q <= norm24_q(20 downto 5);
				elsif (norm24_i(19 downto 18) /= "00" and norm24_i(19 downto 18) /= "11") or
				      (norm24_q(19 downto 18) /= "00" and norm24_q(19 downto 18) /= "11") then
					norm_i <= norm24_i(19 downto 4);
					norm_q <= norm24_q(19 downto 4);
				elsif (norm24_i(18 downto 17) /= "00" and norm24_i(18 downto 17) /= "11") or
				      (norm24_q(18 downto 17) /= "00" and norm24_q(18 downto 17) /= "11") then
					norm_i <= norm24_i(18 downto 3);
					norm_q <= norm24_q(18 downto 3);
				elsif (norm24_i(17 downto 16) /= "00" and norm24_i(17 downto 16) /= "11") or
				      (norm24_q(17 downto 16) /= "00" and norm24_q(17 downto 16) /= "11") then
					norm_i <= norm24_i(17 downto 2);
					norm_q <= norm24_q(17 downto 2);
				elsif (norm24_i(16 downto 15) /= "00" and norm24_i(16 downto 15) /= "11") or
				      (norm24_q(16 downto 15) /= "00" and norm24_q(16 downto 15) /= "11") then
					norm_i <= norm24_i(16 downto 1);
					norm_q <= norm24_q(16 downto 1);
				else
					norm_i <= norm24_i(15 downto 0);
					norm_q <= norm24_q(15 downto 0);
				end if;

-- Normalize angle from 2Q15 -pi..+pi to 18 bit -1..+1 				
				m <= phi * ("01" & x"45f2");
--				phi_norm <= m(33 downto 16);
--				phi_dif <= phi_norm - phi_acc;
				phi_dif <= m(33 downto 2) - phi_acc;
				if wr_accs = '1' then
					phi_acc <= set_phi & "00000000000000";
				else
--					if slow = '0' then
--						phi_acc <= phi_acc + (  phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
--														phi_dif(31) & phi_dif(31) & phi_dif(31 downto 6)); --phy acc=phi hld k=1/64
--					else
--						phi_acc <= phi_acc + ( 	phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
--														phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
--														phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
--														phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31 downto 16)); --phy acc=phi hld k=1/65536
					if slow = '0' then
						phi_acc <= phi_acc + (  phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
						                        phi_dif(31 downto 4)); 											--phy acc=phi hld k=1/16
					else
						phi_acc <= phi_acc + ( 	phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
														phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
														phi_dif(31) & phi_dif(31) & phi_dif(31) & phi_dif(31) & 
														phi_dif(31) & phi_dif(31) & phi_dif(31 downto 14));   --phy acc=phi hld k=1/16384
					end if;
				end if;
				
			end if;	-- ce
		end if; -- clr
		
	end if; -- clk
end process proc;

end Behavioral;

