/*  firmin.c

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2016, 2025 Warren Pratt, NR0V

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

#include "comm.h"

/********************************************************************************************************
*																										*
*											Time-Domain FIR												*
*																										*
********************************************************************************************************/

void calc_firmin (FIRMIN a)
{
	a->h = fir_bandpass (a->nc, a->f_low, a->f_high, a->samplerate, a->wintype, 1, a->gain);
	a->rsize = a->nc;
	a->mask = a->rsize - 1;
	a->ring = (float *) malloc0 (a->rsize * sizeof (complex));
	a->idx = 0;
}

FIRMIN create_firmin (int run, int position, int size, float* in, float* out,
	int nc, float f_low, float f_high, int samplerate, int wintype, float gain)
{
	FIRMIN a = (FIRMIN) malloc0 (sizeof (firmin));
	a->run = run;
	a->position = position;
	a->size = size;
	a->in = in;
	a->out = out;
	a->nc = nc;
	a->f_low = f_low;
	a->f_high = f_high;
	a->samplerate = samplerate;
	a->wintype = wintype;
	a->gain = gain;
	calc_firmin (a);
	return a;
}

void destroy_firmin (FIRMIN a)
{
	_aligned_free (a->ring);
	_aligned_free (a->h);
	_aligned_free (a);
}

void flush_firmin (FIRMIN a)
{
	memset (a->ring, 0, a->rsize * sizeof (complex));
	a->idx = 0;
}

void xfirmin (FIRMIN a, int pos)
{
	if (a->run && a->position == pos)
	{
		int i, j, k;
		for (i = 0; i < a->size; i++)
		{
			a->ring[2 * a->idx + 0] = a->in[2 * i + 0];
			a->ring[2 * a->idx + 1] = a->in[2 * i + 1];
			a->out[2 * i + 0] = 0.0;
			a->out[2 * i + 1] = 0.0;
			k = a->idx;
			for (j = 0; j < a->nc; j++)
			{
				a->out[2 * i + 0] += a->h[2 * j + 0] * a->ring[2 * k + 0] - a->h[2 * j + 1] * a->ring[2 * k + 1];
				a->out[2 * i + 1] += a->h[2 * j + 0] * a->ring[2 * k + 1] + a->h[2 * j + 1] * a->ring[2 * k + 0]; 
				k = (k + a->mask) & a->mask;
			}
			a->idx = (a->idx + 1) & a->mask;
		}
	}
	else if (a->in != a->out)
		memcpy (a->out, a->in, a->size * sizeof (complex));
}

void setBuffers_firmin (FIRMIN a, float* in, float* out)
{
	a->in = in;
	a->out = out;
}

void setSamplerate_firmin (FIRMIN a, int rate)
{
	a->samplerate = (float)rate;
	calc_firmin (a);
}

void setSize_firmin (FIRMIN a, int size)
{
	a->size = size;
}

void setFreqs_firmin (FIRMIN a, float f_low, float f_high)
{
	a->f_low = f_low;
	a->f_high = f_high;
	calc_firmin (a);
}

/********************************************************************************************************
*																										*
*								Standalone Partitioned Overlap-Save Bandpass							*
*																										*
********************************************************************************************************/

