/*  cfcomp.c

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2017, 2021 Warren Pratt, NR0V

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

void calc_cfcwindow (CFCOMP a)
{
	int i;
	float arg0, arg1, cgsum, igsum, coherent_gain, inherent_power_gain, wmult;
	switch (a->wintype)
	{
	case 0:
		arg0 = 2.0f * PI / (float)a->fsize;
		cgsum = 0.0;
		igsum = 0.0;
		for (i = 0; i < a->fsize; i++)
		{
			a->window[i] = sqrtf (0.54f - 0.46f * cosf((float)i * arg0));
			cgsum += a->window[i];
			igsum += a->window[i] * a->window[i];
		}
		coherent_gain = cgsum / (float)a->fsize;
		inherent_power_gain = igsum / (float)a->fsize;
		wmult = 1.0f / sqrtf (inherent_power_gain);
		for (i = 0; i < a->fsize; i++)
			a->window[i] *= wmult;
		a->winfudge = sqrtf (1.0f / coherent_gain);
		break;
	case 1:
		arg0 = 2.0f * PI / (float)a->fsize;
		cgsum = 0.0;
		igsum = 0.0;
		for (i = 0; i < a->fsize; i++)
		{
			arg1 = cosf(arg0 * (float)i);
			a->window[i]  = sqrtf   (+0.21747f
				          + arg1 * (-0.45325f
				          + arg1 * (+0.28256f
				          + arg1 * (-0.04672f))));
			cgsum += a->window[i];
			igsum += a->window[i] * a->window[i];
		}
		coherent_gain = cgsum / (float)a->fsize;
		inherent_power_gain = igsum / (float)a->fsize;
		wmult = 1.0f / sqrtf (inherent_power_gain);
		for (i = 0; i < a->fsize; i++)
			a->window[i] *= wmult;
		a->winfudge = sqrtf (1.0f / coherent_gain);
		break;
	}
}

int fCOMPcompare (const void * a, const void * b)
{
	if (*(float*)a < *(float*)b)
		return -1;
	else if (*(float*)a == *(float*)b)
		return 0;
	else
		return 1;
}

void calc_comp (CFCOMP a)
{
	int i, j;
	float f, frac, fincr, fmax;
	float* sary;
	a->precomplin = powf (10.0f, 0.05f * a->precomp);
	a->prepeqlin  = powf (10.0f, 0.05f * a->prepeq);
	fmax = 0.5f * a->rate;
	for (i = 0; i < a->nfreqs; i++)
	{
		a->F[i] = max (a->F[i], 0.0f);
		a->F[i] = min (a->F[i], fmax);
		a->G[i] = max (a->G[i], 0.0f);
	}
	sary = (float *)malloc0 (3 * a->nfreqs * sizeof (float));
	for (i = 0; i < a->nfreqs; i++)
	{
		sary[3 * i + 0] = a->F[i];
		sary[3 * i + 1] = a->G[i];
		sary[3 * i + 2] = a->E[i];
	}
	qsort (sary, a->nfreqs, 3 * sizeof (float), fCOMPcompare);
	for (i = 0; i < a->nfreqs; i++)
	{
		a->F[i] = sary[3 * i + 0];
		a->G[i] = sary[3 * i + 1];
		a->E[i] = sary[3 * i + 2];
	}
	_aligned_free (sary);
	a->fp[0] = 0.0f;
	a->fp[a->nfreqs + 1] = fmax;
	a->gp[0] = a->G[0];
	a->gp[a->nfreqs + 1] = a->G[a->nfreqs - 1];
	a->ep[0] = a->E[0];								// cutoff?
	a->ep[a->nfreqs + 1] = a->E[a->nfreqs - 1];		// cutoff?
	for (i = 0, j = 1; i < a->nfreqs; i++, j++)
	{
		a->fp[j] = a->F[i];
		a->gp[j] = a->G[i];
		a->ep[j] = a->E[i];
	}
	fincr = a->rate / (float)a->fsize;
	j = 0;
	// print_impulse ("gp.txt", a->nfreqs+2, a->gp, 0, 0);
	for (i = 0; i < a->msize; i++)
	{
		f = fincr * (float)i;
		while (f >= a->fp[j + 1] && j < a->nfreqs) j++;
		frac = (f - a->fp[j]) / (a->fp[j + 1] - a->fp[j]);
		a->comp[i] = powf (10.0f, 0.05f * (frac * a->gp[j + 1] + (1.0f - frac) * a->gp[j]));
		a->peq[i]  = powf (10.0, 0.05f * (frac * a->ep[j + 1] + (1.0f - frac) * a->ep[j]));
		a->cfc_gain[i] = a->precomplin * a->comp[i];
	}
	// print_impulse ("comp.txt", a->msize, a->comp, 0, 0);
}

void calc_cfcomp(CFCOMP a)
{
	int i;
	a->incr = a->fsize / a->ovrlp;
	if (a->fsize > a->bsize)
		a->iasize = a->fsize;
	else
		a->iasize = a->bsize + a->fsize - a->incr;
	a->iainidx = 0;
	a->iaoutidx = 0;
	if (a->fsize > a->bsize)
	{
		if (a->bsize > a->incr)  a->oasize = a->bsize;
		else					 a->oasize = a->incr;
		a->oainidx = (a->fsize - a->bsize - a->incr) % a->oasize;
	}
	else
	{
		a->oasize = a->bsize;
		a->oainidx = a->fsize - a->incr;
	}
	a->init_oainidx = a->oainidx;
	a->oaoutidx = 0;
	a->msize = a->fsize / 2 + 1;
	a->window    = (float *)malloc0 (a->fsize  * sizeof(float));
	a->inaccum   = (float *)malloc0 (a->iasize * sizeof(float));
	a->forfftin  = (float *)malloc0 (a->fsize  * sizeof(float));
	a->forfftout = (float *)malloc0 (a->msize  * sizeof(complex));
	a->cmask     = (float *)malloc0 (a->msize  * sizeof(float));
	a->mask      = (float *)malloc0 (a->msize  * sizeof(float));
	a->cfc_gain  = (float *)malloc0 (a->msize  * sizeof(float));
	a->revfftin  = (float *)malloc0 (a->msize  * sizeof(complex));
	a->revfftout = (float *)malloc0 (a->fsize  * sizeof(float));
	a->save      = (float **)malloc0(a->ovrlp  * sizeof(float *));
	for (i = 0; i < a->ovrlp; i++)
		a->save[i] = (float *)malloc0(a->fsize * sizeof(float));
	a->outaccum = (float *)malloc0(a->oasize * sizeof(float));
	a->nsamps = 0;
	a->saveidx = 0;
	a->pffft_work = (float*)malloc0(2 * a->fsize * sizeof(complex));
	a->Rfor = pffft_plan_dft_1d(a->fsize, a->forfftin, a->forfftout, PFFFT_FORWARD, PFFFT_REAL);
	a->Rrev = pffft_plan_dft_1d(a->fsize, a->revfftin, a->revfftout, PFFFT_BACKWARD, PFFFT_REAL);
//	a->Rfor = fftw_plan_dft_r2c_1d(a->fsize, a->forfftin, (fftw_complex *)a->forfftout, FFTW_ESTIMATE);
//	a->Rrev = fftw_plan_dft_c2r_1d(a->fsize, (fftw_complex *)a->revfftin, a->revfftout, FFTW_ESTIMATE);
	calc_cfcwindow(a);

	a->pregain  = (2.0f * a->winfudge) / (float)a->fsize;
	a->postgain = 0.5f / ((float)a->ovrlp * a->winfudge);

	a->fp = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	a->gp = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	a->ep = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	a->comp = (float *) malloc0 (a->msize * sizeof (float));
	a->peq  = (float *) malloc0 (a->msize * sizeof (float));
	calc_comp (a);

	a->gain = 0.0;
	a->mmult = expf (-1.0f / (a->rate * a->ovrlp * a->mtau));
	a->dmult = expf (-(float)a->fsize / (a->rate * a->ovrlp * a->dtau));

	a->delta         = (float*)malloc0 (a->msize * sizeof(float));
	a->delta_copy    = (float*)malloc0 (a->msize * sizeof(float));
	a->cfc_gain_copy = (float*)malloc0 (a->msize * sizeof(float));
}

void decalc_cfcomp(CFCOMP a)
{
	int i;
	_aligned_free (a->cfc_gain_copy);
	_aligned_free (a->delta_copy);
	_aligned_free (a->delta);
	_aligned_free (a->peq);
	_aligned_free (a->comp);
	_aligned_free (a->ep);
	_aligned_free (a->gp);
	_aligned_free (a->fp);

	pffftw_destroy_plan(a->Rrev);
	pffftw_destroy_plan(a->Rfor);
	pffft_aligned_free(a->pffft_work);
	_aligned_free(a->outaccum);
	for (i = 0; i < a->ovrlp; i++)
		_aligned_free(a->save[i]);
	_aligned_free(a->save);
	_aligned_free(a->revfftout);
	_aligned_free(a->revfftin);
	_aligned_free(a->cfc_gain);
	_aligned_free(a->mask);
	_aligned_free(a->cmask);
	_aligned_free(a->forfftout);
	_aligned_free(a->forfftin);
	_aligned_free(a->inaccum);
	_aligned_free(a->window);
}

CFCOMP create_cfcomp (int run, int position, int peq_run, int size, float* in, float* out, int fsize, int ovrlp, 
	int rate, int wintype, int comp_method, int nfreqs, float precomp, float prepeq, float* F, float* G, float* E, float mtau, float dtau)
{
	CFCOMP a = (CFCOMP) malloc0 (sizeof (cfcomp));
	
	a->run = run;
	a->position = position;
	a->peq_run = peq_run;
	a->bsize = size;
	a->in = in;
	a->out = out;
	a->fsize = fsize;
	a->ovrlp = ovrlp;
	a->rate = (float)rate;
	a->wintype = wintype;
	a->comp_method = comp_method;
	a->nfreqs = nfreqs;
	a->precomp = precomp;
	a->prepeq = prepeq;
	a->mtau = mtau;					// compression metering time constant
	a->dtau = dtau;					// compression display time constant
	a->F = (float *)malloc0 (a->nfreqs * sizeof (float));
	a->G = (float *)malloc0 (a->nfreqs * sizeof (float));
	a->E = (float *)malloc0 (a->nfreqs * sizeof (float));
	memcpy (a->F, F, a->nfreqs * sizeof (float));
	memcpy (a->G, G, a->nfreqs * sizeof (float));
	memcpy (a->E, E, a->nfreqs * sizeof (float));
	calc_cfcomp (a);
	return a;
}

void flush_cfcomp (CFCOMP a)
{
	int i;
	memset (a->inaccum, 0, a->iasize * sizeof (float));
	for (i = 0; i < a->ovrlp; i++)
		memset (a->save[i], 0, a->fsize * sizeof (float));
	memset (a->outaccum, 0, a->oasize * sizeof (float));
	a->nsamps   = 0;
	a->iainidx  = 0;
	a->iaoutidx = 0;
	a->oainidx  = a->init_oainidx;
	a->oaoutidx = 0;
	a->saveidx  = 0;
	a->gain = 0.0;
	memset(a->delta, 0, a->msize * sizeof(float));
}

void destroy_cfcomp (CFCOMP a)
{
	decalc_cfcomp (a);
	_aligned_free (a->E);
	_aligned_free (a->G);
	_aligned_free (a->F);
	_aligned_free (a);
}


void calc_mask (CFCOMP a)
{
	int i;
	float comp, mask, delta;
	switch (a->comp_method)
	{
	case 0:
		{
			float mag, test;
			for (i = 0; i < a->msize; i++)
			{
				mag = sqrtf (a->forfftout[2 * i + 0] * a->forfftout[2 * i + 0] 
					      + a->forfftout[2 * i + 1] * a->forfftout[2 * i + 1]);
				comp = a->cfc_gain[i];
				test = comp * mag;
				if (test > 1.0f)
					mask = 1.0f / mag;
				else
					mask = comp;
				a->cmask[i] = mask;
				if (test > a->gain) a->gain = test;
				else a->gain = a->mmult * a->gain;

				delta = a->cfc_gain[i] - a->cmask[i];
				if (delta > a->delta[i]) a->delta[i] = delta;
				else a->delta[i] *= a->dmult;
			}
			break;
		}
	}
	if (a->peq_run)
	{
		for (i = 0; i < a->msize; i++)
		{
			a->mask[i] = a->cmask[i] * a->prepeqlin * a->peq[i];
		}
	}
	else
		memcpy (a->mask, a->cmask, a->msize * sizeof (float));
	// print_impulse ("mask.txt", a->msize, a->mask, 0, 0);
	a->mask_ready = 1;
}

void xcfcomp (CFCOMP a, int pos)
{
	if (a->run && pos == a->position)
	{
		int i, j, k, sbuff, sbegin;
		for (i = 0; i < 2 * a->bsize; i += 2)
		{
			a->inaccum[a->iainidx] = a->in[i];
			a->iainidx = (a->iainidx + 1) % a->iasize;
		}
		a->nsamps += a->bsize;
		while (a->nsamps >= a->fsize)
		{
			for (i = 0, j = a->iaoutidx; i < a->fsize; i++, j = (j + 1) % a->iasize)
				a->forfftin[i] = a->pregain * a->window[i] * a->inaccum[j];
			a->iaoutidx = (a->iaoutidx + a->incr) % a->iasize;
			a->nsamps -= a->incr;
			pffftw_execute(a->Rfor, a->pffft_work);
			calc_mask(a);
			for (i = 0; i < a->msize; i++)
			{
				a->revfftin[2 * i + 0] = a->mask[i] * a->forfftout[2 * i + 0];
				a->revfftin[2 * i + 1] = a->mask[i] * a->forfftout[2 * i + 1];
			}
			pffftw_execute(a->Rrev, a->pffft_work);
			for (i = 0; i < a->fsize; i++)
				a->save[a->saveidx][i] = a->postgain * a->window[i] * a->revfftout[i];
			for (i = a->ovrlp; i > 0; i--)
			{
				sbuff = (a->saveidx + i) % a->ovrlp;
				sbegin = a->incr * (a->ovrlp - i);
				for (j = sbegin, k = a->oainidx; j < a->incr + sbegin; j++, k = (k + 1) % a->oasize)
				{
					if ( i == a->ovrlp)
						a->outaccum[k]  = a->save[sbuff][j];
					else
						a->outaccum[k] += a->save[sbuff][j];
				}
			}
			a->saveidx = (a->saveidx + 1) % a->ovrlp;
			a->oainidx = (a->oainidx + a->incr) % a->oasize;
		}
		for (i = 0; i < a->bsize; i++)
		{
			a->out[2 * i + 0] = a->outaccum[a->oaoutidx];
			a->out[2 * i + 1] = 0.0;
			a->oaoutidx = (a->oaoutidx + 1) % a->oasize;
		}
	}
	else if (a->out != a->in)
		memcpy (a->out, a->in, a->bsize * sizeof (complex));
}

void setBuffers_cfcomp (CFCOMP a, float* in, float* out)
{
	a->in = in;
	a->out = out;
}

void setSamplerate_cfcomp (CFCOMP a, int rate)
{
	decalc_cfcomp (a);
	a->rate = (float)rate;
	calc_cfcomp (a);
}

void setSize_cfcomp (CFCOMP a, int size)
{
	decalc_cfcomp (a);
	a->bsize = size;
	calc_cfcomp (a);
}

/********************************************************************************************************
*																										*
*											TXA Properties												*
*																										*
********************************************************************************************************/

