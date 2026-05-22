/*
 * fpga.h
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#ifndef SRC_FPGA_H_
#define SRC_FPGA_H_

/* ADDR 10 bits * 4 */
/* write */
#define FPGA_HW_RESET 		0x0000  /* Global Reset */
#define FPGA_RXA_DDS_NR 	0x0100  /* DDS NR */
#define FPGA_RXA_MOD 		0x0101  /* MODULATION */
#define FPGA_RXA_LSB 		0x0102  /* J3E LSB */
#define FPGA_RXA_FOS_COEFF 	0x0103  /* FOS COEFF 64 */
#define FPGA_RXA_FOS_GAIN 	0x0104  /* FOS GAIN CORRECT */
#define FPGA_RXA_OFFSET		0x0105  /* A1A TONE J3E OFFSET */
#define FPGA_RXA_DDS_WB 	0x0106  /* DDS WB */
//#define FPGA_RXA_RF_GAIN    0x0107  /* (0 - 32768, gain 1.0 = 256) */
//#define FPGA_RXA_AGC_TYPE   0x0108  /*  */
//#define FPGA_RXA_AGC_LEVEL  0x0109  /*  */
//#define FPGA_RXA_AGC_STEP	0x010A  /*  */
//#define FPGA_RXA_AGC_FAST	0x010B  /*  */
#define FPGA_RXA_AUDIO_LP	0x010E  /*  */
#define FPGA_RXA_AUDIO_HP	0x010F  /*  */
#define FPGA_RXA_AUDIO_CORR	0x0110	/* correct out audio filter (0, 1, 2, 3*/

/* -- 0x0120-0x012F  AGC */
#define FPGA_RXA_RF_GAIN	0x0120
#define FPGA_RXA_AGC_ON		0x0121
#define FPGA_RXA_AGC_MAX	0x0122
#define FPGA_RXA_AGC_MAX2	0x0123
#define FPGA_RXA_AGC_MIN	0x0124
#define FPGA_RXA_AGC_MIN2	0x0125
#define FPGA_RXA_AGC_INC	0x0126
#define FPGA_RXA_AGC_DEC	0x0127

#define FPGA_TXA_DDS 		0x0200  /* DDS  */
#define FPGA_TXA_CTRL 		0x0201  /* ctrl reg */
#define FPGA_TXA_CTRL_ON 	( 1 << 0 ) /* txa on(0) */
#define FPGA_TXA_CTRL_HW 	( 1 << 1 ) /* txa hw on(1) */
#define FPGA_TXA_RESAMPLER_G	0x0203  /* txa resampler out gain */

// 0x022_  /* limiter */
#define FPGA_LIM_IN 		0x0220 /* lim_in_gain default "00" & x"3FFF" */
#define FPGA_LIM_LIMIT 		0x0221 /* lim_limit default x"0400" */
#define FPGA_LIM_OUT 		0x0222 /* lim_out_gain default "00" & x"1FFF", */
#define FPGA_LIM_PHASE 		0x0223 /* phase_step default x"1D9A"  -- 1850 Hz */
#define FPGA_LIM_OVER 		0x0224 /* limit_overshoot default x"1000"  */
#define FPGA_LIM_FIR 		0x0225 /* LP FIR */
#define FPGA_LIM_CTRL 		0x0226 /* CTRL bit 0 - enable */

// 0x024_  /* modulator */
#define FPGA_TXA_MOD 		0x0240  /* MODULATION */
#define FPGA_TXA_LSB 		0x0241  /* J3E LSB */
#define FPGA_TXA_AUDIO_GAIN 0x0242  /* AUDIO GAIN */
#define FPGA_TXA_CARRIER_LEVEL 0x0243  /* CARRIER LEVEL (A3E) */
#define FPGA_TXA_J3E 		0x0244  /* PHASE STEP (J3E) */
#define FPGA_TXA_FOS_COEFF 	0x0248  /* FOS COEFF 64  */
#define FPGA_TXA_FOS_GAIN 	0x0249  /* FOS GAIN CORRECT */
#define FPGA_TXA_TEST 		0x024F  /* TEST_REG */
// 0x026_  /* resampler */
// 0x028_  /* linear cmd */
#define FPGA_LIN_READ_SELECT        0x0280
#define FPGA_LIN_ADC_SHIFT          0x0281
#define FPGA_LIN_AGC_K              0x0282
#define FPGA_LIN_GAINI         		0x0283
#define FPGA_LIN_GAINQ         		0x0284
#define FPGA_LIN_CORR_KPROP         0x0286
#define FPGA_LIN_AMPI         		0x0287
#define FPGA_LIN_AMPQ         		0x0288
#define FPGA_LIN_DCI         		0x0289
#define FPGA_LIN_DCQ         		0x028A
#define FPGA_LIN_PHI_SIN       		0x028B
#define FPGA_LIN_PHI_COS       		0x028C
#define FPGA_LIN_CORR_KDIFF         0x028D
#define FPGA_LIN_CORR_KSTAB         0x028E
#define FPGA_LIN_CTRL               0x028F
#define FPGA_LINER_CLR              (1UL << 0)
#define FPGA_LINER_ON               (1UL << 1)
#define FPGA_LINER_AGC              (1UL << 2)
#define FPGA_LIN_PHASE_SLOW	        (1UL << 3)