void plan_firopt (FIROPT a)
{
	// must call for change in 'nc', 'size', 'out'
	int i;
	a->nfor = a->nc / a->size;
	a->buffidx = 0;
	a->idxmask = a->nfor - 1;
	a->fftin = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->fftout = (float **) malloc0 (a->nfor * sizeof (float *));
	a->fmask = (float **) malloc0 (a->nfor * sizeof (float *));
	a->maskgen = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->pcfor = (s_pffft_plan *) malloc0 (a->nfor * sizeof (s_pffft_plan));
	a->maskplan = (s_pffft_plan *) malloc0 (a->nfor * sizeof (s_pffft_plan));
	a->pffr_work = (float *) pffft_aligned_malloc (a->nfor * sizeof (complex));
	for (i = 0; i < a->nfor; i++)
	{
		a->fftout[i] = (float *) malloc0 (2 * a->size * sizeof (complex));
		a->fmask[i] = (float *) malloc0 (2 * a->size * sizeof (complex));
//		a->pcfor[i] = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->fftin, (fftw_complex *)a->fftout[i], FFTW_FORWARD, FFTW_PATIENT);
		a->pcfor[i].pffft = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
		a->pcfor[i].in = a->fftin;
		a->pcfor[i].out = a->fftout[i];
		a->pcfor[i].direction = PFFFT_FORWARD;
		a->maskplan[i].pffft = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
		a->maskplan[i].in = a->maskgen;
		a->maskplan[i].out = a->fmask[i];
		a->maskplan[i].direction = PFFFT_FORWARD;
//		a->maskplan[i] = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->maskgen, (fftw_complex *)a->fmask[i], FFTW_FORWARD, FFTW_PATIENT);
	}
	a->accum = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->crev = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
//	a->crev = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->accum, (fftw_complex *)a->out, FFTW_BACKWARD, FFTW_PATIENT);
}

void calc_firopt (FIROPT a)
{
	// call for change in frequency, rate, wintype, gain
	// must also call after a call to plan_firopt()
	int i;
	float* impulse = fir_bandpass (a->nc, a->f_low, a->f_high, a->samplerate, a->wintype, 1, a->gain);
	a->buffidx = 0;
	for (i = 0; i < a->nfor; i++)
	{
		// I right-justified the impulse response => take output from left side of output buff, discard right side
		// Be careful about flipping an asymmetrical impulse response.
		memcpy (&(a->maskgen[2 * a->size]), &(impulse[2 * a->size * i]), a->size * sizeof(complex));
		pffft_transform_ordered(a->maskplan[i].pffft, a->maskplan[i].in, a->maskplan[i].out, a->pffr_work, a->maskplan[i].direction);
//		fftw_execute (a->maskplan[i]);
	}
	_aligned_free (impulse);
}

FIROPT create_firopt (int run, int position, int size, float* in, float* out,
	int nc, float f_low, float f_high, int samplerate, int wintype, float gain)
{
	FIROPT a = (FIROPT) malloc0 (sizeof (firopt));
	a->run = run;
	a->position = position;
	a->size = size;
	a->in = in;
	a->out = out;
	a->nc = nc;
	a->f_low = f_low;
	a->f_high = f_high;
	a->samplerate = samplerate;
	a->wintype = wintype;
	a->gain = gain;
	plan_firopt (a);
	calc_firopt (a);
	return a;
}

void deplan_firopt (FIROPT a)
{
	int i;
	pffft_destroy_setup (a->crev);
	_aligned_free (a->accum);
	for (i = 0; i < a->nfor; i++)
	{
		_aligned_free (a->fftout[i]);
		_aligned_free (a->fmask[i]);
		pffft_destroy_setup (a->pcfor[i].pffft);
		pffft_destroy_setup (a->maskplan[i].pffft);
	}
	_aligned_free (a->maskplan);
	_aligned_free (a->pcfor);
	_aligned_free (a->maskgen);
	_aligned_free (a->fmask);
	_aligned_free (a->fftout);
	_aligned_free (a->fftin);
	pffft_aligned_free(a->pffr_work);
}

void destroy_firopt (FIROPT a)
{
	deplan_firopt (a);
	_aligned_free (a);
}

void flush_firopt (FIROPT a)
{
	int i; 
	memset (a->fftin, 0, 2 * a->size * sizeof (complex));
	for (i = 0; i < a->nfor; i++)
		memset (a->fftout[i], 0, 2 * a->size * sizeof (complex));
	a->buffidx = 0;
}

