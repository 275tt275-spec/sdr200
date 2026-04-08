  ----------------------------------------------------------------------------------

-- Create Date:    13:25:29 07/07/2010 

----- PHASE BLOCK
--  addr			       WR                    			RD
--  0058       reset byte_cnt, latch I, Q, PHI   	read byte (one from 17) from latches
--  0059       write byte (one from 17)     		read byte (one from 17) from latches
--  005A	   write K
-- 
-- K: 0=17 shifts, ..., 6=23 shifts
-- 
-- Write byte order: I_lsb, ..., I_msb, Q_lsb, ..., Q_msb, PHI_lsb, ..., PHI_msb 
--                       7 bytes          7 bytes         3 bytes (actually, 18 bits)
-- Read byte order:  I_lsb, ..., I_msb, Q_lsb, ..., Q_msb, PHI_lsb, ..., PHI_msb 
--                       7 bytes          7 bytes         3 bytes (actually, 18 bits)


----- Address space
-- addr
-- 0041  ADC input data left shifts
--       00 - 0 shifts
--       01 - 1 shifts
--       10 - 2 shifts
--       11 - 3 shifts
--  

-- 0042 AGC K (3 bits)
--       000 - 11 shifts  
--       001 - 12 shifts  
--       010 - 13 shifts  
--       011 - 14 shifts  
--       100 - 15 shifts  

----- Output (DAC) DDS signals gain (write only)
-- 0043 gain_I
-- 0044 gain_Q

----- DDS ADC (write only)
-- 0045 ADC DDS

----- ERR corrector (write only)
-- 0046 k_prop  !!! data format is 8Q7 (e.g. range is -256..256) - default is 4
 
-- 004D k_diff - !!! data format is 8Q7 (e.g. range is -256..256) - default is 200
-- 004E stab_control  data format is 0Q15 as usually - default is 0.3
--			kdiff parameter is fixed (0.95)
-- 
----- ADC correction IQ gain (write only)
-- 0047 - ADC correction I gain 
-- 0048 - ADC correction Q gain
--
----- Output DC offsets (write only)
-- 0049 - I DC offset
-- 004A - Q DC offset
-- 
----- Ortho compensate (write only)
-- 004B - sinPHI 
-- 004C - cosPHI

-- NEW!!
-- 004F - (0) - lin_clr, (1) - lin_on, (2) - agc_on, (3) - phase_slow

-- 0040		Read source select
--          WR 0 - AGC K OUT
--			WR 1 - RMS
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_SIGNED.ALL;

entity linear_dds_iq is
    Port ( 
        din1_i : in  STD_LOGIC_VECTOR (23 downto 0);
        din1_q : in  STD_LOGIC_VECTOR (23 downto 0);
        din2 : in  STD_LOGIC_VECTOR (15 downto 0);
        aclk : in  STD_LOGIC;
        ce : in  STD_LOGIC;
        s_axis_cfg_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        s_axis_cfg_tdest : in STD_LOGIC_VECTOR (4 downto 0);
        s_axis_cfg_tvalid : in STD_LOGIC;
        s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
        dout_i : out  STD_LOGIC_VECTOR (23 downto 0);
        dout_q : out  STD_LOGIC_VECTOR (23 downto 0);
        cfg_dout : out  STD_LOGIC_VECTOR (31 downto 0);
        m_ovf : out std_logic_vector(3 downto 0)
    );
end linear_dds_iq;

