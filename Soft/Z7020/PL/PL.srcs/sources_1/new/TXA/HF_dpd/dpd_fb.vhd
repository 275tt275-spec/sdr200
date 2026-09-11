----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.09.2026 07:25:48
-- Design Name: 
-- Module Name: dpd_fb - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity dpd_fb is
  Port (
      ref_i : in  STD_LOGIC_VECTOR (15 downto 0);
      ref_q : in  STD_LOGIC_VECTOR (15 downto 0);
      adc_fb : in  STD_LOGIC_VECTOR (15 downto 0);
      s_axis_dds_tdata : in STD_LOGIC_VECTOR (31 downto 0);
      fb_out_i : out  STD_LOGIC_VECTOR (15 downto 0);
      fb_out_q : out  STD_LOGIC_VECTOR (15 downto 0);
      txa_on : in  STD_LOGIC;
      cfg_clr : in  STD_LOGIC;
      phase_slow : in  STD_LOGIC;
      i_corr_amp : in std_logic_vector(17 downto 0);
      q_corr_amp : in std_logic_vector(17 downto 0);
      s_axis_cfg_tdata : in STD_LOGIC_VECTOR (7 downto 0);
      s_axis_cfg_tdest : in STD_LOGIC_VECTOR (1 downto 0);
      s_axis_cfg_tvalid : in STD_LOGIC;
      aclk : in  STD_LOGIC
  );
end dpd_fb;

architecture Behavioral of dpd_fb is

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
	
	signal sine_dds, cosine_dds : std_logic_vector(15 downto 0);
	signal zeroif_i, zeroif_q : std_logic_vector(15 downto 0);
	signal phi : std_logic_vector(17 downto 0);

begin

    cosine_dds <= s_axis_dds_tdata(15 downto 0);
    sine_dds <= s_axis_dds_tdata(31 downto 16);	

inst_adc2zeroif : adc2zeroif
    port map (
        clk      => aclk,
        ce       => txa_on,
        clr      => cfg_clr,			
        din      => adc_fb,
        cosine   => cosine_dds,
        sine     => sine_dds,
        i_amp    => i_corr_amp,
        q_amp    => q_corr_amp,
        i_out    => zeroif_i,
        q_out    => zeroif_q
    );
    
inst_corr_measure : corr_measure
    port map (
		i1    => zeroif_i,	
		q1    => zeroif_q,
		i2    => ref_i,
		q2    => ref_q,
		clk   => aclk,
		ce    => txa_on,
		clr   => cfg_clr,
		din   => s_axis_cfg_tdata,
		addr  => s_axis_cfg_tdest,
		rd    => '0',
		wr    => s_axis_cfg_tvalid,
		cs    => '1',
		slow  => phase_slow,
		dout  => open,
		phi_out => phi
	);
    
inst_corr_rotate : corr_rotate
	port map (
		din_i    => zeroif_i,
		din_q    => zeroif_q,
		phi      => phi,
		clk      => aclk,
		ce       => txa_on,
		clr      => cfg_clr,          
		dout_i   => fb_out_i,
		dout_q   => fb_out_q
    );

end Behavioral;
