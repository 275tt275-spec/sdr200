/*  comm.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2024, 2025 Warren Pratt, NR0V

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
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "meter.h"
#include "resample.h"
#include "amsq.h"
#include "eq.h"
#include "iir.h"
#include "cfcomp.h"
#include "compress.h"
#include "bandpass.h"
#include "osctrl.h"
#include "wcpAGC.h"
#include "ammod.h"
#include "emph.h"
#include "fmmod.h"
#include "siphon.h"
#include "gen.h"
#include "slew.h"
#include "calcc.h"
#include "iqc.h"
#include "cfir.h"
#include "impulse_cache.h"
#include "pffft.h"
#include "meterlog10.h"
#include "fcurve.h"
#include "TXA.h"

// manage differences among consoles
#define _Thetis
#define PORT

// channel definitions
#define MAX_CHANNELS					1					// maximum number of supported channels
#define DSP_MULT						2					// number of dsp_buffsizes that are held in an iobuff pseudo-ring
#define INREAL							float				// data type for channel input buffer
#define OUTREAL							float				// data type for channel output buffer

// display definitions
#define dMAX_DISPLAYS					72					// maximum number of displays = max instances
#define dMAX_STITCH						4					// maximum number of sub-spans to stitch together
#define dMAX_NUM_FFT					1					// maximum number of ffts for an elimination
#define dMAX_PIXELS						16384				// maximum number of pixels that can be requested
#define dMAX_AVERAGE					60					// maximum number of pixel frames that will be window-averaged
#ifdef _Thetis
#define dINREAL							double
#else
#define dINREAL							float
#endif
#define dOUTREAL						float
#define dSAMP_BUFF_MULT					2					// ratio of input sample buffer size to fft size (for overlap)
#define dNUM_PIXEL_BUFFS				3					// number of pixel output buffers
#define dMAX_M							1					// number of variables to calibrate
#define dMAX_N							100					// maximum number of frequencies at which to calibrate
#define dMAX_CAL_SETS					2					// maximum number of calibration data sets
#define dMAX_PIXOUTS					4					// maximum number of det/avg/outputs per display instance

// wisdom definitions
#define MAX_WISDOM_SIZE_DISPLAY			262144
#define MAX_WISDOM_SIZE_FILTER			262144				// was 32769

// math definitions
#define PI								3.1415926535897932f
#define TWOPI							6.2831853071795864f

// miscellaneous
typedef float complex[2];

extern float* fir_bandpass (int N, float f_low, float f_high, float samplerate, int wintype, int rtype, float scale);
extern void mp_imp (int N, float* fir, float* mpfir, int pfactor, int polarity);
extern float* fftcv_mults (int NM, float* c_impulse);

#define malloc0(x)	pffft_aligned_malloc(x)
#define _aligned_free(p) pffft_aligned_free(p)
#define InitializeCriticalSectionAndSpinCount(x)
#define DeleteCriticalSection(x)
#define EnterCriticalSection(x)
#define LeaveCriticalSection(x)