architecture Behavioral of linear_dds_iq is

    component ila_0 IS
    PORT (
    clk : IN STD_LOGIC;
    probe0 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe3 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe4 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe5 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    probe6 : IN STD_LOGIC_VECTOR(0 DOWNTO 0)
    );
    END component ila_0;
	
	component adc2zeroif
    Port ( 
        clk : in  STD_LOGIC;
        ce : in  STD_LOGIC;
        clr : in  STD_LOGIC;
        din : in  STD_LOGIC_VECTOR (15 downto 0);
        cosine : in  STD_LOGIC_VECTOR (15 downto 0);
        sine : in  STD_LOGIC_VECTOR (15 downto 0);
        i_amp : in  STD_LOGIC_VECTOR (17 downto 0);
        q_amp : in  STD_LOGIC_VECTOR (17 downto 0);
        i_out : out  STD_LOGIC_VECTOR (15 downto 0);
        q_out : out  STD_LOGIC_VECTOR (15 downto 0)
    );
	end component;

	COMPONENT corr_measure
	PORT(
		i1 : IN std_logic_vector(15 downto 0);
		q1 : IN std_logic_vector(15 downto 0);
		i2 : IN std_logic_vector(15 downto 0);
		q2 : IN std_logic_vector(15 downto 0);
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;
		din : IN std_logic_vector(7 downto 0);
		addr : IN std_logic_vector(1 downto 0);
		rd : IN std_logic;
		wr : IN std_logic;
		cs : IN std_logic;          
		slow : IN std_logic;          
		dout : OUT std_logic_vector(7 downto 0);
		phi_out : OUT std_logic_vector(17 downto 0)
		);
	END COMPONENT;	
	
	COMPONENT corr_rotate
	PORT(
		din_i : IN std_logic_vector(15 downto 0);
		din_q : IN std_logic_vector(15 downto 0);
		phi : IN std_logic_vector(17 downto 0);
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;          
		dout_i : OUT std_logic_vector(15 downto 0);
		dout_q : OUT std_logic_vector(15 downto 0)
		);
	END COMPONENT;
	
	COMPONENT liner_n_corr
	PORT(
		din_new : IN std_logic_vector(17 downto 0);
		clr : IN std_logic;
		clk : IN std_logic;
		din_fb : IN std_logic_vector(17 downto 0);
		din_stab : IN std_logic_vector(17 downto 0);
		k_prop : IN std_logic_vector(17 downto 0);
		k_dif : IN std_logic_vector(17 downto 0);          
		dout_sum : OUT std_logic_vector(17 downto 0);
		dout_integ : OUT std_logic_vector(17 downto 0);
		dout_err : OUT std_logic_vector(17 downto 0);
		dout_stab : OUT std_logic_vector(17 downto 0)
		);
	END COMPONENT;
	
	COMPONENT liner_n_agc
	PORT(
		din_i : IN std_logic_vector(15 downto 0);
		din_q : IN std_logic_vector(15 downto 0);
		fwd_i : IN std_logic_vector(15 downto 0);
		fwd_q : IN std_logic_vector(15 downto 0);
		clk : IN std_logic;
		clr : IN std_logic;
		k : IN std_logic_vector(2 downto 0);
		sat : IN std_logic_vector(2 downto 0);          
		dout_i : OUT std_logic_vector(15 downto 0);
		dout_q : OUT std_logic_vector(15 downto 0);
  	   k_out : out  STD_LOGIC_VECTOR (15 downto 0)
		);
	END COMPONENT;
	
	COMPONENT mult48cc
	PORT(
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;
		a : IN std_logic_vector(17 downto 0);
		b : IN std_logic_vector(17 downto 0);          
		m : OUT std_logic_vector(35 downto 0)
		);
	END COMPONENT;
	
	COMPONENT orth_gain
	PORT(
		clk : IN std_logic;
		ce : IN std_logic;
		clr : IN std_logic;
		sin : IN std_logic_vector(15 downto 0);
		cos : IN std_logic_vector(15 downto 0);
		din_s : IN std_logic_vector(15 downto 0);
		din_c : IN std_logic_vector(15 downto 0);
		gain_I : IN std_logic_vector(15 downto 0);
		gain_Q : IN std_logic_vector(15 downto 0);          
		dout0 : OUT std_logic_vector(16 downto 0);
		dout1 : OUT std_logic_vector(16 downto 0);
		dout2 : OUT std_logic_vector(16 downto 0);
		dout3 : OUT std_logic_vector(16 downto 0)
		);
	END COMPONENT;

	COMPONENT calc_rms
	PORT(
		clk : IN std_logic;
		clr : IN std_logic;
		din_i : IN std_logic_vector(15 downto 0);
		din_q : IN std_logic_vector(15 downto 0);          
		dout : OUT std_logic_vector(31 downto 0)
		);
	END COMPONENT;

signal phase_i, phase_q : std_logic_vector(15 downto 0);
signal di_16, dq_16 : std_logic_vector(15 downto 0);
signal fir_i, fir_q : std_logic_vector(15 downto 0) := (others => '0');

signal di_19, dq_19 : std_logic_vector(18 downto 0);
signal di_sum, dq_sum, fb_i, fb_q : std_logic_vector(17 downto 0);

signal din1_ir, din1_qr : std_logic_vector(17 downto 0) := (others => '0');
signal phi : std_logic_vector(17 downto 0);

signal wrs, m_cs, wr_m : std_logic := '0';
signal corr_clr : std_logic;

signal sine1, cosine1, sine_adc, cosine_adc : std_logic_vector(15 downto 0);