void xfiropt (FIROPT a, int pos)
{
	if (a->run && (a->position == pos))
	{
		int i, j, k;
		memcpy (&(a->fftin[2 * a->size]), a->in, a->size * sizeof (complex));
		pffft_transform_ordered(a->pcfor[a->buffidx].pffft, a->pcfor[a->buffidx].in, a->pcfor[a->buffidx].out, a->pffr_work, a->pcfor[a->buffidx].direction);
//		fftw_execute (a->pcfor[a->buffidx]);
		k = a->buffidx;
		memset (a->accum, 0, 2 * a->size * sizeof (complex));
		for (j = 0; j < a->nfor; j++)
		{
			for (i = 0; i < 2 * a->size; i++)
			{
				a->accum[2 * i + 0] += a->fftout[k][2 * i + 0] * a->fmask[j][2 * i + 0] - a->fftout[k][2 * i + 1] * a->fmask[j][2 * i + 1];
				a->accum[2 * i + 1] += a->fftout[k][2 * i + 0] * a->fmask[j][2 * i + 1] + a->fftout[k][2 * i + 1] * a->fmask[j][2 * i + 0];
			}
			k = (k + a->idxmask) & a->idxmask;
		}
		a->buffidx = (a->buffidx + 1) & a->idxmask;
		pffft_transform_ordered(a->crev, a->accum, a->out, a->pffr_work, PFFFT_BACKWARD);
//		fftw_execute (a->crev);
		memcpy (a->fftin, &(a->fftin[2 * a->size]), a->size * sizeof(complex));
	}
	else if (a->in != a->out)
		memcpy (a->out, a->in, a->size * sizeof (complex));
}

void setBuffers_firopt (FIROPT a, float* in, float* out)
{
	a->in = in;
	a->out = out;
	deplan_firopt (a);
	plan_firopt (a);
	calc_firopt (a);
}

void setSamplerate_firopt (FIROPT a, int rate)
{
	a->samplerate = rate;
	calc_firopt (a);
}

void setSize_firopt (FIROPT a, int size)
{
	a->size = size;
	deplan_firopt (a);
	plan_firopt (a);
	calc_firopt (a);
}

void setFreqs_firopt (FIROPT a, float f_low, float f_high)
{
	a->f_low = f_low;
	a->f_high = f_high;
	calc_firopt (a);
}

/********************************************************************************************************
*																										*
*									Partitioned Overlap-Save Filter Kernel								*
*																										*
********************************************************************************************************/


void plan_fircore (FIRCORE a)
{
	// must call for change in 'nc', 'size', 'out'
	int i;
	a->nfor = a->nc / a->size;
	a->cset = 0;
	a->buffidx = 0;
	a->idxmask = a->nfor - 1;
	a->fftin = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->fftout   = (float **) malloc0 (a->nfor * sizeof (float *));
	a->fmask    = (float ***) malloc0 (2 * sizeof (float **));
	a->fmask[0] = (float **) malloc0 (a->nfor * sizeof (float *));
	a->fmask[1] = (float **) malloc0 (a->nfor * sizeof (float *));
	a->maskgen = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->pcfor = (s_pffft_plan *) malloc0 (a->nfor * sizeof (s_pffft_plan));
	a->maskplan    = (s_pffft_plan **) malloc0 (2 * sizeof (s_pffft_plan *));
	a->maskplan[0] = (s_pffft_plan *) malloc0 (a->nfor * sizeof (s_pffft_plan));
	a->maskplan[1] = (s_pffft_plan *) malloc0 (a->nfor * sizeof (s_pffft_plan));
	a->pffr_work = (float *) pffft_aligned_malloc (a->nfor * sizeof (complex));
	for (i = 0; i < a->nfor; i++)
	{
		a->fftout[i]   = (float *) malloc0 (2 * a->size * sizeof (complex));
		a->fmask[0][i] = (float *) malloc0 (2 * a->size * sizeof (complex));
		a->fmask[1][i] = (float *) malloc0 (2 * a->size * sizeof (complex));
//		a->pcfor[i] = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->fftin, (fftw_complex *)a->fftout[i], FFTW_FORWARD, FFTW_PATIENT);
		a->pcfor[i].pffft = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
		a->pcfor[i].in = a->fftin;
		a->pcfor[i].out = a->fftout[i];
		a->pcfor[i].direction = PFFFT_FORWARD;
//		a->maskplan[0][i] = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->maskgen, (fftw_complex *)a->fmask[0][i], FFTW_FORWARD, FFTW_PATIENT);
		a->maskplan[0][i].pffft = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
		a->maskplan[0][i].in = a->maskgen;
		a->maskplan[0][i].out = a->fmask[0][i];
		a->maskplan[0][i].direction = PFFFT_FORWARD;
//		a->maskplan[1][i] = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->maskgen, (fftw_complex *)a->fmask[1][i], FFTW_FORWARD, FFTW_PATIENT);
		a->maskplan[1][i].pffft = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
		a->maskplan[1][i].in = a->maskgen;
		a->maskplan[1][i].out = a->fmask[1][i];
		a->maskplan[1][i].direction = PFFFT_FORWARD;
	}
	a->accum = (float *) malloc0 (2 * a->size * sizeof (complex));
	a->crev = pffft_new_setup(2 * a->size, PFFFT_COMPLEX);
//	a->crev = fftw_plan_dft_1d(2 * a->size, (fftw_complex *)a->accum, (fftw_complex *)a->out, FFTW_BACKWARD, FFTW_PATIENT);
	a->masks_ready = 0;
}

