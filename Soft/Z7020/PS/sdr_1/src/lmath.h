/*  lmath.h

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2015, 2023 Warren Pratt, NR0V

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

extern void dR (int n, float* r, float* y, float* z);

extern void trI (
    int n,
    float* r,
    float* B,
	float* y,
	float* v,
	float* dR_z
    );

void asolve(int xsize, int asize, float* x, float* a, float* r, float* z);
void median(int n, float* a, float* med);

#ifndef _bldr_h
#define _bldr_h

typedef struct _bldr
{
	float* catxy;
	float* sx;
	float* sy;
	float* h;
	int* p;
	int* np;
	float* taa;
	float* tab;
	float* tag;
	float* tad;
	float* tbb;
	float* tbg;
	float* tbd;
	float* tgg;
	float* tgd;
	float* tdd;
	float* A;
	float* B;
	float* C;
	float* D;
	float* E;
	float* F;
	float* G;
	float* MAT;
	float* RHS;
	float* SLN;
	float* z;
	float* zp;
	float* wrk;
	int* ipiv;
} bldr, *BLDR;

BLDR create_builder(int points, int ints);
void destroy_builder(BLDR a);
void flush_builder(BLDR a, int points, int ints);
void xbuilder(BLDR a, int points, float* x, float* y, int ints, float* t, int* info, float* c, float ptol);
int fcompare(const void* a, const void* b);
void decomp(int n, float* a, int* piv, int* info, float* wrk);
void dsolve(int n, float* a, int* piv, float* b, float* x);

#endif
