/*  eq.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2016 Warren Pratt, NR0V

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
*									Partitioned Overlap-Save Equalizer									*
*																										*
********************************************************************************************************/

#ifndef _eqp_h
#define _eqp_h
#include "firmin.h"
typedef struct _eqp
{
	int run;
	int size;
	int nc;
	int mp;
	float* in;
	float* out;
	int nfreqs;
	float* F;
	float* G;
	int ctfmode;
	int wintype;
	float samplerate;
	FIRCORE p;
} eqp, *EQP;

extern float* eq_impulse (int N, int nfreqs, float* F, float* G, float samplerate, float scale, int ctfmode, int wintype);
extern EQP create_eqp (int run, int size, int nc, int mp, float *in, float *out, 
	int nfreqs, float* F, float* G, int ctfmode, int wintype, int samplerate);
extern void destroy_eqp (EQP a);
extern void flush_eqp (EQP a);
extern void xeqp (EQP a);
extern void setBuffers_eqp (EQP a, float* in, float* out);
extern void setSamplerate_eqp (EQP a, int rate);
extern void setSize_eqp (EQP a, int size);
void SetRXAEQNC (int channel, int nc);
void SetRXAEQMP (int channel, int mp);
void SetTXAEQNC (int channel, int nc);
void SetTXAEQMP (int channel, int mp);

#endif



/********************************************************************************************************
*																										*
*											Overlap-Save Equalizer										*
*																										*
********************************************************************************************************/

#ifndef _eq_h
#define _eq_h

#include "pffft.h"

typedef struct _eq
{
	int run;
	int size;
	float* in;
	float* out;
	int nfreqs;
	float* F;
	float* G;
	float* infilt;
	float* product;
	float* mults;
	float scale;
	int ctfmode;
	int wintype;
	float samplerate;
	s_pffft_plan* CFor;
	s_pffft_plan* CRev;
	float* pffft_work;
}eq, *EQ;

extern float* eq_mults (int size, int nfreqs, float* F, float* G, float samplerate, float scale, int ctfmode, int wintype);
extern EQ create_eq (int run, int size, float *in, float *out, int nfreqs, float* F, float* G, int ctfmode, int wintype, int samplerate);
extern void destroy_eq (EQ a);
extern void flush_eq (EQ a);
extern void xeq (EQ a);
extern void setBuffers_eq (EQ a, float* in, float* out);
extern void setSamplerate_eq (EQ a, int rate);
extern void setSize_eq (EQ a, int size);

#endif
