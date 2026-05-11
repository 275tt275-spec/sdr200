/*  wcpAGC.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2011, 2012, 2013 Warren Pratt, NR0V

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

The author can be reached by email at  

warren@wpratt.com

*/

#ifndef _wcpagc_h
#define _wcpagc_h

#define MAX_SAMPLE_RATE		(384000.0)
#define MAX_N_TAU			(8)
#define MAX_TAU_ATTACK		(0.01)
#define RB_SIZE				(int)(MAX_SAMPLE_RATE * MAX_N_TAU * MAX_TAU_ATTACK + 1)

typedef struct _wcpagc
{
	int run;
	int mode;
	int pmode;
	float* in;
	float* out;
	int io_buffsize;
	float sample_rate;

	float tau_attack;
	float tau_decay;
	int n_tau;
	float max_gain;
	float var_gain;
	float fixed_gain;
	float min_volts;
	float max_input;
	float out_targ;
	float out_target;
	float inv_max_input;
	float slope_constant;

	float gain;
	float inv_out_target;

	int out_index;
	int in_index;
	int attack_buffsize;

	float* ring;
	float* abs_ring;
	int ring_buffsize;
	float ring_max;

	float attack_mult;
	float decay_mult;
	float volts;
	float save_volts;
	float out_sample[2];
	float abs_out_sample;
	int state;

	float tau_fast_backaverage;
	float fast_backmult;
	float onemfast_backmult;
	float fast_backaverage;
	float tau_fast_decay;
	float fast_decay_mult;
	float pop_ratio;

	int hang_enable;
	float hang_backaverage;
	float tau_hang_backmult;
	float hang_backmult;
	float onemhang_backmult;
	int hang_counter;
	float hangtime;
	float hang_thresh;
	float hang_level;

	float tau_hang_decay;
	float hang_decay_mult;
	int decay_type;
}wcpagc, *WCPAGC;

void loadWcpAGC (WCPAGC a);
void xwcpagc (WCPAGC a);
WCPAGC create_wcpagc (	int run,
								int mode,
								int pmode,
								float* in,
								float* out,
								int io_buffsize,
								int sample_rate,
								float tau_attack,
								float tau_decay,
								int n_tau,
								float max_gain,
								float var_gain,
								float fixed_gain,
								float max_input,
								float out_targ,
								float tau_fast_backaverage,
								float tau_fast_decay,
								float pop_ratio,
								int hang_enable,
								float tau_hang_backmult,
								float hangtime,
								float hang_thresh,
								float tau_hang_decay
								);

void destroy_wcpagc (WCPAGC a);
void flush_wcpagc (WCPAGC a);
void setBuffers_wcpagc (WCPAGC a, float* in, float* out);
void setSamplerate_wcpagc (WCPAGC a, int rate);
void setSize_wcpagc (WCPAGC a, int size);

// RXA Properties
void SetRXAAGCMode (int channel, int mode);
void SetRXAAGCFixed (int channel, float fixed_agc);
void SetRXAAGCAttack (int channel, int attack);
void SetRXAAGCDecay (int channel, int decay);
void SetRXAAGCHang (int channel, int hang);
void GetRXAAGCHangLevel(int channel, float *hangLevel);
void SetRXAAGCHangLevel(int channel, float hangLevel);
void GetRXAAGCHangThreshold(int channel, int *hangthreshold);
void SetRXAAGCHangThreshold (int channel, int hangthreshold);
void GetRXAAGCTop(int channel, float *max_agc);
void SetRXAAGCTop (int channel, float max_agc);
void SetRXAAGCSlope (int channel, int slope);
void SetRXAAGCThresh(int channel, float thresh, float size, float rate);
void GetRXAAGCThresh(int channel, float *thresh, float size, float rate);

// TXA Properties
void SetTXAALCSt (int channel, int state);
void SetTXAALCAttack (int channel, int attack);
void SetTXAALCDecay (int channel, int decay);
void SetTXAALCHang (int channel, int hang);
void SetTXALevelerSt (int channel, int state);
void SetTXALevelerAttack (int channel, int attack);
void SetTXALevelerDecay (int channel, int decay);
void SetTXALevelerHang (int channel, int hang);
void SetTXALevelerTop (int channel, float maxgain);

#endif