signal i_corr_amp, q_corr_amp : std_logic_vector(17 downto 0) := x"7fff" & "00";
signal din2c : std_logic_vector(15 downto 0);

signal aa1, bb1, aa2, bb2, aa3, bb3, aa4, bb4 : std_logic_vector(17 downto 0);
signal pp1, pp2, pp3, pp4 : std_logic_vector(35 downto 0);

signal dc_i, dc_q : std_logic_vector(15 downto 0) := (others => '0');

signal sum0_i, sum0_q, sum_i, sum_q: std_logic_vector(17 downto 0) := (others => '0');

signal gainI, gainQ, phi_cos_reg : std_logic_vector(15 downto 0) := x"7fff";
signal phi_sin_reg : std_logic_vector(15 downto 0) := x"0000";
signal orth0, orth1, orth2, orth3 : std_logic_vector(16 downto 0);

signal stab_reg : std_logic_vector(17 downto 0) := x"2666" & "00";	-- 0.3
signal stab_cnt : std_logic_vector(17 downto 0) := (others => '0');
signal prop_reg : std_logic_vector(17 downto 0) := x"1780" & "00";	-- 4 (0.0156*256)
signal dif_reg : std_logic_vector(17 downto 0) := x"6400" & "00";	-- 200 (0.78*256)

signal agc_i, agc_q : std_logic_vector(15 downto 0);
signal agc_k : std_logic_vector(2 downto 0) := "010";
signal agc_k_out : std_logic_vector(15 downto 0);

signal dout_i_int, dout_q_int : std_logic_vector(15 downto 0);

signal adc_shifts : std_logic_vector(2 downto 0) := (others => '0');

--signal rms_dout : std_logic_vector(31 downto 0);
signal rms_l : std_logic_vector(15 downto 0) := (others => '0');

signal lin_clr, lin_on, agc_on, phase_slow : STD_LOGIC := '0';
signal overflow_i, overflow_q, overm_i, overm_q : STD_LOGIC;
signal cfg_addr : std_logic_vector(3 downto 0);
signal cfg_wr : std_logic := '0';

    constant ACLK_DIVIDER : integer := ((122880000 / 32000) - 1);
    signal sync_cnt : std_logic_vector(11 downto 0) := (others => '0');
    signal valid32 : std_logic;

begin

valid32 <= '1' when sync_cnt = ACLK_DIVIDER else '0';

process(aclk)
begin
    if rising_edge(aclk) then
        if sync_cnt = ACLK_DIVIDER then
            sync_cnt <= (others => '0');
        else
            sync_cnt <= sync_cnt + 1;
        end if;
    end if;
end process;

dout_i <= dout_i_int & x"00";
dout_q <= dout_q_int & x"00";

---- Feedback from ADC
din2c <= din2  							when adc_shifts = "000" else
			din2(14 downto 0) & '0'		when adc_shifts = "001" else
			din2(13 downto 0) & "00"	when adc_shifts = "010" else
			din2(12 downto 0) & "000"	when adc_shifts = "011" else
			din2(11 downto 0) & "0000"	when adc_shifts = "100" else
			din2(10 downto 0) & "00000"	when adc_shifts = "101" else
			din2(9 downto 0) & "000000"	when adc_shifts = "110" else
			din2(8 downto 0) & "0000000";

inst_adc2zeroif : adc2zeroif
		port map (
			clk => aclk,
			ce => ce,
			clr => lin_clr,			
			din => din2c,
			cosine => cosine_adc,
			sine => sine_adc,
			i_amp => i_corr_amp,
			q_amp => q_corr_amp,
			i_out => fir_i,
			q_out => fir_q
		);
		
debug_0 : ila_0
    PORT MAP(
        clk => aclk,
        probe0 => din2c,
        probe1 => fb_i(17 downto 2),
        probe2 => fb_q(17 downto 2),
        probe3 => din1_ir(17 downto 2),
        probe4 => dout_i_int,
        probe5 => dout_q_int,
        probe6(0) => valid32
    );

