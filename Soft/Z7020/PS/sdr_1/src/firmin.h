/*  firmin.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2016 Warren Pratt, NR0V

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

/********************************************************************************************************
*																										*
*											Time-Domain FIR												*
*																										*
********************************************************************************************************/

#ifndef _firmin_h
#define _firmin_h

#include "pffft.h"

typedef struct _firmin
{
	int run;				// run control
	int position;			// position at which to execute
	int size;				// input/output buffer size, power of two
	float* in;				// input buffer
	float* out;			// output buffer, can be same as input
	int nc;					// number of filter coefficients, power of two
	float f_low;			// low cutoff frequency
	float f_high;			// high cutoff frequency
	float* ring;			// internal complex ring buffer
	float* h;				// complex filter coefficients
	int rsize;				// ring size, number of complex samples, power of two
	int mask;				// mask to update indexes
	int idx;				// ring input/output index
	float samplerate;		// sample rate
	int wintype;			// filter window type
	float gain;			// filter gain
}firmin, *FIRMIN;

extern FIRMIN create_firmin (int run, int position, int size, float* in, float* out,
	int nc, float f_low, float f_high, int samplerate, int wintype, float gain);
extern void destroy_firmin (FIRMIN a);
extern void flush_firmin (FIRMIN a);
extern void xfirmin (FIRMIN a, int pos);
extern void setBuffers_firmin (FIRMIN a, float* in, float* out);
extern void setSamplerate_firmin (FIRMIN a, int rate);
extern void setSize_firmin (FIRMIN a, int size);
extern void setFreqs_firmin (FIRMIN a, float f_low, float f_high);

#endif

/********************************************************************************************************
*																										*
*								Standalone Partitioned Overlap-Save Bandpass							*
*																										*
********************************************************************************************************/

#ifndef _firopt_h
#define _firopt_h

typedef struct _firopt
{
	int run;				// run control
	int position;			// position at which to execute
	int size;				// input/output buffer size, power of two
	float* in;				// input buffer
	float* out;			// output buffer, can be same as input
	int nc;					// number of filter coefficients, power of two, >= size
	float f_low;			// low cutoff frequency
	float f_high;			// high cutoff frequency
	float samplerate;		// sample rate
	int wintype;			// filter window type
	float gain;			// filter gain
	int nfor;				// number of buffers in delay line
	float* fftin;			// fft input buffer
	float** fmask;			// frequency domain masks
	float** fftout;		// fftout delay line
	float* accum;			// frequency domain accumulator
	int buffidx;			// fft out buffer index
	int idxmask;			// mask for index computations
	float* maskgen;		// input for mask generation FFT
	s_pffft_plan* pcfor;		// array of forward FFT plans
	PFFFT_Setup* crev;			// reverse fft plan
	s_pffft_plan* maskplan;	// plans for frequency domain masks
	float* pffr_work;
} firopt, *FIROPT;

FIROPT create_firopt (int run, int position, int size, float* in, float* out,
	int nc, float f_low, float f_high, int samplerate, int wintype, float gain);
void xfiropt (FIROPT a, int pos);
void destroy_firopt (FIROPT a);
void flush_firopt (FIROPT a);
void setBuffers_firopt (FIROPT a, float* in, float* out);
void setSamplerate_firopt (FIROPT a, int rate);
void setSize_firopt (FIROPT a, int size);
void setFreqs_firopt (FIROPT a, float f_low, float f_high);

#endif

/********************************************************************************************************
*																										*
*									Partitioned Overlap-Save Filter Kernel								*
*																										*
********************************************************************************************************/

#ifndef _fircore_h
#define _fircore_h

typedef struct _fircore
{
	int size;				// input/output buffer size, power of two
	float* in;				// input buffer
	float* out;			// output buffer, can be same as input
	int nc;					// number of filter coefficients, power of two, >= size
	float* impulse;		// impulse response of filter
	float* imp;
	int nfor;				// number of buffers in delay line
	float* fftin;			// fft input buffer
	float*** fmask;		// frequency domain masks
	float** fftout;		// fftout delay line
	float* accum;			// frequency domain accumulator
	int buffidx;			// fft out buffer index
	int idxmask;			// mask for index computations
	float* maskgen;		// input for mask generation FFT
	s_pffft_plan* pcfor;		// array of forward FFT plans
	PFFFT_Setup* crev;			// reverse fft plan
	s_pffft_plan** maskplan;	// plans for frequency domain masks
	float* pffr_work;
//	CRITICAL_SECTION update;
	int cset;
	int mp;
	int masks_ready;
} fircore, *FIRCORE;

FIRCORE create_fircore (int size, float* in, float* out,
	int nc, int mp, float* impulse);
void xfircore (FIRCORE a);
void destroy_fircore (FIRCORE a);
void flush_fircore (FIRCORE a);
void setBuffers_fircore (FIRCORE a, float* in, float* out);
void setSize_fircore (FIRCORE a, int size);
void setImpulse_fircore (FIRCORE a, float* impulse, int update);
void setNc_fircore (FIRCORE a, int nc, float* impulse);
void setMp_fircore (FIRCORE a, int mp);
void setUpdate_fircore (FIRCORE a);

#endif
