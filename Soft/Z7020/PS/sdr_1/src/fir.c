/*  fir.c

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2016, 2022, 2025 Warren Pratt, NR0V

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

warren@pratt.one
*/

#include <math.h>

#include "comm.h"
#include "pffft.h"

float* fftcv_mults (int NM, float* c_impulse)
{
	float* mults        = (float *) pffft_aligned_malloc (NM * sizeof (complex));
	float* cfft_impulse = (float *) pffft_aligned_malloc (NM * sizeof (complex));
	float* work = (float *) pffft_aligned_malloc (NM * sizeof (complex));
	PFFFT_Setup* ptmp = pffft_new_setup(NM, PFFFT_COMPLEX);

	memset (cfft_impulse, 0, NM * sizeof (complex));
	// store complex coefs right-justified in the buffer
	memcpy (&(cfft_impulse[NM - 2]), c_impulse, (NM / 2 + 1) * sizeof(complex));

	pffft_transform_ordered(ptmp, cfft_impulse, mults, work, PFFFT_FORWARD);
	pffft_destroy_setup(ptmp);
	pffft_aligned_free(cfft_impulse);
	pffft_aligned_free(work);
	return mults;
}

float* get_fsamp_window(int N, int wintype)
{
	int i;
	float arg0, arg1;
	float* window = (float *) pffft_aligned_malloc (N * sizeof(float));
	switch (wintype)
	{
	case 0:
		arg0 = 2.0 * PI / ((float)N - 1.0);
		for (i = 0; i < N; i++)
		{
			arg1 = cosf(arg0 * (float)i);
			window[i]  =   +0.21747
				+ arg1 *  (-0.45325
				+ arg1 *  (+0.28256
				+ arg1 *  (-0.04672)));
		}
		break;
	case 1:
		arg0 = 2.0 * PI / ((double)N - 1.0);
		for (i = 0; i < N; ++i)
		{
			arg1 = cosf(arg0 * (double)i);
			window[i]  =   +6.3964424114390378e-02
				+ arg1 *  (-2.3993864599352804e-01
				+ arg1 *  (+3.5015956323820469e-01
				+ arg1 *  (-2.4774111897080783e-01
				+ arg1 *  (+8.5438256055858031e-02
				+ arg1 *  (-1.2320203369293225e-02
				+ arg1 *  (+4.3778825791773474e-04))))));
		}
		break;
	default:
		for (i = 0; i < N; i++)
			window[i] = 1.0;
	}
	return window;
}

float* fir_fsamp_odd (int N, float* A, int rtype, float scale, int wintype)
{
	int i, j;
	int mid = (N - 1) / 2;
	float mag, phs;
	float* window;
	float *fcoef     = (float *) pffft_aligned_malloc (N * sizeof (complex));
	float *c_impulse = (float *) pffft_aligned_malloc (N * sizeof (complex));
	float* work = (float *) pffft_aligned_malloc (N * sizeof (complex));
	PFFFT_Setup* ptmp = pffft_new_setup(N, PFFFT_COMPLEX);

	float local_scale = 1.0 / (float)N;
	for (i = 0; i <= mid; i++)
	{
		mag = A[i] * local_scale;
		phs = - (float)mid * TWOPI * (float)i / (float)N;
		fcoef[2 * i + 0] = mag * cos (phs);
		fcoef[2 * i + 1] = mag * sin (phs);
	}
	for (i = mid + 1, j = 0; i < N; i++, j++)
	{
		fcoef[2 * i + 0] = + fcoef[2 * (mid - j) + 0];
		fcoef[2 * i + 1] = - fcoef[2 * (mid - j) + 1];
	}

	pffft_transform_ordered(ptmp, fcoef, c_impulse, work, PFFFT_BACKWARD);
	pffft_destroy_setup(ptmp);
	pffft_aligned_free(fcoef);
	pffft_aligned_free(work);
	window = get_fsamp_window(N, wintype);
	switch (rtype)
	{
	case 0:
		for (i = 0; i < N; i++)
			c_impulse[i] = scale * c_impulse[2 * i] * window[i];
		break;
	case 1:
		for (i = 0; i < N; i++)
		{
			c_impulse[2 * i + 0] *= scale * window[i];
			c_impulse[2 * i + 1] = 0.0;
		}
		break;
	}
	pffft_aligned_free(window);
	return c_impulse;
}

