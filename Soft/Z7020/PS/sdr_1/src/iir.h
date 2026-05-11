/*  iir.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2014, 2022, 2023 Warren Pratt, NR0V

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
*											Bi-Quad Notch												*
*																										*
********************************************************************************************************/

#ifndef _snotch_h
#define _snotch_h

typedef struct _snotch
{
	int run;
	int size;
	float* in;
	float* out;
	float rate;
	float f;
	float bw;
	float a0, a1, a2, b1, b2;
	float x0, x1, x2, y1, y2;
//	CRITICAL_SECTION cs_update;
} snotch, *SNOTCH;

SNOTCH create_snotch (int run, int size, float* in, float* out, int rate, float f, float bw);
void destroy_snotch (SNOTCH a);
void flush_snotch (SNOTCH a);
void xsnotch (SNOTCH a);
void setBuffers_snotch (SNOTCH a, float* in, float* out);
void setSamplerate_snotch (SNOTCH a, int rate);
void setSize_snotch (SNOTCH a, int size);
void SetSNCTCSSFreq (SNOTCH a, float freq);
void SetSNCTCSSRun (SNOTCH a, int run);

#endif

/********************************************************************************************************
*																										*
*											Complex Bi-Quad Peaking										*
*																										*
********************************************************************************************************/

#ifndef _speak_h
#define _speak_h

typedef struct _speak
{
	int run;
	int size;
	float* in;
	float* out;
	float rate;
	float f;
	float bw;
	float cbw;
	float gain;
	float fgain;
	int nstages;
	int design;
	float a0, a1, a2, b1, b2;
	float *x0, *x1, *x2, *y0, *y1, *y2;
//	CRITICAL_SECTION cs_update;
} speak, *SPEAK;

SPEAK create_speak (int run, int size, float* in, float* out, int rate, float f, float bw, float gain, int nstages, int design);
void destroy_speak (SPEAK a);
void flush_speak (SPEAK a);
void xspeak (SPEAK a);
void setBuffers_speak (SPEAK a, float* in, float* out);
void setSamplerate_speak (SPEAK a, int rate);
void setSize_speak (SPEAK a, int size);
void SetRXABiQuadRun(int channel, int run);
void SetRXABiQuadFreq(int channel, float freq);
void SetRXABiQuadBandwidth(int channel, float bw);
void SetRXABiQuadGain(int channel, float gain);

#endif

/********************************************************************************************************
*																										*
*										Complex Multiple Peaking										*
*																										*
********************************************************************************************************/

#ifndef _mpeak_h
#define _mpeak_h

typedef struct _mpeak
{
	int run;
	int size;
	float* in;
	float* out;
	int rate;
	int npeaks;
	int* enable;
	float* f;
	float* bw;
	float* gain;
	int nstages;
	SPEAK* pfil;
	float* tmp;
	float* mix;
//	CRITICAL_SECTION cs_update;
} mpeak, *MPEAK;

MPEAK create_mpeak (int run, int size, float* in, float* out, int rate, int npeaks, int* enable, float* f, float* bw, float* gain, int nstages);
void destroy_mpeak (MPEAK a);
void flush_mpeak (MPEAK a);
void xmpeak (MPEAK a);
void setBuffers_mpeak (MPEAK a, float* in, float* out);
void setSamplerate_mpeak (MPEAK a, int rate);
void setSize_mpeak (MPEAK a, int size);

#endif

/********************************************************************************************************
*																										*
*										     Phase Rotator      										*
*																										*
********************************************************************************************************/

#ifndef _phrot_h
#define _phrot_h

typedef struct _phrot
{
	int reverse;
	int run;
	int size;
	float* in;
	float* out;
	int rate;
	float fc;
	int nstages;
	// normalized such that a0 = 1
	float a1, b0, b1;
	float *x0, *x1, *y0, *y1;
//	CRITICAL_SECTION cs_update;
} phrot, *PHROT;

PHROT create_phrot (int run, int size, float* in, float* out, int rate, float fc, int nstages);
void destroy_phrot (PHROT a);
void flush_phrot (PHROT a);
void xphrot (PHROT a);
void setBuffers_phrot (PHROT a, float* in, float* out);
void setSamplerate_phrot (PHROT a, int rate);
void setSize_phrot (PHROT a, int size);

#endif

/********************************************************************************************************
*																										*
*									Complex Bi-Quad Low-Pass				     						*
*																										*
********************************************************************************************************/

#ifndef _bqlp_h
#define _bqlp_h

