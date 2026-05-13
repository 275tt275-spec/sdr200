/*  calcc.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2016, 2023 Warren Pratt, NR0V

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

#ifndef _calcc_h
#define _calcc_h
#include "delay.h"
#include "lmath.h"
typedef struct _calcc
{
	int channel;
	int runcal;
	int size;
	volatile long mox;
	volatile long solidmox;
	int rate;
	int ints;
	int spi;
	int nsamps;
	int npsamps;
	int pin;
	int map;
	int convex;
	int stbl;
	int scOK;
	float hw_scale;
	float rx_scale;
	float alpha;

	int tsamps;
	float* env_TX;
	float* env_RX;
	float* x;
	float* ym;
	float* yc;
	float* ys;
	float* cat;

	float* t;
	float* tmap;
	float* cm;
	float* cc;
	float* cs;
	float* cm_old;
	float* rxs;
	float* txs;
	float ptol;
	int* info;
	int* binfo;
	float txdel;
	BLDR ccbld;
	volatile long savecorr_bypass;
//	HANDLE Sem_SaveCorr;
	volatile long restcorr_bypass;
//	HANDLE Sem_RestCorr;
	volatile long calccorr_bypass;
//	HANDLE Sem_CalcCorr;
	volatile long turnoff_bypass;
//	HANDLE Sem_TurnOff;
	struct _ctrl
	{
		float moxdelay;
		float loopdelay;
		int state;
		int reset;
		int automode;
		int mancal;
		int turnon;
		int moxsamps;
		int moxcount;
		int count;
		int* cpi;
		int* sindex;
		int* sbase;
		int full_ints;
		int calcinprogress;
		volatile long calcdone;
		int waitsamps;
		int waitcount;
		float env_maxtx;
		volatile long running;
		int bs_count;
		volatile long current_state;
//		CRITICAL_SECTION cs_SafeToEnd;
	} ctrl;
	struct _disp
	{
		float* x;
		float* ym;
		float* yc;
		float* ys;
		float* cm;
		float* cc;
		float* cs;
//		CRITICAL_SECTION cs_disp;
	} disp;
	DELAY rxdelay;
	DELAY txdelay;
	struct _util
	{
		char savefile[256];
		char restfile[256];
		int ints;
		int channel;
		float* pm;
		float* pc;
		float* ps;
	} util;
	float* temptx;				//////////////////////////////////////////////////// temporary tx complex buffer - remove with new callback3port()
	float* temprx;				//////////////////////////////////////////////////// temporary rx complex buffer - remove with new callback3port()
} calcc, *CALCC;

extern CALCC create_calcc (int channel, int runcal, int size, int rate, int ints, int spi, float hw_scale, 
	float moxdelay, float loopdelay, float ptol, int mox, int solidmox, int pin, int map, int stbl,
	int npsamps, float alpha);

extern void destroy_calcc (CALCC a);
extern void flush_calcc (CALCC a);
void pscc (int channel, int size, float* tx, float* rx);
extern void PSSaveCorrection(void* pargs);
extern void PSRestoreCorrection(void* pargs);
extern void doPSCalcCorrection(void* arg);
extern void doPSTurnoff(void* arg);

#endif

// 'info' assignments:
//		 0 - builder for rx_scale
//		 1 - builder for cm
//		 2 - builder for cc
//		 3 - builder for cs
//		 4 - feedback level warning
//		 5 - count of attempted calibrations
//		 6 - results from scheck()
//       7 - results from rxscheck()
//
//		13 - dogcount
//		14 - indicates iqc_Run = 1
//		15 - control state
