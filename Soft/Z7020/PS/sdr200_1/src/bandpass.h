/*  bandpass.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2016, 2017 Warren Pratt, NR0V

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
*										Overlap-Save Bandpass											*
*																										*
********************************************************************************************************/

#ifndef _bps_h
#define _bps_h

#include "pffft.h"

typedef struct _bps
{
	int run;
	int position;
	int size;
	float* in;
	float* out;
	float f_low;
	float f_high;
	float* infilt;
	float* product;
	float* mults;
	float samplerate;
	int wintype;
	float gain;
	s_pffft_plan* CFor;
	s_pffft_plan* CRev;
	float* pffft_work;
}bps, *BPS;

extern BPS create_bps (int run, int position, int size, float* in, float* out, 
	float f_low, float f_high, int samplerate, int wintype, float gain);

extern void destroy_bps (BPS a);
extern void flush_bps (BPS a);
extern void xbps (BPS a, int pos);
extern void setBuffers_bps (BPS a, float* in, float* out);
extern void setSamplerate_bps (BPS a, int rate);
extern void setSize_bps (BPS a, int size);
extern void setFreqs_bps (BPS a, float f_low, float f_high);

// RXA Prototypes
void SetRXABPSRun (int channel, int run);
void SetRXABPSFreqs (int channel, float low, float high);

// TXA Prototypes
void SetTXABPSRun (int channel, int run);
void SetTXABPSFreqs (int channel, float low, float high);

#endif


/********************************************************************************************************
*																										*
*									Partitioned Overlap-Save Bandpass									*
*																										*
********************************************************************************************************/


#ifndef _bandpass_h
#define _bandpass_h
#include "firmin.h"
typedef struct _bandpass
{
	int run;
	int position;
	int size;
	int nc;
	int mp;
	float* in;
	float* out;
	float f_low;
	float f_high;
	float samplerate;
	int wintype;
	float gain;
	FIRCORE p;
}bandpass, *BANDPASS;

extern BANDPASS create_bandpass (int run, int position, int size, int nc, int mp, float* in, float* out, 
	float f_low, float f_high, int samplerate, int wintype, float gain);
extern void destroy_bandpass (BANDPASS a);
extern void flush_bandpass (BANDPASS a);
extern void xbandpass (BANDPASS a, int pos);
extern void setBuffers_bandpass (BANDPASS a, float* in, float* out);
extern void setSamplerate_bandpass (BANDPASS a, int rate);
extern void setSize_bandpass (BANDPASS a, int size);
extern void setGain_bandpass (BANDPASS a, float gain, int update);
extern void CalcBandpassFilter (BANDPASS a, float f_low, float f_high, float gain);
void SetRXABandpassFreqs (int channel, float f_low, float f_high);
void SetRXABandpassNC (int channel, int nc);
void SetRXABandpassMP (int channel, int mp);
void SetTXABandpassNC (int channel, int nc);
void SetTXABandpassMP (int channel, int mp);

#endif
