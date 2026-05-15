/*
 * cmd.h
 *
 *  Created on: 13 мая 2026 г.
 *      Author: VictorT
 */

#ifndef SRC_CMD_H_
#define SRC_CMD_H_

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

#endif /* SRC_CMD_H_ */
