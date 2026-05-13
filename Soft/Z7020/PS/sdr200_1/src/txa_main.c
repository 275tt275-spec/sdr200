
#include "txa_main.h"

#define DEFAULT_COEFF	32

struct _txa txa[1];
struct _ch ch;

volatile long ch_upslew;

void set_dsp(int in_size, int dsp_size, int input_samplerate, int dsp_rate, int output_samplerate)
{
	ch.in_size = in_size;
	ch.dsp_size = dsp_size;
	ch.in_rate = input_samplerate;
	ch.dsp_rate = dsp_rate;
	ch.out_rate = output_samplerate;

	if (ch.in_rate >= ch.dsp_rate)
		ch.dsp_insize = ch.dsp_size * (ch.in_rate / ch.dsp_rate);
	else
		ch.dsp_insize = ch.dsp_size / (ch.dsp_rate / ch.in_rate);

	if (ch.out_rate >= ch.dsp_rate)
		ch.dsp_outsize = ch.dsp_size * (ch.out_rate / ch.dsp_rate);
	else
		ch.dsp_outsize = ch.dsp_size / (ch.dsp_rate / ch.out_rate);

	if (ch.in_rate >= ch.out_rate)
		ch.out_size = ch.in_size / (ch.in_rate / ch.out_rate);
	else
		ch.out_size = ch.in_size * (ch.out_rate / ch.in_rate);
}

