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

#include <math.h>
#include <stdint.h>
#include <time.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

#include "pffft.h"

#include "txa_main.h"
#include "fir.h"
#include "firmin.h"
#include "bandpass.h"
#include "impulse_cache.h"
#include "resample.h"
#include "gen.h"
#include "patchpanel.h"
#include "meter.h"
#include "meterlog10.h"
#include "iir.h"
#include "amsq.h"
#include "eq.h"
#include "emph.h"
#include "fcurve.h"
#include "wcpAGC.h"
#include "cfcomp.h"
#include "compress.h"
#include "osctrl.h"
#include "ammod.h"
#include "fmmod.h"
//#include "siphon.h"
#include "slew.h"
#include "calcc.h"
#include "iqc.h"
#include "cfir.h"
#include "delay.h"
#include "lmath.h"

// manage differences among consoles
#define _Thetis

// channel definitions
#define MAX_CHANNELS					32					// maximum number of supported channels
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
#define PORT

#define _aligned_free(x) pffft_aligned_free(x)

#ifdef __cplusplus
extern "C" {
#endif
	void* malloc0(size_t nb_bytes);
	bool InterlockedBitTestAndReset(volatile void *addr,  int bit);
	bool InterlockedBitTestAndSet(volatile void *addr, int bit);
#ifdef __cplusplus
}
#endif

#ifndef __cplusplus
    #define max(a,b) (((a) > (b)) ? (a) : (b))
    #define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#define Sleep(x)
#define EnterCriticalSection(x)
#define LeaveCriticalSection(x)
#define DeleteCriticalSection(x)
#define InitializeCriticalSectionAndSpinCount(x,y)

#define InterlockedAnd(x,y) __atomic_and_fetch(x, y, __ATOMIC_SEQ_CST)
#define _InterlockedAnd(x,y) __atomic_fetch_and(x, y, __ATOMIC_SEQ_CST)
#define InterlockedExchange(x,y) __atomic_exchange_n(x, y, __ATOMIC_SEQ_CST)