typedef struct _bqlp
{
	int run;
	int size;
	float* in;
	float* out;
	float rate;
	float fc;
	float Q;
	float gain;
	int nstages;
	float a0, a1, a2, b1, b2;
	float* x0, * x1, * x2, * y0, * y1, * y2;
//	CRITICAL_SECTION cs_update;
} bqlp, *BQLP;

BQLP create_bqlp(int run, int size, float* in, float* out, float rate, float fc, float Q, float gain, int nstages);
void destroy_bqlp(BQLP a);
void flush_bqlp(BQLP a);
void xbqlp(BQLP a);
void setBuffers_bqlp(BQLP a, float* in, float* out);
void setSamplerate_bqlp(BQLP a, int rate);
void setSize_bqlp(BQLP a, int size);

#endif

/********************************************************************************************************
*																										*
*									   float Bi-Quad Low-Pass				     						*
*																										*
********************************************************************************************************/

#ifndef _dbqlp_h
#define _dbqlp_h

BQLP create_dbqlp(int run, int size, float* in, float* out, float rate, float fc, float Q, float gain, int nstages);
void flush_dbqlp(BQLP a);
void xdbqlp(BQLP a);
void setBuffers_dbqlp(BQLP a, float* in, float* out);
void setSamplerate_dbqlp(BQLP a, int rate);
void setSize_dbqlp(BQLP a, int size);

#endif

/********************************************************************************************************
*																										*
*									Complex Bi-Quad Band-Pass				     						*
*																										*
********************************************************************************************************/

#ifndef _bqbp_h
#define _bqbp_h

typedef struct _bqbp
{
	int run;
	int size;
	float* in;
	float* out;
	float rate;
	float f_low;
	float f_high;
	float gain;
	int nstages;
	float a0, a1, a2, b1, b2;
	float* x0, * x1, * x2, * y0, * y1, * y2;
//	CRITICAL_SECTION cs_update;
} bqbp, * BQBP;

BQBP create_bqbp(int run, int size, float* in, float* out, float rate, float f_low, float f_high, float gain, int nstages);
void destroy_bqbp(BQBP a);
void flush_bqbp(BQBP a);
void xbqbp(BQBP a);
void setBuffers_bqbp(BQBP a, float* in, float* out);
void setSamplerate_bqbp(BQBP a, int rate);
void setSize_bqbp(BQBP a, int size);

#endif

/********************************************************************************************************
*																										*
*									  float Bi-Quad Band-Pass				     						*
*																										*
********************************************************************************************************/

#ifndef _dbqbp_h
#define _dbqbp_h

BQBP create_dbqbp(int run, int size, float* in, float* out, float rate, float f_low, float f_high, float gain, int nstages);
void destroy_dbqbp(BQBP a);
void flush_dbqbp(BQBP a);
void xdbqbp(BQBP a);
void setBuffers_dbqbp(BQBP a, float* in, float* out);
void setSamplerate_dbqbp(BQBP a, int rate);
void setSize_dbqbp(BQBP a, int size);

#endif

/********************************************************************************************************
*																										*
*									   float Single-Pole High-Pass				   						*
*																										*
********************************************************************************************************/

#ifndef _dsphp_h
#define _dsphp_h

typedef struct _sphp
{
	int run;
	int size;
	float* in;
	float* out;
	float rate;
	float fc;
	int nstages;
	float a1, b0, b1;
	float* x0, * x1, * y0, * y1;
//	CRITICAL_SECTION cs_update;
} sphp, * SPHP;

SPHP create_dsphp(int run, int size, float* in, float* out, float rate, float fc, int nstages);
void destroy_dsphp(SPHP a);
void flush_dsphp(SPHP a);
void xdsphp(SPHP a);
void setBuffers_dsphp(SPHP a, float* in, float* out);
void setSamplerate_dsphp(SPHP a, int rate);
void setSize_dsphp(SPHP a, int size);

#endif

/********************************************************************************************************
*																										*
*								     Complex Single-Pole High-Pass				     					*
*																										*
********************************************************************************************************/

#ifndef _dphp_h
#define _dphp_h

SPHP create_sphp(int run, int size, float* in, float* out, float rate, float fc, int nstages);
void destroy_sphp(SPHP a);
void flush_sphp(SPHP a);
void xsphp(SPHP a);
void setBuffers_sphp(SPHP a, float* in, float* out);
void setSamplerate_sphp(SPHP a, int rate);
void setSize_sphp(SPHP a, int size);

#endif