void create_txa(int channel)
{
	InitializeCriticalSectionAndSpinCount(&csDSP, 2500);

	txa[channel].f_low = 2700.0f;
	txa[channel].f_high = 150.0f;
	txa[channel].inbuff = (float*)malloc0(1 * ch.dsp_insize * sizeof(complex));
	txa[channel].outbuff = (float*)malloc0(1 * ch.dsp_outsize * sizeof(complex));
	txa[channel].midbuff = (float*)malloc0(2 * ch.dsp_size * sizeof(complex));

	txa[channel].rsmpin.p = create_resample(
		1,								// run - will be turned on below if needed
		ch.dsp_insize,					// input buffer size
		txa[channel].inbuff,			// pointer to input buffer
		txa[channel].midbuff,			// pointer to output buffer
		ch.in_rate,						// input sample rate
		ch.dsp_rate, 					// output sample rate
		0.0,							// select cutoff automatically
		0,								// select ncoef automatically
		1.0);							// gain

	txa[channel].gen0.p = create_gen(
		0,											// run
		ch.dsp_size,								// buffer size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		ch.dsp_rate,								// sample rate
		1);											// mode

	txa[channel].panel.p = create_panel(
		channel,									// channel number
		1,											// run
		ch.dsp_size,								// size
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer
		1.0,										// gain1
		1.0,										// gain2I
		1.0,										// gain2Q
		2,											// 1 to use Q, 2 to use I for input
		0);											// 0, no copy

	txa[channel].phrot.p = create_phrot(
		0,											// run
		ch.dsp_size,								// size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		ch.dsp_rate,								// samplerate
		338.0,										// 1/2 of phase frequency
		8);											// number of stages

	txa[channel].micmeter.p = create_meter(
		0,											// run
		0,											// optional pointer to another 'run'
		ch.dsp_size,								// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,								// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_MIC_AV,									// index for average value
		TXA_MIC_PK,									// index for peak value
		-1,											// index for gain value
		0);											// pointer for gain computation

	txa[channel].amsq.p = create_amsq(
		0,											// run
		ch.dsp_size,								// size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		txa[channel].midbuff,						// trigger buffer
		ch.dsp_rate,								// sample rate
		0.010f,										// time constant for averaging signal
		0.004f,										// up-slew time
		0.004f,										// down-slew time
		0.180f,										// signal level to initiate tail
		0.200f,										// signal level to initiate unmute
		0.000f,										// minimum tail length
		0.025f,										// maximum tail length
		0.200f);									// muted gain
	{
		float default_F[11] = { 0.0,  32.0f,  63.0f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f };
		float default_G[11] = { 0.0, -12.0f, -12.0f, -12.0f,  -1.0f,  +1.0f,   +4.0f,   +9.0f,  +12.0f,  -10.0f,   -10.0f };
		//double default_G[11] =   {0.0,   0.0,   0.0,   0.0,   0.0,   0.0,    0.0,    0.0,    0.0,    0.0,     0.0};
		txa[channel].eqp.p = create_eqp(
			1,											// run - OFF by default
			ch.dsp_size,									// size
			max(2048, ch.dsp_size),						// number of filter coefficients
			0,											// minimum phase flag
			txa[channel].midbuff,						// pointer to input buffer
			txa[channel].midbuff,						// pointer to output buffer
			10,											// nfreqs
			default_F,									// vector of frequencies
			default_G,									// vector of gain values
			0,											// cutoff mode
			0,											// wintype
			ch.dsp_rate);								// samplerate
	}

	txa[channel].eqmeter.p = create_meter(
		0,											// run
		&(txa[channel].eqp.p->run),					// pointer to eqp 'run'
		ch.dsp_size,								// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,								// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_EQ_AV,									// index for average value
		TXA_EQ_PK,									// index for peak value
		-1,											// index for gain value
		0);											// pointer for gain computation

	txa[channel].preemph.p = create_emphp(
		0,											// run
		1,											// position
		ch.dsp_size,								// size
		max(DEFAULT_COEFF, ch.dsp_size),						// number of filter coefficients
		0,											// minimum phase flag
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer,
		ch.dsp_rate,								// sample rate
		0,											// pre-emphasis type
		300.0f,										// f_low
		3000.0f);									// f_high

	txa[channel].leveler.p = create_wcpagc(
		1,											// run - OFF by default
		5,											// mode
		0,											// 0 for max(I,Q), 1 for envelope
		txa[channel].midbuff,						// input buff pointer
		txa[channel].midbuff,						// output buff pointer
		ch.dsp_size,								// io_buffsize
		ch.dsp_rate,								// sample rate
		0.001f,										// tau_attack
		0.500f,										// tau_decay
		6,											// n_tau
		1.778f,										// max_gain
		1.0f,										// var_gain
		1.0f,										// fixed_gain
		1.0f,										// max_input
		0.8f,										// out_targ
		0.250f,										// tau_fast_backaverage
		0.005f,										// tau_fast_decay
		5.0f,										// pop_ratio
		0,											// hang_enable
		0.500f,										// tau_hang_backmult
		0.500f,										// hangtime
		2.000f,										// hang_thresh
		0.100f);										// tau_hang_decay

	txa[channel].lvlrmeter.p = create_meter(
		0,											// run
		&(txa[channel].leveler.p->run),				// pointer to leveler 'run'
		ch.dsp_size,								// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,								// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_LVLR_AV,								// index for average value
		TXA_LVLR_PK,								// index for peak value
		TXA_LVLR_GAIN,								// index for gain value
		&txa[channel].leveler.p->gain);				// pointer for gain computation

	{
		float default_F[5] = { 200.0f, 1000.0f, 2000.0f, 3000.0f, 4000.0f };
		float default_G[5] = { 0.0f, 5.0f, 10.0f, 10.0f, 5.0f };
		float default_E[5] = { 7.0f, 7.0f, 7.0f, 7.0f, 7.0f };
		txa[channel].cfcomp.p = create_cfcomp(
			1,											// run
			0,											// position
			0,											// post-equalizer run
			ch.dsp_size,								// size
			txa[channel].midbuff,						// input buffer
			txa[channel].midbuff,						// output buffer
			2048,										// fft size
			4,											// overlap
			ch.dsp_rate,						// samplerate
			1,											// window type
			0,											// compression method
			5,											// nfreqs
			0.0,										// pre-compression
			0.0,										// pre-postequalization
			default_F,									// frequency array
			default_G,									// compression array
			default_E,									// eq array
			0.25f,										// metering time constant
			0.50f);										// display time constant
	}

	txa[channel].cfcmeter.p = create_meter(
		0,											// run
		&(txa[channel].cfcomp.p->run),				// pointer to eqp 'run'
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,						// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_CFC_AV,									// index for average value
		TXA_CFC_PK,									// index for peak value
		TXA_CFC_GAIN,								// index for gain value
		&txa[channel].cfcomp.p->gain);				// pointer for gain computation

	txa[channel].bp0.p = create_bandpass(
		1,											// always runs
		0,											// position
		ch.dsp_size,						// size
		max(DEFAULT_COEFF, ch.dsp_size),			// number of coefficients
		0,											// flag for minimum phase
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer 
		txa[channel].f_low,							// low freq cutoff
		txa[channel].f_high,						// high freq cutoff
		ch.dsp_rate,						// samplerate
		1,											// wintype
		2.0f);										// gain

	txa[channel].compressor.p = create_compressor(
		1,											// run - OFF by default
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer
		3.0f);										// gain

	txa[channel].bp1.p = create_bandpass(
		1,											// ONLY RUNS WHEN COMPRESSOR IS USED
		0,											// position
		ch.dsp_size,						// size
		max(DEFAULT_COEFF, ch.dsp_size),			// number of coefficients
		0,											// flag for minimum phase
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer 
		txa[channel].f_low,							// low freq cutoff
		txa[channel].f_high,						// high freq cutoff
		ch.dsp_rate,						// samplerate
		1,											// wintype
		2.0f);										// gain	

	txa[channel].osctrl.p = create_osctrl(
		1,											// run
		ch.dsp_size,						// size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		ch.dsp_rate,						// sample rate
		1.95f);										// gain for clippings

	txa[channel].bp2.p = create_bandpass(
		1,											// ONLY RUNS WHEN COMPRESSOR IS USED
		0,											// position
		ch.dsp_size,						// size
		max(DEFAULT_COEFF, ch.dsp_size),			// number of coefficients
		0,											// flag for minimum phase
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer 
		txa[channel].f_low,							// low freq cutoff
		txa[channel].f_high,						// high freq cutoff
		ch.dsp_rate,						// samplerate
		1,											// wintype
		1.0f);										// gain

	txa[channel].compmeter.p = create_meter(
		0,											// run
		&(txa[channel].compressor.p->run),			// pointer to compressor 'run'
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,						// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_COMP_AV,								// index for average value
		TXA_COMP_PK,								// index for peak value
		-1,											// index for gain value
		0);											// pointer for gain computation

	txa[channel].alc.p = create_wcpagc(
		1,											// run - always ON
		5,											// mode
		1,											// 0 for max(I,Q), 1 for envelope
		txa[channel].midbuff,						// input buff pointer
		txa[channel].midbuff,						// output buff pointer
		ch.dsp_size,						// io_buffsize
		ch.dsp_rate,						// sample rate
		0.001f,										// tau_attack
		0.010f,										// tau_decay
		6,											// n_tau
		1.0f,										// max_gain
		1.0f,										// var_gain
		1.0f,										// fixed_gain
		1.0f,										// max_input
		1.0f,										// out_targ
		0.250f,										// tau_fast_backaverage
		0.005f,										// tau_fast_decay
		5.0f,										// pop_ratio
		0,											// hang_enable
		0.500f,										// tau_hang_backmult
		0.500f,										// hangtime
		2.000f,										// hang_thresh
		0.100f);										// tau_hang_decay

	txa[channel].ammod.p = create_ammod(
		0,											// run - OFF by default
		0,											// mode:  0=>AM, 1=>DSB
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to output buffer
		0.5f);										// carrier level


	txa[channel].fmmod.p = create_fmmod(
		0,											// run - OFF by default
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].midbuff,						// pointer to input buffer
		ch.dsp_rate,						// samplerate
		5000.0f,										// deviation
		300.0f,										// low cutoff frequency
		3000.0f,										// high cutoff frequency
		1,											// ctcss run control
		0.10f,										// ctcss level
		100.0f,										// ctcss frequency
		1,											// run bandpass filter
		max(DEFAULT_COEFF, ch.dsp_size),			// number coefficients for bandpass filter
		0);											// minimum phase flag

	txa[channel].gen1.p = create_gen(
		0,											// run
		ch.dsp_size,						// buffer size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		ch.dsp_rate,						// sample rate
		0);

	txa[channel].uslew.p = create_uslew(
		channel,									// channel
//		&ch_upslew,					// pointer to channel upslew flag
		ch.dsp_size,						// buffer size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		(float)ch.dsp_rate,						// sample rate
		0.000,										// delay time
		0.005f);										// upslew time

	txa[channel].alcmeter.p = create_meter(
		0,											// run
		0,											// optional pointer to a 'run'
		ch.dsp_size,						// size
		txa[channel].midbuff,						// pointer to buffer
		ch.dsp_rate,						// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_ALC_AV,									// index for average value
		TXA_ALC_PK,									// index for peak value
		TXA_ALC_GAIN,								// index for gain value
		&txa[channel].alc.p->gain);					// pointer for gain computation