PORT
void SetTXACFCOMPRun (int channel, int run)
{
	CFCOMP a = txa[channel].cfcomp.p;
	if (a->run != run)
	{
		EnterCriticalSection (&ch[channel].csDSP);
		a->run = run;
		LeaveCriticalSection (&ch[channel].csDSP);
	}
}

PORT 
void SetTXACFCOMPPosition (int channel, int pos)
{
	CFCOMP a = txa[channel].cfcomp.p;
	if (a->position != pos)
	{
		EnterCriticalSection (&ch[channel].csDSP);
		a->position = pos;
		LeaveCriticalSection (&ch[channel].csDSP);
	}
}

PORT
void SetTXACFCOMPprofile (int channel, int nfreqs, float* F, float* G, float *E)
{
	CFCOMP a = txa[channel].cfcomp.p;
	EnterCriticalSection (&ch[channel].csDSP);
	a->nfreqs = nfreqs;
	_aligned_free (a->E);
	_aligned_free (a->F);
	_aligned_free (a->G);
	a->F = (float *)malloc0 (a->nfreqs * sizeof (float));
	a->G = (float *)malloc0 (a->nfreqs * sizeof (float));
	a->E = (float *)malloc0 (a->nfreqs * sizeof (float));
	memcpy (a->F, F, a->nfreqs * sizeof (float));
	memcpy (a->G, G, a->nfreqs * sizeof (float));
	memcpy (a->E, E, a->nfreqs * sizeof (float));
	_aligned_free (a->ep);
	_aligned_free (a->gp);
	_aligned_free (a->fp);
	a->fp = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	a->gp = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	a->ep = (float *) malloc0 ((a->nfreqs + 2) * sizeof (float));
	calc_comp(a);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXACFCOMPPrecomp (int channel, float precomp)
{
	CFCOMP a = txa[channel].cfcomp.p;
	if (a->precomp != precomp)
	{
		EnterCriticalSection (&ch[channel].csDSP);
		a->precomp = precomp;
		a->precomplin = powf (10.0f, 0.05f * a->precomp);
		for (int i = 0; i < a->msize; i++)
		{
			a->cfc_gain[i] = a->precomplin * a->comp[i];
		}
		LeaveCriticalSection (&ch[channel].csDSP);
	}
}

PORT
void SetTXACFCOMPPeqRun (int channel, int run)
{
	CFCOMP a = txa[channel].cfcomp.p;
	if (a->peq_run != run)
	{
		EnterCriticalSection (&ch[channel].csDSP);
		a->peq_run = run;
		LeaveCriticalSection (&ch[channel].csDSP);
	}
}

PORT
void SetTXACFCOMPPrePeq (int channel, float prepeq)
{
	CFCOMP a = txa[channel].cfcomp.p;
	EnterCriticalSection (&ch[channel].csDSP);
	a->prepeq = prepeq;
	a->prepeqlin = powf (10.0f, 0.05f * a->prepeq);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void GetTXACFCOMPDisplayCompression (int channel, float* comp_values, int* ready)
{
	int i;
	CFCOMP a = txa[channel].cfcomp.p;
	EnterCriticalSection(&ch[channel].csDSP);
	if (*ready = a->mask_ready)
	{
		memcpy(a->delta_copy, a->delta, a->msize * sizeof(float));
		memcpy(a->cfc_gain_copy, a->cfc_gain, a->msize * sizeof(float));
		a->mask_ready = 0;
	}
	LeaveCriticalSection(&ch[channel].csDSP);
	if (*ready)
	{
		for (i = 0; i < a->msize; i++)
			comp_values[i] = 20.0f * mlog10 (a->cfc_gain_copy[i] / (a->cfc_gain_copy[i] - a->delta_copy[i]));
	}
}
