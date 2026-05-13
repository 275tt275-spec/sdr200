/*  emph.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2014, 2016, 2023 Warren Pratt, NR0V

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
*								Partitioned Overlap-Save FM Pre-Emphasis								*
*																										*
********************************************************************************************************/

#ifndef _emphp_h
#define _emphp_h
#include "firmin.h"
typedef struct _emphp
{
	int run;
	int position;
	int size;
	int nc;
	int mp;
	float* in;
	float* out;
	int ctype;
	float f_low;
	float f_high;
	float rate;
	FIRCORE p;
} emphp, *EMPHP;

extern EMPHP create_emphp (int run, int position, int size, int nc, int mp, 
	float* in, float* out, int rate, int ctype, float f_low, float f_high);
extern void destroy_emphp (EMPHP a);
extern void flush_emphp (EMPHP a);
extern void xemphp (EMPHP a, int position);
extern void setBuffers_emphp (EMPHP a, float* in, float* out);
extern void setSamplerate_emphp (EMPHP a, int rate);
extern void setSize_emphp (EMPHP a, int size);
void SetTXAFMEmphMP (int channel, int mp);
void SetTXAFMEmphNC (int channel, int nc);
void SetTXAFMPreEmphFreqs(int channel, float low, float high);

#endif

/********************************************************************************************************
*																										*
*										Overlap-Save FM Pre-Emphasis									*
*																										*
********************************************************************************************************/

#ifndef _emph_h
#define _emph_h

#include "pffft.h"

typedef struct _emph
{
	int run;
	int position;
	int size;
	float* in;
	float* out;
	int ctype;
	float f_low;
	float f_high;
	float* infilt;
	float* product;
	float* mults;
	float rate;
	s_pffft_plan* CFor;
	s_pffft_plan* CRev;
	float* pffft_work;
} emph, *EMPH;

extern EMPH create_emph (int run, int position, int size, float* in, float* out, int rate, int ctype, float f_low, float f_high);
extern void destroy_emph (EMPH a);
extern void flush_emph (EMPH a);
extern void xemph (EMPH a, int position);
extern void setBuffers_emph (EMPH a, float* in, float* out);
extern void setSamplerate_emph (EMPH a, int rate);
extern void setSize_emph (EMPH a, int size);

#endif