#if 0
	txa[channel].sip1.p = create_siphon(
		0,											// run
		0,											// position
		0,											// mode
		0,											// disp
		dsp_size,						// input buffer size
		txa[channel].midbuff,						// input buffer
		16384,										// number of samples to buffer
		16384,										// fft size for spectrum
		1);											// specmode
#endif
	txa[channel].calcc.p = create_calcc(
		channel,									// channel number
		0,											// run calibration
		1024,										// input buffer size
		ch.in_rate,						// samplerate
		16,											// ints
		256,										// spi
		(1.0f / 0.4072f),								// hw_scale
		0.1f,										// mox delay
		0.0f,										// loop delay
		0.8f,										// ptol
		0,											// mox
		0,											// solidmox
		1,											// pin mode
		1,											// map mode
		0,											// stbl mode
		256,										// pin samples
		0.9f);										// alpha

	txa[channel].iqc.p0 = txa[channel].iqc.p1 = create_iqc(
		0,											// run
		ch.dsp_size,						// size
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		(float)ch.dsp_rate,				// sample rate
		16,											// ints
		0.005f,										// changeover time
		256);										// spi

	txa[channel].cfir.p = create_cfir(
		0,											// run
		ch.dsp_size,								// size
		max(DEFAULT_COEFF, ch.dsp_size),						// number of filter coefficients
		0,											// minimum phase flag
		txa[channel].midbuff,						// input buffer
		txa[channel].midbuff,						// output buffer
		ch.dsp_rate,								// input sample rate
		ch.out_rate,								// CIC input sample rate
		1,											// CIC differential delay
		640,										// CIC interpolation factor
		5,											// CIC integrator-comb pairs
		20000.0f,									// cutoff frequency
		2,											// brick-wall windowed rolloff
		0.0f,										// raised-cosine transition width
		0);											// window type

	txa[channel].rsmpout.p = create_resample(
		1,											// run - will be turned ON below if needed
		ch.dsp_size,						// input size
		txa[channel].midbuff,						// pointer to input buffer
		txa[channel].outbuff,						// pointer to output buffer
		ch.dsp_rate,								// input sample rate
		ch.out_rate,								// output sample rate
		0.0,										// select cutoff automatically
		0,											// select ncoef automatically
		0.980f);									// gain

	txa[channel].outmeter.p = create_meter(
		1,											// run
		0,											// optional pointer to another 'run'
		ch.dsp_outsize,					// size
		txa[channel].outbuff,						// pointer to buffer
		ch.out_rate,						// samplerate
		0.100f,										// averaging time constant
		0.100f,										// peak decay time constant
		txa[channel].meter,							// result vector
//		txa[channel].pmtupdate,						// locks for meter access
		TXA_OUT_AV,									// index for average value
		TXA_OUT_PK,									// index for peak value
		-1,											// index for gain value
		0);											// pointer for gain computation

	// turn OFF / ON resamplers as needed