float* fir_fsamp (int N, float* A, int rtype, float scale, int wintype)
{
	int n, i, j, k;
	float sum;
	float* window;
	float *c_impulse = (float *) pffft_aligned_malloc (N * sizeof (complex));

	if (N & 1)
	{
		int M = (N - 1) / 2;
		for (n = 0; n < M + 1; n++)
		{
			sum = 0.0;
			for (k = 1; k < M + 1; k++)
				sum += 2.0 * A[k] * cos(TWOPI * (n - M) * k / N);
			c_impulse[2 * n + 0] = (1.0 / N) * (A[0] + sum);
			c_impulse[2 * n + 1] = 0.0;
		}
		for (n = M + 1, j = 1; n < N; n++, j++)
		{
			c_impulse[2 * n + 0] = c_impulse[2 * (M - j) + 0];
			c_impulse[2 * n + 1] = 0.0;
		}
	}
	else
	{
		float M = (float)(N - 1) / 2.0;
		for (n = 0; n < N / 2; n++)
		{
			sum = 0.0;
			for (k = 1; k < N / 2; k++)
				sum += 2.0 * A[k] * cos(TWOPI * (n - M) * k / N);
			c_impulse[2 * n + 0] = (1.0 / N) * (A[0] + sum);
			c_impulse[2 * n + 1] = 0.0;
		}
		for (n = N / 2, j = 1; n < N; n++, j++)
		{
			c_impulse[2 * n + 0] = c_impulse[2 * (N / 2 - j) + 0];
			c_impulse[2 * n + 1] = 0.0;
		}
	}
	window = get_fsamp_window (N, wintype);
	switch (rtype)
	{
	case 0:
		for (i = 0; i < N; i++)
			c_impulse[i] = scale * c_impulse[2 * i] * window[i];
		break;
	case 1:
		for (i = 0; i < N; i++)
			{
				c_impulse[2 * i + 0] *= scale * window[i];
				c_impulse[2 * i + 1] = 0.0;
			}
		break;
	}
	pffft_aligned_free(window);
	return c_impulse;
}

float* fir_bandpass (int N, float f_low, float f_high, float samplerate, int wintype, int rtype, float scale)
{
	// check for previous in the cache
	struct Params 
	{
		int N;
		int wintype;
		int rtype;
		float f_low;
		float f_high;
		float samplerate;
		float scale;
	};

	struct Params params;
	memset(&params, 0, sizeof (params));
	params.N = N;
	params.wintype = wintype;
	params.rtype = rtype;
	params.f_low = f_low;
	params.f_high = f_high;
	params.samplerate = samplerate;
	params.scale = scale;

	HASH_T h = fnv1a_hash(&params, sizeof(params));
	float* imp = get_impulse_cache_entry(FIR_CACHE, h, N);
	if (imp) return imp;
	//

	float *c_impulse = (float *) pffft_aligned_malloc (N * sizeof (complex));
	float ft = (f_high - f_low) / (2.0 * samplerate);
	float ft_rad = TWOPI * ft;
	float w_osc = PI * (f_high + f_low) / samplerate;
	int i, j;
	float m = 0.5 * (float)(N - 1);
	float delta = PI / m;
	float cosphi;
	float posi, posj;
	float sinc, window, coef;

	if (N & 1)
	{
		switch (rtype)
		{
		case 0:
			c_impulse[N >> 1] = scale * 2.0 * ft;
			break;
		case 1:
			c_impulse[N - 1] = scale * 2.0 * ft;
			c_impulse[  N  ] = 0.0;
			break;
		}
	}
	for (i = (N + 1) / 2, j = N / 2 - 1; i < N; i++, j--)
	{
		posi = (double)i - m;
		posj = (double)j - m;
		sinc = sin (ft_rad * posi) / (PI * posi);
		switch (wintype)
		{
		case 0:	// Blackman-Harris 4-term
			cosphi = cos (delta * i);
			window  =             + 0.21747
					+ cosphi *  ( - 0.45325
					+ cosphi *  ( + 0.28256
					+ cosphi *  ( - 0.04672 )));
			break;
		case 1:	// Blackman-Harris 7-term
		default:
			cosphi = cos (delta * i);
			window	=			  + 6.3964424114390378e-02
					+ cosphi *  ( - 2.3993864599352804e-01
					+ cosphi *  ( + 3.5015956323820469e-01
					+ cosphi *	( - 2.4774111897080783e-01
					+ cosphi *  ( + 8.5438256055858031e-02
					+ cosphi *	( - 1.2320203369293225e-02
					+ cosphi *	( + 4.3778825791773474e-04 ))))));
			break;
		}
		coef = scale * sinc * window;
		switch (rtype)
		{
		case 0:
			c_impulse[i] = + coef * cos (posi * w_osc);
			c_impulse[j] = + coef * cos (posj * w_osc);
			break;
		case 1:
			c_impulse[2 * i + 0] = + coef * cos (posi * w_osc);
			c_impulse[2 * i + 1] = - coef * sin (posi * w_osc);
			c_impulse[2 * j + 0] = + coef * cos (posj * w_osc);
			c_impulse[2 * j + 1] = - coef * sin (posj * w_osc);
			break;
		}
	}

	// store in cache
	add_impulse_to_cache(FIR_CACHE, h, N, c_impulse);

	return c_impulse;
}