void calc_fircore (FIRCORE a, int flip)
{
	// call for change in frequency, rate, wintype, gain
	// must also call after a call to plan_firopt()
	int i;
	if (a->mp)
		mp_imp (a->nc, a->impulse, a->imp, 16, 0);
	else
		memcpy (a->imp, a->impulse, a->nc * sizeof (complex));
	for (i = 0; i < a->nfor; i++)
	{
		s_pffft_plan* p = &a->maskplan[1 - a->cset][i];
		// I right-justified the impulse response => take output from left side of output buff, discard right side
		// Be careful about flipping an asymmetrical impulse response.
		memcpy (&(a->maskgen[2 * a->size]), &(a->imp[2 * a->size * i]), a->size * sizeof(complex));
		pffft_transform_ordered(p->pffft, p->in, p->out, a->pffr_work, p->direction);
//		fftw_execute (a->maskplan[1 - a->cset][i]);
	}
	a->masks_ready = 1;
	if (flip)
	{
		EnterCriticalSection (&a->update);
		a->cset = 1 - a->cset;
		LeaveCriticalSection (&a->update);
		a->masks_ready = 0;
	}
}

FIRCORE create_fircore (int size, float* in, float* out, int nc, int mp, float* impulse)
{
	FIRCORE a = (FIRCORE) malloc0 (sizeof (fircore));
	a->size = size;
	a->in = in;
	a->out = out;
	a->nc = nc;
	a->mp = mp;
//	InitializeCriticalSectionAndSpinCount (&a->update, 2500);
	plan_fircore (a);
	a->impulse = (float *) malloc0 (a->nc * sizeof (complex));
	a->imp     = (float *) malloc0 (a->nc * sizeof (complex));
	memcpy (a->impulse, impulse, a->nc * sizeof (complex));
	calc_fircore (a, 1);
	return a;
}

void deplan_fircore (FIRCORE a)
{
	int i;
	pffft_destroy_setup (a->crev);
	_aligned_free (a->accum);
	for (i = 0; i < a->nfor; i++)
	{
		_aligned_free (a->fftout[i]);
		_aligned_free (a->fmask[0][i]);
		_aligned_free (a->fmask[1][i]);
		pffft_destroy_setup (a->pcfor[i].pffft);
		pffft_destroy_setup (a->maskplan[0][i].pffft);
		pffft_destroy_setup (a->maskplan[1][i].pffft);
	}
	_aligned_free (a->maskplan[0]);
	_aligned_free (a->maskplan[1]);
	_aligned_free (a->maskplan);
	_aligned_free (a->pcfor);
	_aligned_free (a->maskgen);
	_aligned_free (a->fmask[0]);
	_aligned_free (a->fmask[1]);
	_aligned_free (a->fmask);
	_aligned_free (a->fftout);
	_aligned_free (a->fftin);
	pffft_aligned_free(a->pffr_work);
}