-- PHASE Block

    wr_m <= s_axis_cfg_tvalid when s_axis_cfg_tdest(4) = '1' else '0';        
    m_cs <= '1' when s_axis_cfg_tdest(4) = '1' else '0';
    cfg_addr <= s_axis_cfg_tdest(3 downto 0);
    cfg_wr <= s_axis_cfg_tvalid when s_axis_cfg_tdest(4) = '0' else '0';   

	measure: corr_measure PORT MAP(
		i1 => fir_i,	
		q1 => fir_q, 
		i2 => di_16, 
		q2 => dq_16, 
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		din => s_axis_cfg_tdata(7 downto 0),
		addr => s_axis_cfg_tdest(1 downto 0),
		rd => '0',
		wr => wr_m,
		cs => m_cs,
		slow => phase_slow,
		dout => open,
		phi_out => phi
	);
	rotate: corr_rotate PORT MAP(
		din_i => fir_i, 
		din_q => fir_q, 
		phi => phi,
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		dout_i => phase_i,
		dout_q => phase_q
	);
	
-- AGC
	agc: liner_n_agc PORT MAP(
		din_i => phase_i,
		din_q =>  phase_q,
		fwd_i => di_16,
		fwd_q => dq_16,
		clk => aclk,
		clr => corr_clr,
		k => agc_k,
		sat => "000",
		dout_i => agc_i,
		dout_q => agc_q,
		k_out => agc_k_out
	);
	
-- Corrector
din1_ir <= din1_i(23 downto 6);
din1_qr <= din1_q(23 downto 6);

corr_clr <= lin_clr or (not lin_on);

fb_i <= phase_i & "00" when agc_on = '0' else
		  agc_i & "00";
fb_q <= phase_q & "00" when agc_on = '0' else
		  agc_q & "00";

corr_i: liner_n_corr PORT MAP(
		din_new => din1_ir,
		clr => corr_clr,
		clk => aclk,
		din_fb => fb_i,
		din_stab => stab_cnt,	
		k_prop =>   prop_reg,
		k_dif =>    dif_reg,
		dout_sum => di_sum,
		dout_integ => open ,
		dout_err => open,
		dout_stab => open
	);

corr_q: liner_n_corr PORT MAP(
		din_new => din1_qr,
		clr => corr_clr,
		clk => aclk,
		din_fb => fb_q,
		din_stab => stab_cnt,	
		k_prop =>   prop_reg,
		k_dif =>    dif_reg,
		dout_sum => dq_sum,
		dout_integ => open ,
		dout_err => open,
		dout_stab => open
	);

--- DDSes
		
cosine_adc <= s_axis_dds_tdata(15 downto 0);
sine_adc <= s_axis_dds_tdata(31 downto 16);			

cosine1 <= x"7fff";
sine1 <= x"0000";

-- Ortho conversion
aa1 <= di_16(15) & di_16(15) & di_16;
bb1 <= orth0 & '0';

aa2 <= dq_16(15) & dq_16(15) & dq_16;
bb2 <= orth1 & '0';

aa3 <= dq_16(15) & dq_16(15) & dq_16;
bb3 <= orth2 & '0';

aa4 <= di_16(15) & di_16(15) & di_16;
bb4 <= orth3 & '0';

mult_icos : mult48cc port map (
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		a => aa1,
		b => bb1,
		m => pp1
	);

mult_qsin : mult48cc port map (
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		a => aa2,
		b => bb2,
		m => pp2
	);
mult_qcos : mult48cc port map (
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		a => aa3,
		b => bb3,
		m => pp3
	);

mult_isin : mult48cc port map (
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		a => aa4,
		b => bb4,
		m => pp4
	);
	
Inst_orth_gain: orth_gain PORT MAP(
		clk => aclk,
		ce => ce,
		clr => lin_clr,
		sin => sine1,
		cos => cosine1,
		din_s => phi_sin_reg,
		din_c => phi_cos_reg,
		gain_I => gainI,
		gain_Q => gainQ,
		dout0 => orth0,
		dout1 => orth1,
		dout2 => orth2,
		dout3 => orth3
	);

--Inst_calc_rms: calc_rms PORT MAP(
--		clk => aclk,
--		clr => lin_clr,
--		din_i => fir_i,
--		din_q => fir_q,
--		dout => rms_dout
--	);

sum_proc : process(aclk)
begin
	if rising_edge(aclk) then
			
-- final summator in FPGA block (19 bits), overflow check, convert to 16 bits
		di_19 <= (di_sum(17) & di_sum) + (din1_ir(17) & din1_ir);
		if (di_19(18 downto 17) = "00") or (di_19(18 downto 17) = "11") then	-- no overflow
			di_16 <= di_19(17 downto 2);
			overm_i <= '0';
		else	-- overflow
		    overm_i <= '1';
			if di_19(18) = '1' then
				di_16 <= x"8000";
			else
				di_16 <= x"7FFF";
			end if;
		end if;

		dq_19 <= (dq_sum(17) & dq_sum) + (din1_qr(17) & din1_qr);
		if (dq_19(18 downto 17) = "00") or (dq_19(18 downto 17) = "11") then	-- no overflow
			dq_16 <= dq_19(17 downto 2);
			overm_q <= '0';
		else	-- overflow
		    overm_q <= '1';
			if dq_19(18) = '1' then
				dq_16 <= x"8000";
			else
				dq_16 <= x"7FFF";
			end if;
		end if;
		