//	TXAResCheck(channel);
}

void xtxa(int channel)
{
	xresample(txa[channel].rsmpin.p);				// input resampler
	xgen(txa[channel].gen0.p);						// input signal generator
	xpanel(txa[channel].panel.p);					// includes MIC gain
	xphrot(txa[channel].phrot.p);					// phase rotator
	xmeter(txa[channel].micmeter.p);				// MIC meter
	xamsqcap(txa[channel].amsq.p);					// downward expander capture
	xamsq(txa[channel].amsq.p);					    // downward expander action
	xeqp(txa[channel].eqp.p);						// pre-EQ
	xmeter(txa[channel].eqmeter.p);					// EQ meter
	xemphp(txa[channel].preemph.p, 0);				// FM pre-emphasis (first option)
	xwcpagc(txa[channel].leveler.p);				// Leveler
	xmeter(txa[channel].lvlrmeter.p);				// Leveler Meter
	xcfcomp(txa[channel].cfcomp.p, 0);				// Continuous Frequency Compressor with post-EQ
	xmeter(txa[channel].cfcmeter.p);				// CFC+PostEQ Meter
	xbandpass(txa[channel].bp0.p, 0);				// primary bandpass filter
	xcompressor(txa[channel].compressor.p);			// COMP compressor
	xbandpass(txa[channel].bp1.p, 0);				// aux bandpass (runs if COMP)
	xosctrl(txa[channel].osctrl.p);					// CESSB Overshoot Control
	xbandpass(txa[channel].bp2.p, 0);				// aux bandpass (runs if CESSB)
	xmeter(txa[channel].compmeter.p);				// COMP meter
	xwcpagc(txa[channel].alc.p);					// ALC
	xammod(txa[channel].ammod.p);					// AM Modulator
	xemphp(txa[channel].preemph.p, 1);				// FM pre-emphasis (second option)
	xfmmod(txa[channel].fmmod.p);					// FM Modulator
	xgen(txa[channel].gen1.p);						// output signal generator (TUN and Two-tone)
	xuslew(txa[channel].uslew.p);					// up-slew for AM, FM, and gens
	xmeter(txa[channel].alcmeter.p);				// ALC Meter
//	xsiphon(txa[channel].sip1.p, 0);				// siphon data for display
	xiqc(txa[channel].iqc.p0);						// PureSignal correction
	xcfir(txa[channel].cfir.p);						// compensating FIR filter (used Protocol_2 only)
	xresample(txa[channel].rsmpout.p);				// output resampler
	xmeter(txa[channel].outmeter.p);				// output meter
}