// 0x02A_  /* linear phase block */
// PHASE BLOCK
#define FPGA_LIN_PHASE_RST          0x02A8
#define FPGA_LIN_PHASE_WR           0x02A9
#define FPGA_LIN_PHASE_K            0x02AA

/* read */
// 0x00__  HW_cfg
#define FPGA_HW_CTRL 		0x0001  /* status bits */
#define FPGA_HW_CTRL_PTT    (1UL << 0)
#define FPGA_HW_CTRL_CW     (1UL << 1)
#define FPGA_HW_CTRL_DTR    (1UL << 2)
#define FPGA_HW_CTRL_RTS	(1UL << 3)
// 0x01__  TXA_cfg
// 0x02__  TXA_cfg
#define FPGA_TXA_OVER 		0x0200  /* over bits */
#define FPGA_TXA_AUDIO_ABS 	0x0201  /* audio_max_abs */
// 0x03__   SWR_cfg
#define FPGA_REG_SWR		0x0300  /* swr 16 bit inc & 16 bit ref (absolute) */
#define FPGA_REG_MAG		0x0301  /* magnitude 16 bit chan A & 16 bit chan B (absolute) */
#define FPGA_REG_ANGLE		0x0302  /* angle 16 bit chan A & 16 bit chan B (signed) */

#define FPGA_RXA_GET		0x0100

#define BRAM_DEVICE_ID			XPAR_BRAM_0_DEVICE_ID
#define FIFO_DEV_ID	   			XPAR_AXI_FIFO_0_DEVICE_ID
#define READ_STATUS_TIMEOUT		50000

typedef enum tag_fpga_mod {
	FPGA_MOD_J3E	= 0,
	FPGA_MOD_A3E	= 1,
	FPGA_MOD_A1A	= 2,
	FPGA_MOD_F3E	= 3
} e_fpga_mod;

typedef struct tag_agc
{
	uint32_t on;
	uint32_t rssi_max;
	uint32_t rssi_max_fast;
	uint32_t rssi_min;
	uint32_t rssi_min_fast;
	uint16_t gain_inc;
	uint16_t gain_inc_fast;
	uint16_t gain_dec;
	uint16_t gain_dec_fast;
} s_agc;

typedef struct tag_swr
{
	uint16_t inc;
	uint16_t ref;
	uint16_t magA;
	uint16_t magB;
	uint16_t angA;
	uint16_t angB;
} s_swr;

typedef struct tag_linear
{
	uint32_t agc_k;
	uint32_t phase_k;
	uint32_t adc_shift;
	uint32_t prop;
	uint32_t diff;
	uint32_t stab;
	uint32_t i_corr_gain;
	uint32_t q_corr_gain;
	uint32_t gain_i;
	uint32_t gain_q;
	uint32_t dc_i;
	uint32_t dc_q;
	uint32_t phi_sin;
	uint32_t phi_cos;
} s_linear;

typedef struct tag_limiter
{
	uint32_t in_gain;
	uint32_t out_gain;
	uint32_t limit;
	uint32_t overshoot;
	uint32_t dds_phase;
} s_limiter;

void fpga_init(void);
void fpga_tick(void);
void fpga_write(uint16_t addr, uint32_t value);
uint32_t fpga_read(uint16_t addr);
void fpga_RXA_DDSNR(uint32_t value);
void fpga_RXA_DDSWB(uint32_t value);
void fpga_RXA_MOD(uint32_t value);
void fpga_RXA_LSB(uint32_t value);
void fpga_RXA_FOSGAIN(uint32_t value);
void fpga_RXA_OFFSET(uint32_t value);
void fpga_RXA_GainRF(uint32_t value);
void fpga_RXA_AGC(s_agc* agc);
void fpga_RXA_FOS(const uint32_t* p);
void fpga_RXA_LP(const uint32_t* p);
void fpga_RXA_HP(const uint32_t* p);
void fpga_RXA_AudioCorrect(uint8_t value);
uint32_t fpga_RXA_GetRSSI(void);
void fpga_TXA_Enable(int enable);
void fpga_TXA_DDS(uint32_t value);
void fpga_TXA_OFFSET(uint32_t value);
void fpga_TXA_CTRL(uint32_t value);
void fpga_TXA_MOD(uint32_t value);
void fpga_TXA_LSB(uint32_t value);
void fpga_TXA_AUDIOGAIN(uint32_t value);
void fpga_TXA_FOS(const uint32_t* p);
void fpga_TXA_FOSGAIN(uint32_t value);
void fpga_TXA_ResamplerGain(uint32_t value);
void fpga_GetSWR(s_swr* swr);
void fpga_LIM_Enable(int enable);
void fpga_LIM_Set(s_limiter* lim);
void fpga_LIM_FIR(const uint32_t* p);
void fpga_LinearReset(void);
void fpga_LinearInit(s_linear* lin);
void fpga_LinearEnable(s_linear* lin, int enable);
void fpga_LinearSetIQGain(s_linear* lin);
void fpga_LinearSetIQCorr(s_linear* lin);
void fpga_LinearSetIQDC(s_linear* lin);
void fpga_LinearSetShift(s_linear* lin);
void fpga_LinearSetCoeff(s_linear* lin);
void fpga_LinearSetIQPhi(s_linear* lin);
uint32_t fpga_SetStatus(void);


#endif /* SRC_FPGA_H_ */