void analytic (int N, float* in, float* out)
{
	int i;
	float inv_N = 1.0 / (float)N;
	float two_inv_N = 2.0 * inv_N;
	float* x = (float *) pffft_aligned_malloc (N * sizeof (complex));
	float* work = (float *) pffft_aligned_malloc (N * sizeof (complex));
	PFFFT_Setup* pfor = pffft_new_setup(N, PFFFT_COMPLEX);
	PFFFT_Setup* prev = pffft_new_setup(N, PFFFT_COMPLEX);
	pffft_transform_ordered(pfor, in, x, work, PFFFT_FORWARD);
	x[0] *= inv_N;
	x[1] *= inv_N;
	for (i = 1; i < N / 2; i++)
	{
		x[2 * i + 0] *= two_inv_N;
		x[2 * i + 1] *= two_inv_N;
	}
	x[N + 0] *= inv_N;
	x[N + 1] *= inv_N;
	memset (&x[N + 2], 0, (N - 2) * sizeof (float));
	pffft_transform_ordered(prev, x, out, work, PFFFT_BACKWARD);

	pffft_destroy_setup (prev);
	pffft_destroy_setup (pfor);
	pffft_aligned_free(x);
	pffft_aligned_free(work);
}

void mp_imp (int N, float* fir, float* mpfir, int pfactor, int polarity)
{
	// check for previous in the cache
	struct Params 
	{
		int N;
		int pfactor;
		int polarity;
	};

	struct Params params;
	memset(&params, 0, sizeof(params));
	params.N = N;
	params.pfactor = pfactor;
	params.polarity = polarity;

	HASH_T h = fnv1a_hash(&params, sizeof(params));

	size_t arr_len = N * sizeof(complex);
	HASH_T hf = fnv1a_hash((uint8_t*)fir, arr_len);
	h ^= hf + GOLDEN_RATIO + (h << 6) + (h >> 2);

	float* imp = get_impulse_cache_entry(MP_CACHE, h, N);
	if (imp)
	{
		memcpy(mpfir, imp, N * sizeof(complex)); // need to copy into mpfir
		pffft_aligned_free(imp);
		return;
	}
	//

	int i;
	int size = N * pfactor;
	float inv_PN = 1.0 / (float)size;
	float* firpad  = (float *) pffft_aligned_malloc (size * sizeof (complex));
	float* firfreq = (float *) pffft_aligned_malloc (size * sizeof (complex));
	float* mag     = (float *) pffft_aligned_malloc (size * sizeof (float));
	float* ana     = (float *) pffft_aligned_malloc (size * sizeof (complex));
	float* impulse = (float *) pffft_aligned_malloc (size * sizeof (complex));
	float* newfreq = (float *) pffft_aligned_malloc (size * sizeof (complex));
	memcpy (firpad, fir, N * sizeof (complex));
	float* work = (float *) pffft_aligned_malloc (size * sizeof (complex));
	PFFFT_Setup* pfor = pffft_new_setup(size, PFFFT_COMPLEX);
	PFFFT_Setup* prev = pffft_new_setup(size, PFFFT_COMPLEX);

	pffft_transform_ordered(pfor, firpad, firfreq, work, PFFFT_FORWARD);
	for (i = 0; i < size; i++)
	{
		mag[i] = sqrt (firfreq[2 * i + 0] * firfreq[2 * i + 0] + firfreq[2 * i + 1] * firfreq[2 * i + 1]) * inv_PN;
		if (mag[i] > 0.0)
			ana[2 * i + 0] = logf (mag[i]);
		else
			ana[2 * i + 0] = logf (1.0e-32);
	}
	analytic (size, ana, ana);
	for (i = 0; i < size; i++)
	{
		newfreq[2 * i + 0] = + mag[i] * cosf (ana[2 * i + 1]);
		if (polarity)
			newfreq[2 * i + 1] = + mag[i] * sinf (ana[2 * i + 1]);
		else
			newfreq[2 * i + 1] = - mag[i] * sinf (ana[2 * i + 1]);
	}
	pffft_transform_ordered(prev, newfreq, impulse, work, PFFFT_BACKWARD);
	if (polarity)
		memcpy (mpfir, &impulse[2 * (pfactor - 1) * N], N * sizeof (complex));
	else
		memcpy (mpfir, impulse, N * sizeof (complex));
	// print_impulse("min_imp.txt", N, mpfir, 1, 0);
	pffft_destroy_setup (prev);
	pffft_destroy_setup (pfor);
	pffft_aligned_free (newfreq);
	pffft_aligned_free (impulse);
	pffft_aligned_free (ana);
	pffft_aligned_free (mag);
	pffft_aligned_free (firfreq);
	pffft_aligned_free (firpad);
	pffft_aligned_free (work);
	// store in cache
	add_impulse_to_cache(MP_CACHE, h, N, mpfir);
}

