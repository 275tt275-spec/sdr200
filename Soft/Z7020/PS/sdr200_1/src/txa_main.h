#pragma once

#include "comm.h"

enum txaMode
{
	TXA_LSB,
	TXA_USB,
	TXA_DSB,
	TXA_CWL,
	TXA_CWU,
	TXA_FM,
	TXA_AM,
	TXA_DIGU,
	TXA_SPEC,
	TXA_DIGL,
	TXA_SAM,
	TXA_DRM,
	TXA_AM_LSB,
	TXA_AM_USB
};

enum txaMeterType
{
	TXA_MIC_PK,
	TXA_MIC_AV,
	TXA_EQ_PK,
	TXA_EQ_AV,
	TXA_LVLR_PK,
	TXA_LVLR_AV,
	TXA_LVLR_GAIN,
	TXA_CFC_PK,
	TXA_CFC_AV,
	TXA_CFC_GAIN,
	TXA_COMP_PK,
	TXA_COMP_AV,
	TXA_ALC_PK,
	TXA_ALC_AV,
	TXA_ALC_GAIN,
	TXA_OUT_PK,
	TXA_OUT_AV,
	TXA_METERTYPE_LAST
};

struct _ch
{
	int in_rate;				// input samplerate
	int out_rate;				// output samplerate
	int in_size;				// input buffsize (complex samples) in a fexchange() operation
	int dsp_rate;				// sample rate for mainstream dsp processing
	int dsp_size;				// number complex samples processed per buffer in mainstream dsp processing
	int dsp_insize;				// size (complex samples) of the output of the r1 (input) buffer
	int dsp_outsize;			// size (complex samples) of the input of the r2 (output) buffer
	int out_size;				// output buffsize (complex samples) in a fexchange() operation
};

struct _create_runs
{
	int rsmpin;					// input resampler
	int panel;					// includes MIC gain
	int phrot;					// phase rotator
	int micmeter;				// MIC meter
	int amsq;					// downward expander capture
	int eqp;					// pre-EQ
	int eqmeter;				// EQ meter
	int preemph;				// FM pre-emphasis
	int leveler;				// Leveler
	int lvlrmeter;				// Leveler Meter
	int cfcomp;					// Continuous Frequency Compressor with post-EQ
	int cfcmeter;				// CFC+PostEQ Meter
	int bp0;					// primary bandpass filter
	int compressor;				// COMP compressor
	int osctrl;					// CESSB Overshoot Control
	int compmeter;				// COMP meter
	int alc;					// ALC
	int ammod;					// AM Modulator
	int fmmod;					// FM Modulator
	int alcmeter;				// ALC Meter
	int iqc;					// PureSignal correction
	int cfir;					// compensating FIR filter (used Protocol_2 only)
	int rsmpout;				// output resampler
	int outmeter;				// output meter
};

struct _txa
{
	float* inbuff;
	float* outbuff;
	float* midbuff;
	int mode;
	float f_low;
	float f_high;
	float meter[TXA_METERTYPE_LAST];
//	CRITICAL_SECTION* pmtupdate[TXA_METERTYPE_LAST];
	struct
	{
		METER p;
	} micmeter, eqmeter, lvlrmeter, cfcmeter, compmeter, alcmeter, outmeter;
	struct
	{
		RESAMPLE p;
	} rsmpin, rsmpout;
	struct
	{
		GEN p;
	} gen0, gen1;
	struct
	{
		PANEL p;
	} panel;
	struct
	{
		PHROT p;
	} phrot;
	struct
	{
		AMSQ p;
	} amsq;
	struct
	{
		EQP p;
	} eqp;
	struct
	{
		EMPHP p;
	} preemph;
	struct
	{
		WCPAGC p;
	} leveler, alc;
	struct
	{
		CFCOMP p;
	} cfcomp;
	struct
	{
		COMPRESSOR p;
	} compressor;
	struct
	{
		BANDPASS p;
	} bp0, bp1, bp2;
	struct
	{
		OSCTRL p;
	} osctrl;
	struct
	{
		AMMOD p;
	} ammod;
	struct
	{
		FMMOD p;
	} fmmod;
#if 0
	struct
	{
		SIPHON p;
	} sip1;
#endif
	struct
	{
		USLEW p;
	} uslew;
	struct
	{
		CALCC p;
//		CRITICAL_SECTION cs_update;
	} calcc;
	struct
	{
		IQC p0, p1;
		// p0 for dsp-synchronized reference, p1 for other
	} iqc;
	struct
	{
		CFIR p;
	} cfir;
	struct	_create_runs runs;
};

extern struct _txa txa[];
void set_dsp(int in_size, int dsp_size, int input_samplerate, int dsp_rate, int output_samplerate);
void create_txa(int channel, struct _create_runs* runs);
void xtxa(int channel);
void SetTXAMode(int channel, int mode);
void SetTXABandpassFreqs (int channel, float f_low, float f_high);
int TXAUslewCheck(int channel);
void TXASetupBPFilters(int channel);
// extern CRITICAL_SECTION csDSP;