void SetTXAMode(int channel, int mode)
{
	if (txa[channel].mode != mode)
	{
		EnterCriticalSection(&csDSP);
		txa[channel].mode = mode;
		txa[channel].ammod.p->run = 0;
		txa[channel].fmmod.p->run = 0;
		txa[channel].preemph.p->run = 0;
		switch (mode)
		{
		case TXA_AM:
		case TXA_SAM:
			txa[channel].ammod.p->run = 1;
			txa[channel].ammod.p->mode = 0;
			break;
		case TXA_DSB:
			txa[channel].ammod.p->run = 1;
			txa[channel].ammod.p->mode = 1;
			break;
		case TXA_AM_LSB:
		case TXA_AM_USB:
			txa[channel].ammod.p->run = 1;
			txa[channel].ammod.p->mode = 2;
			break;
		case TXA_FM:
			txa[channel].fmmod.p->run = 1;
			txa[channel].preemph.p->run = 1;
			break;
		default:

			break;
		}
		TXASetupBPFilters(channel);
		LeaveCriticalSection(&csDSP);
	}
}

int TXAUslewCheck(int channel)
{
	return	(txa[channel].ammod.p->run == 1) ||
		(txa[channel].fmmod.p->run == 1) ||
		(txa[channel].gen0.p->run == 1) ||
		(txa[channel].gen1.p->run == 1);
}

void TXASetupBPFilters(int channel)
{
	txa[channel].bp0.p->run = 1;
	txa[channel].bp1.p->run = 0;
	txa[channel].bp2.p->run = 0;
	switch (txa[channel].mode)
	{
	case TXA_LSB:
	case TXA_USB:
	case TXA_CWL:
	case TXA_CWU:
	case TXA_DIGL:
	case TXA_DIGU:
	case TXA_SPEC:
	case TXA_DRM:
		CalcBandpassFilter(txa[channel].bp0.p, txa[channel].f_low, txa[channel].f_high, 2.0);
		if (txa[channel].compressor.p->run)
		{
			CalcBandpassFilter(txa[channel].bp1.p, txa[channel].f_low, txa[channel].f_high, 2.0);
			txa[channel].bp1.p->run = 1;
			if (txa[channel].osctrl.p->run)
			{
				CalcBandpassFilter(txa[channel].bp2.p, txa[channel].f_low, txa[channel].f_high, 1.0);
				txa[channel].bp2.p->run = 1;
			}
		}
		break;
	case TXA_DSB:
	case TXA_AM:
	case TXA_SAM:
	case TXA_FM:
		if (txa[channel].compressor.p->run)
		{
			CalcBandpassFilter(txa[channel].bp0.p, 0.0, txa[channel].f_high, 2.0);
			CalcBandpassFilter(txa[channel].bp1.p, 0.0, txa[channel].f_high, 2.0);
			txa[channel].bp1.p->run = 1;
			if (txa[channel].osctrl.p->run)
			{
				CalcBandpassFilter(txa[channel].bp2.p, 0.0, txa[channel].f_high, 1.0);
				txa[channel].bp2.p->run = 1;
			}
		}
		else
		{
			CalcBandpassFilter(txa[channel].bp0.p, txa[channel].f_low, txa[channel].f_high, 1.0);
		}
		break;
	case TXA_AM_LSB:
		CalcBandpassFilter(txa[channel].bp0.p, -txa[channel].f_high, 0.0, 2.0);
		if (txa[channel].compressor.p->run)
		{
			CalcBandpassFilter(txa[channel].bp1.p, -txa[channel].f_high, 0.0, 2.0);
			txa[channel].bp1.p->run = 1;
			if (txa[channel].osctrl.p->run)
			{
				CalcBandpassFilter(txa[channel].bp2.p, -txa[channel].f_high, 0.0, 1.0);
				txa[channel].bp2.p->run = 1;
			}
		}
		break;
	case TXA_AM_USB:
		CalcBandpassFilter(txa[channel].bp0.p, 0.0, txa[channel].f_high, 2.0);
		if (txa[channel].compressor.p->run)
		{
			CalcBandpassFilter(txa[channel].bp1.p, 0.0, txa[channel].f_high, 2.0);
			txa[channel].bp1.p->run = 1;
			if (txa[channel].osctrl.p->run)
			{
				CalcBandpassFilter(txa[channel].bp2.p, 0.0, txa[channel].f_high, 1.0);
				txa[channel].bp2.p->run = 1;
			}
		}
		break;
	}
}