// impulse response of a zero frequency filter comprising a cascade of two resonators, 
//    each followed by a detrending filter
float* zff_impulse(int nc, float scale)
{
	// nc = number of coefficients (power of two)
	int n_resdet = nc / 2 - 1;			// size of single zero-frequency resonator with detrender
	int n_dresdet = 2 * n_resdet - 1;	// size of two cascaded units; when we convolve these we get 2 * n - 1 length
	// allocate the single and make the values
	float* resdet = (float*) pffft_aligned_malloc (n_resdet * sizeof(float));
	for (int i = 1, j = 0, k = n_resdet - 1; i < nc / 4; i++, j++, k--)
		resdet[j] = resdet[k] = (float)(i * (i + 1) / 2);
	resdet[nc / 4 - 1] = (float)(nc / 4 * (nc / 4 + 1) / 2);
	// print_impulse ("resdet", n_resdet, resdet, 0, 0);
	// allocate the double and complex versions and make the values
	float* dresdet = (float*) pffft_aligned_malloc (n_dresdet * sizeof(float));
	float div = (float)((nc / 2 + 1) * (nc / 2 + 1));					// calculate divisor
	float* c_dresdet = (float*) pffft_aligned_malloc (nc * sizeof(complex));
	for (int n = 0; n < n_dresdet; n++)	// convolve to make the cascade
	{
		for (int k = 0; k < n_resdet; k++)
			if ((n - k) >= 0 && (n - k) < n_resdet)
				dresdet[n] += resdet[k] * resdet[n - k];
		dresdet[n] /= div;
		c_dresdet[2 * n + 0] = dresdet[n] * scale;
		c_dresdet[2 * n + 1] = 0.0;
	}
	// print_impulse("dresdet", n_dresdet, dresdet, 0, 0);
	// print_impulse("c_dresdet", nc, c_dresdet, 1, 0);
	pffft_aligned_free(dresdet);
	pffft_aligned_free(resdet);
	return c_dresdet;
}
