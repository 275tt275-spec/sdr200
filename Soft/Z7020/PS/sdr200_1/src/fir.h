/*  fir.h

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

extern float* fftcv_mults (int NM, float* c_impulse);
extern float* fir_fsamp_odd (int N, float* A, int rtype, float scale, int wintype);
extern float* fir_fsamp (int N, float* A, int rtype, float scale, int wintype);
extern float* fir_bandpass (int N, float f_low, float f_high, float samplerate, int wintype, int rtype, float scale);
extern float* get_fsamp_window(int N, int wintype);
extern float *fir_read (int N, const char *filename, int rtype, float scale);
extern void analytic (int N, float* in, float* out);
extern void mp_imp (int N, float* fir, float* mpfir, int pfactor, int polarity);
extern float* zff_impulse(int nc, float scale);