void destroy_fircore (FIRCORE a)
{
	deplan_fircore (a);
	_aligned_free (a->imp);
	_aligned_free (a->impulse);
	DeleteCriticalSection (&a->update);
	_aligned_free (a);
}

void flush_fircore (FIRCORE a)
{
	int i; 
	memset (a->fftin, 0, 2 * a->size * sizeof (complex));
	for (i = 0; i < a->nfor; i++)
		memset (a->fftout[i], 0, 2 * a->size * sizeof (complex));
	a->buffidx = 0;
}

void xfircore (FIRCORE a)
{
	int i, j, k;
	memcpy (&(a->fftin[2 * a->size]), a->in, a->size * sizeof (complex));
	s_pffft_plan* p = &a->pcfor[a->buffidx];
	pffft_transform_ordered(p->pffft, p->in, p->out, a->pffr_work, p->direction);
//	fftw_execute (a->pcfor[a->buffidx]);
	k = a->buffidx;
	memset (a->accum, 0, 2 * a->size * sizeof (complex));
	EnterCriticalSection (&a->update);
	float* accum = a->accum;
	float** fftout = a->fftout;
	float*** fmask = a->fmask;
	int cset = a->cset;
	int idxmask = a->idxmask;
	int sz = a->size;
	int nfor = a->nfor;
	for (j = 0; j < nfor; j++)
	{
		for (i = 0; i < 2 * sz; i++)
		{
			accum[2 * i + 0] += fftout[k][2 * i + 0] * fmask[cset][j][2 * i + 0] - fftout[k][2 * i + 1] * fmask[cset][j][2 * i + 1];
			accum[2 * i + 1] += fftout[k][2 * i + 0] * fmask[cset][j][2 * i + 1] + fftout[k][2 * i + 1] * fmask[cset][j][2 * i + 0];
		}
		k = (k + idxmask) & idxmask;
	}
	LeaveCriticalSection (&a->update);
	a->buffidx = (a->buffidx + 1) & idxmask;
	pffft_transform_ordered(a->crev, a->accum, a->out, a->pffr_work, PFFFT_BACKWARD);
//	fftw_execute (a->crev);
	memcpy (a->fftin, &(a->fftin[2 * a->size]), a->size * sizeof(complex));
}

void setBuffers_fircore (FIRCORE a, float* in, float* out)
{
	a->in = in;
	a->out = out;
	deplan_fircore (a);
	plan_fircore (a);
	calc_fircore (a, 1);
}

void setSize_fircore (FIRCORE a, int size)
{
	a->size = size;
	deplan_fircore (a);
	plan_fircore (a);
	calc_fircore (a, 1);
}

void setImpulse_fircore (FIRCORE a, float* impulse, int update)
{
	memcpy (a->impulse, impulse, a->nc * sizeof (complex));
	calc_fircore (a, update);
}

void setNc_fircore (FIRCORE a, int nc, float* impulse)
{
	// because of FFT planning, this will probably cause a glitch in audio if done during dataflow
	deplan_fircore (a);
	_aligned_free (a->impulse);
	_aligned_free (a->imp);
	a->nc = nc;
	plan_fircore (a);
	a->imp     = (float *) malloc0 (a->nc * sizeof (complex));
	a->impulse = (float *) malloc0 (a->nc * sizeof (complex));
	memcpy (a->impulse, impulse, a->nc * sizeof (complex));
	calc_fircore (a, 1);
}

void setMp_fircore (FIRCORE a, int mp)
{
	a->mp = mp;
	calc_fircore (a, 1);
}

void setUpdate_fircore (FIRCORE a)
{
	if (a->masks_ready)
	{
		EnterCriticalSection (&a->update);
		a->cset = 1 - a->cset;
		LeaveCriticalSection (&a->update);
		a->masks_ready = 0;
	}
}