-- final sum in ortho conversion		
		sum0_i <= pp1(33 downto 16) - pp2(33 downto 16);
		sum0_q <= pp3(33 downto 16) + pp4(33 downto 16);

-- DC offsets
		sum_i <= sum0_i + (dc_i(15) & dc_i(15) & dc_i);
		sum_q <= sum0_q + (dc_q(15) & dc_q(15) & dc_q);		

-- overflow check		
		if (sum_i(17 downto 15) = "000") or (sum_i(17 downto 15) = "111") then	-- no overflow
			dout_i_int <= sum_i(15 downto 0);
			overflow_i <= '0';
		else	-- overflow
		    overflow_i <= '1';
			if sum_i(17) = '1' then
				dout_i_int <= x"8000";
			else
				dout_i_int <= x"7FFF";
			end if;
		end if;

		if (sum_q(17 downto 15) = "000") or (sum_q(17 downto 15) = "111") then	-- no overflow
		    overflow_q <= '0';
			dout_q_int <= sum_q(15 downto 0);
		else	-- overflow
		    overflow_q <= '1';
			if sum_q(17) = '1' then
				dout_q_int <= x"8000";
			else
				dout_q_int <= x"7FFF";
			end if;
		end if;
		
	end if;
end process sum_proc;

    m_ovf <= overflow_i & overflow_q & overm_i & overm_q;

cmd_proc : process(aclk)
begin
    if rising_edge(aclk) then	
        if cfg_wr = '1' then    
            if cfg_addr = x"0" then
                if s_axis_cfg_tdata(2 downto 0) = "000" then				
					cfg_dout <= ext(agc_k_out, 32);
--				elsif s_axis_cfg_tdata(2 downto 0) = "001" then
--					cfg_dout <= rms_dout;
				end if;                            
            elsif cfg_addr = x"1" then
                adc_shifts <= s_axis_cfg_tdata(2 downto 0);    
            elsif cfg_addr = x"2" then
                agc_k <= s_axis_cfg_tdata(2 downto 0); 
            elsif cfg_addr = x"3" then
                gainI <= s_axis_cfg_tdata(15 downto 0);      
            elsif cfg_addr = x"4" then
                gainQ <= s_axis_cfg_tdata(15 downto 0); 
            elsif cfg_addr = x"6" then
				prop_reg <= s_axis_cfg_tdata(17 downto 0); 	 
			elsif cfg_addr = x"7" then	
				i_corr_amp <= s_axis_cfg_tdata(17 downto 0);
			elsif cfg_addr = x"8" then
				q_corr_amp <= s_axis_cfg_tdata(17 downto 0);
			elsif cfg_addr = x"9" then
				dc_i <= s_axis_cfg_tdata(15 downto 0);
			elsif cfg_addr = x"A" then
				dc_q <= s_axis_cfg_tdata(15 downto 0);
			elsif cfg_addr = x"B" then
				phi_sin_reg <= s_axis_cfg_tdata(15 downto 0);
			elsif cfg_addr = x"C" then
				phi_cos_reg <= s_axis_cfg_tdata(15 downto 0);
			elsif cfg_addr = x"D" then
				dif_reg <= s_axis_cfg_tdata(17 downto 0);
			elsif cfg_addr = x"E" then
				stab_reg <= s_axis_cfg_tdata(17 downto 0);
			elsif cfg_addr = x"F" then
			    lin_clr <= s_axis_cfg_tdata(0);
				lin_on <= s_axis_cfg_tdata(1);
				agc_on <= s_axis_cfg_tdata(2);
				phase_slow <= s_axis_cfg_tdata(3);              
            end if; 
		end if;         
	end if;
end process cmd_proc;

stab_proc : process(aclk)
begin
	if rising_edge(aclk) then
		if lin_on = '0' or lin_clr = '1' then
			stab_cnt <= (others => '0');
		else
			if stab_cnt < stab_reg then
				stab_cnt <= stab_cnt + 1;
			else
				null;
			end if;
		end if;
	end if;
end process;

end Behavioral;

