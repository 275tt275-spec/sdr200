/*
 * shared_region.h
 *
 *  Created on: 19 июн. 2026 г.
 *      Author: VictorT
 */

#ifndef SHARED_SHARED_REGION_H_
#define SHARED_SHARED_REGION_H_

#define OCM_SHARED_SECTION 	0xFFFF0000
#define SGI_TO_CORE1 		0  // ID прерывания для Core 1
#define TARGET_CORE1 		2  // Битовая маска для Core 1 (Core 0 = 1, Core 1 = 2)
#define CORE1_START_REG 	0xFFFFFFF0
#define SHARED_BUFFER_SIZE	16384

typedef struct tag_shared_buffer {
	uint32_t rd_cnt;
	uint32_t wr_cnt;
	uint32_t type;
	uint32_t lenght;
	uint32_t data;
} s_shared_buffer;

extern volatile s_shared_buffer* Core0toCore1;
extern volatile s_shared_buffer* Core1toCore0;

#define SET_TXA_MODE				1
#define SET_TXA_BANDPASS			2
#define SET_TXA_AM_CARRIER			10
#define SET_TXA_FM_DEVIATION		11
#define SET_TXA_FM_CTCSSFREQ		12
#define SET_TXA_FM_CTCSSRUN			13
#define SET_TXA_FM_MP				14
#define SET_TXA_FM_NC				15
#define SET_TXA_FM_AFFREQ			16
#define SET_TXA_AMSQ_RUN			20
#define SET_TXA_AMSQ_MUTED_GAIN		21
#define SET_TXA_AMSAQ_TRESHOLD		22
#define SET_TXA_ALC					30
#define SET_TXA_LEVELER				31
#define SET_TXA_BPSRUN				32
#define SET_TXA_BPSFREQS			33
#define SET_TXA_USLEW_TIME			40
#define SET_TXA_PANEL_RUN			50
#define SET_TXA_OSCTRL_RUN			60

#define SET_TXA_SET_PS_RUN			70
#define SET_TXA_SET_PS_MOX			71
#define GET_TXA_SET_PS_INFO			72
#define SET_TXA_SET_PS_RESET		73
#define SET_TXA_SET_PS_MANCAL 		74
#define SET_TXA_SET_PS_AUTOMODE		75
#define SET_TXA_SET_PS_TURNON		76
#define SET_TXA_SET_PS_CONTROL		77
#define SET_TXA_SET_PS_LOOPDELAY	78
#define SET_TXA_SET_PS_MOXDELAY		79
#define SET_TXA_SET_PS_TXDELAY		80
#define SET_TXA_SET_PS_PSCCF		81
#define SET_TXA_PS_SAVE_CORR		82
#define SET_TXA_PS_RESTORE_CORR		83
#define SET_TXA_SET_PS_HWPEAK		84
#define SET_TXA_GET_PS_HWPEAK		85
#define SET_TXA_GET_PS_MAXTX		86
#define SET_TXA_SET_PS_PTOL			87
#define SET_TXA_GET_PS_DISP			88
#define SET_TXA_SET_PS_FBRATE		89
#define SET_TXA_SET_PS_PINMODE		90
#define SET_TXA_SET_PS_MAPMODE		91
#define SET_TXA_SET_PS_STABILIZE	92
#define SET_TXA_SET_PS_INTSSPI		93

typedef enum tag_txaMode
{
	MODE_TXA_LSB,
	MODE_TXA_USB,
	MODE_TXA_DSB,
	MODE_TXA_CWL,
	MODE_TXA_CWU,
	MODE_TXA_FM,
	MODE_TXA_AM,
	MODE_TXA_DIGU,
	MODE_TXA_SPEC,
	MODE_TXA_DIGL,
	MODE_TXA_SAM,
	MODE_TXA_DRM,
	MODE_TXA_AM_LSB,
	MODE_TXA_AM_USB
} e_txaMode;

typedef struct tag_wxpAGC {
	int state;
	int attack;
	int decay;
	int hang;
	float maxgain;
}s_wxpAGC;

typedef struct tag_ps_control {
	int reset;
	int mancal;
	int automode;
	int turnon;
}s_ps_control;

#endif /* SHARED_SHARED_REGION_H_ */
