/*  gen.c

This file is part of a program that implements a Software-Defined Radio.

Copyright (C) 2013, 2025 Warren Pratt, NR0V

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

void calc_tone (GEN a)
{
	a->tone.phs = 0.0;
	a->tone.delta = TWOPI * a->tone.freq / a->rate;
	a->tone.cosdelta = cosf (a->tone.delta);
	a->tone.sindelta = sinf (a->tone.delta);
}

void calc_tt (GEN a)
{
	a->tt.phs1 = 0.0;
	a->tt.phs2 = 0.0;
	a->tt.delta1 = TWOPI * a->tt.f1 / a->rate;
	a->tt.delta2 = TWOPI * a->tt.f2 / a->rate;
	a->tt.cosdelta1 = cosf (a->tt.delta1);
	a->tt.cosdelta2 = cosf (a->tt.delta2);
	a->tt.sindelta1 = sinf (a->tt.delta1);
	a->tt.sindelta2 = sinf (a->tt.delta2);
}

void calc_sweep (GEN a)
{
	a->sweep.phs = 0.0;
	a->sweep.dphs = TWOPI * a->sweep.f1 / a->rate;
	a->sweep.d2phs = TWOPI * a->sweep.sweeprate / (a->rate * a->rate);
	a->sweep.dphsmax = TWOPI * a->sweep.f2 / a->rate;
}

void calc_sawtooth (GEN a)
{
	a->saw.period = 1.0f / a->saw.f;
	a->saw.delta = 1.0f / a->rate;
	a->saw.t = 0.0;
}

void calc_triangle (GEN a)
{
	a->tri.period = 1.0f / a->tri.f;
	a->tri.half = 0.5f * a->tri.period;
	a->tri.delta = 1.0f / a->rate;
	a->tri.t = 0.0;
	a->tri.t1 = 0.0;
}

void calc_pulse (GEN a)
{
	int i;
	float delta, theta;
	a->pulse.pperiod = 1.0f / a->pulse.pf;
	a->pulse.tphs = 0.0;
	a->pulse.tdelta = TWOPI * a->pulse.tf / a->rate;
	a->pulse.tcosdelta = cosf (a->pulse.tdelta);
	a->pulse.tsindelta = sinf (a->pulse.tdelta);
	a->pulse.pntrans = (int)(a->pulse.ptranstime * a->rate);
	a->pulse.pnon = (int)(a->pulse.pdutycycle * a->pulse.pperiod * a->rate);
	a->pulse.pnoff = (int)(a->pulse.pperiod * a->rate) - a->pulse.pnon - 2 * a->pulse.pntrans;
	if (a->pulse.pnoff < 0) a->pulse.pnoff = 0;
	a->pulse.pcount = a->pulse.pnoff;
	a->pulse.state = 0;
	a->pulse.ctrans = (float *) malloc0 ((a->pulse.pntrans + 1) * sizeof (float));
	delta = PI / (float)a->pulse.pntrans;
	theta = 0.0;
	for (i = 0; i <= a->pulse.pntrans; i++)
	{
		a->pulse.ctrans[i] = 0.5f * (1.0f - cosf (theta));
		theta += delta;
	}
}

void calc_ttpulse(GEN a)
{
	int i;
	float delta, theta;
	a->ttpulse.pperiod = 1.0f / a->ttpulse.pf;
	a->ttpulse.tphs1 = 0.0;
	a->ttpulse.tphs2 = 0.0;
	a->ttpulse.tdelta1 = TWOPI * a->ttpulse.tf1 / a->rate;
	a->ttpulse.tdelta2 = TWOPI * a->ttpulse.tf2 / a->rate;
	a->ttpulse.tcosdelta1 = cosf(a->ttpulse.tdelta1);
	a->ttpulse.tcosdelta2 = cosf(a->ttpulse.tdelta2);
	a->ttpulse.tsindelta1 = sinf(a->ttpulse.tdelta1);
	a->ttpulse.tsindelta2 = sinf(a->ttpulse.tdelta2);
	a->ttpulse.pntrans = (int)(a->ttpulse.ptranstime * a->rate);
	a->ttpulse.pnon = (int)(a->ttpulse.pdutycycle * a->ttpulse.pperiod * a->rate);
	a->ttpulse.pnoff = (int)(a->ttpulse.pperiod * a->rate) - a->ttpulse.pnon - 2 * a->ttpulse.pntrans;
	if (a->ttpulse.pnoff < 0) a->ttpulse.pnoff = 0;
	a->ttpulse.pcount = a->ttpulse.pnoff;
	a->ttpulse.state = 0;
	a->ttpulse.ctrans = (float*)malloc0((a->ttpulse.pntrans + 1) * sizeof(float));
	delta = PI / (float)a->ttpulse.pntrans;
	theta = 0.0;
	for (i = 0; i <= a->ttpulse.pntrans; i++)
	{
		a->ttpulse.ctrans[i] = 0.5f * (1.0f - cosf(theta));
		theta += delta;
	}
}

void calc_gen (GEN a)
{
	calc_tone (a);
	calc_tt (a);
	calc_sweep (a);
	calc_sawtooth (a);
	calc_triangle (a);
	calc_pulse (a);
	calc_ttpulse (a);
}

void decalc_gen (GEN a)
{
	_aligned_free (a->ttpulse.ctrans);
	_aligned_free (a->pulse.ctrans);
}

GEN create_gen (int run, int size, float* in, float* out, int rate, int mode)
{
	GEN a = (GEN) malloc0 (sizeof (gen));
	a->run = run;
	a->size = size;
	a->in = in;
	a->out = out;
	a->rate = (float)rate;
	a->mode = mode;
	// tone
	a->tone.mag = 1.0f;
	a->tone.freq = 1000.0f;
	// two-tone
	a->tt.mag1 = 0.5f;
	a->tt.mag2 = 0.5f;
	a->tt.f1 = +  900.0f;
	a->tt.f2 = + 1700.0f;
	// noise
	srand ((unsigned int)time (0));
	a->noise.mag = 1.0f;
	// sweep
	a->sweep.mag = 1.0f;
	a->sweep.f1 = -20000.0f;
	a->sweep.f2 = +20000.0f;
	a->sweep.sweeprate = +4000.0f;
	// sawtooth
	a->saw.mag = 1.0f;
	a->saw.f = 500.0f;
	// triangle
	a->tri.mag = 1.0f;
	a->tri.f = 500.0f;
	// pulse
	a->pulse.mag = 1.0f;
	a->pulse.pf = 2.0f;
	a->pulse.pdutycycle = 0.25f;
	a->pulse.ptranstime = 0.005f;
	a->pulse.tf = 600.0f;
	a->pulse.IQout = 0;
	// two-tone pulse
	a->ttpulse.mag1 = 0.5f;
	a->ttpulse.mag2 = 0.5f;
	a->ttpulse.pf = 2.0f;
	a->ttpulse.pdutycycle = 0.25f;
	a->ttpulse.ptranstime = 0.005f;
	a->ttpulse.tf1 = 900.0f;
	a->ttpulse.tf2 = 1700.0f;
	a->ttpulse.IQout = 0;
	calc_gen (a);
	return a;
}

void destroy_gen (GEN a)
{
	decalc_gen (a);
	_aligned_free (a);
}

void flush_gen (GEN a)
{
	a->pulse.state = 0;
	a->ttpulse.state = 0;
}

enum pstate 
{
	OFF,
	UP,
	ON,
	DOWN
};

void xgen (GEN a)
{
	if (a->run)
	{
		switch (a->mode)
		{
		case 0:	// tone
			{
				int i;
				float t1, t2;
				float cosphase = cosf (a->tone.phs);
				float sinphase = sinf (a->tone.phs);
				for (i = 0; i < a->size; i++)
				{
					a->out[2 * i + 0] = + a->tone.mag * cosphase;
					a->out[2 * i + 1] = - a->tone.mag * sinphase;
					t1 = cosphase;
					t2 = sinphase;
					cosphase = t1 * a->tone.cosdelta - t2 * a->tone.sindelta;
					sinphase = t1 * a->tone.sindelta + t2 * a->tone.cosdelta;
					a->tone.phs += a->tone.delta;
					if (a->tone.phs >= TWOPI) a->tone.phs -= TWOPI;
					if (a->tone.phs <   0.0 ) a->tone.phs += TWOPI;
				}
				break;
			}
		case 1:	// two-tone
			{
				int i;
				float tcos, tsin;
				float cosphs1 = cosf (a->tt.phs1);
				float sinphs1 = sinf (a->tt.phs1);
				float cosphs2 = cosf (a->tt.phs2);
				float sinphs2 = sinf (a->tt.phs2);
				for (i = 0; i < a->size; i++)
				{
					a->out[2 * i + 0] = + a->tt.mag1 * cosphs1 + a->tt.mag2 * cosphs2;
					a->out[2 * i + 1] = - a->tt.mag1 * sinphs1 - a->tt.mag2 * sinphs2;
					tcos = cosphs1;
					tsin = sinphs1;
					cosphs1 = tcos * a->tt.cosdelta1 - tsin * a->tt.sindelta1;
					sinphs1 = tcos * a->tt.sindelta1 + tsin * a->tt.cosdelta1;
					a->tt.phs1 += a->tt.delta1;
					if (a->tt.phs1 >= TWOPI) a->tt.phs1 -= TWOPI;
					if (a->tt.phs1 <   0.0 ) a->tt.phs1 += TWOPI;
					tcos = cosphs2;
					tsin = sinphs2;
					cosphs2 = tcos * a->tt.cosdelta2 - tsin * a->tt.sindelta2;
					sinphs2 = tcos * a->tt.sindelta2 + tsin * a->tt.cosdelta2;
					a->tt.phs2 += a->tt.delta2;
					if (a->tt.phs2 >= TWOPI) a->tt.phs2 -= TWOPI;
					if (a->tt.phs2 <   0.0 ) a->tt.phs2 += TWOPI;
				}
				break;
			}
		case 2: // noise
			{
				int i;
				float r1, r2, c, rad;
				for (i = 0; i < a->size; i++)
				{
					do
					{
						r1 = 2.0f * (float)rand() / (float)RAND_MAX - 1.0f;
						r2 = 2.0f * (float)rand() / (float)RAND_MAX - 1.0f;
						c = r1 * r1 + r2 * r2;
					} while (c >= 1.0f);
					rad = sqrtf (-2.0f * logf (c) / c);
					a->out[2 * i + 0] = a->noise.mag * rad * r1;
					a->out[2 * i + 1] = a->noise.mag * rad * r2;
				}
				break;
			}
		case 3:  // sweep
			{
				int i;
				for (i = 0; i < a->size; i++)
				{
					a->out[2 * i + 0] = + a->sweep.mag * cosf(a->sweep.phs);
					a->out[2 * i + 1] = - a->sweep.mag * sinf(a->sweep.phs);
					a->sweep.phs += a->sweep.dphs;
					a->sweep.dphs += a->sweep.d2phs;
					if (a->sweep.phs >= TWOPI) a->sweep.phs -= TWOPI;
					if (a->sweep.phs <   0.0 ) a->sweep.phs += TWOPI;
					if (a->sweep.dphs > a->sweep.dphsmax)
						a->sweep.dphs = TWOPI * a->sweep.f1 / a->rate;
				}
				break;
			}
		case 4:  // sawtooth (audio only)
			{
				int i;
				for (i = 0; i < a->size; i++)
				{
					if (a->saw.t > a->saw.period) a->saw.t -= a->saw.period;
					a->out[2 * i + 0] = a->saw.mag * (a->saw.t * a->saw.f - 1.0f);
					a->out[2 * i + 1] = 0.0;
					a->saw.t += a->saw.delta;
				}
			}
			break;
		case 5:  // triangle (audio only)
			{
				int i;
				for (i = 0; i < a->size; i++)
				{
					if (a->tri.t > a->tri.period) a->tri.t1 = a->tri.t -= a->tri.period;
					if (a->tri.t > a->tri.half)	a->tri.t1 -= a->tri.delta;
					else						a->tri.t1 += a->tri.delta;
					a->out[2 * i + 0] = a->tri.mag * (4.0f * a->tri.t1 * a->tri.f - 1.0f);
					a->out[2 * i + 1] = 0.0;
					a->tri.t += a->tri.delta;
				}
			}
			break;
		case 6:  // pulse (audio or IQ output)
			{
				int i;
				float t1, t2;
				float cosphase = cosf (a->pulse.tphs);
				float sinphase = sinf (a->pulse.tphs);
				for (i = 0; i < a->size; i++)
				{
					if (a->pulse.pnoff != 0)
					{
						switch (a->pulse.state)
						{
						case OFF:
							a->out[2 * i + 0] = 0.0;
							a->out[2 * i + 1] = 0.0;
							if (--a->pulse.pcount == 0)
							{
								a->pulse.state = UP;
								a->pulse.pcount = a->pulse.pntrans;
							}
							break;
						case UP:

							if (a->pulse.IQout)
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase * a->pulse.ctrans[a->pulse.pntrans - a->pulse.pcount];
								a->out[2 * i + 1] = -a->pulse.mag * sinphase * a->pulse.ctrans[a->pulse.pntrans - a->pulse.pcount];
							}
							else
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase * a->pulse.ctrans[a->pulse.pntrans - a->pulse.pcount];
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->pulse.pcount == 0)
							{
								a->pulse.state = ON;
								a->pulse.pcount = a->pulse.pnon;
							}
							break;
						case ON:

							if (a->pulse.IQout)
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase;
								a->out[2 * i + 1] = -a->pulse.mag * sinphase;
							}
							else
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase;
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->pulse.pcount == 0)
							{
								a->pulse.state = DOWN;
								a->pulse.pcount = a->pulse.pntrans;
							}
							break;
						case DOWN:
							if (a->pulse.IQout)
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase * a->pulse.ctrans[a->pulse.pcount];
								a->out[2 * i + 1] = -a->pulse.mag * sinphase * a->pulse.ctrans[a->pulse.pcount];
							}
							else
							{
								a->out[2 * i + 0] = +a->pulse.mag * cosphase * a->pulse.ctrans[a->pulse.pcount];
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->pulse.pcount == 0)
							{
								a->pulse.state = OFF;
								a->pulse.pcount = a->pulse.pnoff;
							}
							break;
						}
					}
					else
					{
						a->out[2 * i + 0] = 0.0;
						a->out[2 * i + 1] = 0.0;
					}
					t1 = cosphase;
					t2 = sinphase;
					cosphase = t1 * a->pulse.tcosdelta - t2 * a->pulse.tsindelta;
					sinphase = t1 * a->pulse.tsindelta + t2 * a->pulse.tcosdelta;
					a->pulse.tphs += a->pulse.tdelta;
					if (a->pulse.tphs >= TWOPI) a->pulse.tphs -= TWOPI;
					if (a->pulse.tphs <   0.0 ) a->pulse.tphs += TWOPI;
				}
			}
			break;
		case 7:		// two-tone pulse (audio or IQ)
			{
				int i;
				float t1a, t1b, t2a, t2b;
				float cosphase1 = cosf(a->ttpulse.tphs1);
				float cosphase2 = cosf(a->ttpulse.tphs2);
				float sinphase1 = sinf(a->ttpulse.tphs1);
				float sinphase2 = sinf(a->ttpulse.tphs2);
				for (i = 0; i < a->size; i++)
				{
					if (a->ttpulse.pnoff != 0)
					{
						switch (a->ttpulse.state)
						{
						case OFF:
							a->out[2 * i + 0] = 0.0;
							a->out[2 * i + 1] = 0.0;
							if (--a->ttpulse.pcount == 0)
							{
								a->ttpulse.state = UP;
								a->ttpulse.pcount = a->ttpulse.pntrans;
							}
							break;
						case UP:
							if (a->ttpulse.IQout)
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2) * a->ttpulse.ctrans[a->ttpulse.pntrans - a->ttpulse.pcount];
								a->out[2 * i + 1] = -(a->ttpulse.mag1 * sinphase1 + a->ttpulse.mag2 * sinphase2) * a->ttpulse.ctrans[a->ttpulse.pntrans - a->ttpulse.pcount];
							}
							else
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2) * a->ttpulse.ctrans[a->ttpulse.pntrans - a->ttpulse.pcount];
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->ttpulse.pcount == 0)
							{
								a->ttpulse.state = ON;
								a->ttpulse.pcount = a->ttpulse.pnon;
							}
							break;
						case ON:
							if (a->ttpulse.IQout)
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2);
								a->out[2 * i + 1] = -(a->ttpulse.mag1 * sinphase1 + a->ttpulse.mag2 * sinphase2);
							}
							else
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2);
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->ttpulse.pcount == 0)
							{
								a->ttpulse.state = DOWN;
								a->ttpulse.pcount = a->ttpulse.pntrans;
							}
							break;
						case DOWN:
							if (a->ttpulse.IQout)
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2) * a->ttpulse.ctrans[a->ttpulse.pcount];
								a->out[2 * i + 1] = -(a->ttpulse.mag1 * sinphase1 + a->ttpulse.mag2 * sinphase2) * a->ttpulse.ctrans[a->ttpulse.pcount];
							}
							else
							{
								a->out[2 * i + 0] = +(a->ttpulse.mag1 * cosphase1 + a->ttpulse.mag2 * cosphase2) * a->ttpulse.ctrans[a->ttpulse.pcount];
								a->out[2 * i + 1] = 0.0;
							}
							if (--a->ttpulse.pcount == 0)
							{
								a->ttpulse.state = OFF;
								a->ttpulse.pcount = a->ttpulse.pnoff;
							}
							break;
						}
					}
					else
					{
						a->out[2 * i + 0] = 0.0;
						a->out[2 * i + 1] = 0.0;
					}
					t1a = cosphase1;
					t1b = sinphase1;
					cosphase1 = t1a * a->ttpulse.tcosdelta1 - t1b * a->ttpulse.tsindelta1;
					sinphase1 = t1a * a->ttpulse.tsindelta1 + t1b * a->ttpulse.tcosdelta1;
					a->ttpulse.tphs1 += a->ttpulse.tdelta1;
					if (a->ttpulse.tphs1 >= TWOPI) a->ttpulse.tphs1 -= TWOPI;
					if (a->ttpulse.tphs1 <  0.0)   a->ttpulse.tphs1 += TWOPI;
					t2a = cosphase2;
					t2b = sinphase2;
					cosphase2 = t2a * a->ttpulse.tcosdelta2 - t2b * a->ttpulse.tsindelta2;
					sinphase2 = t2a * a->ttpulse.tsindelta2 + t2b * a->ttpulse.tcosdelta2;
					a->ttpulse.tphs2 += a->ttpulse.tdelta2;
					if (a->ttpulse.tphs2 >= TWOPI) a->ttpulse.tphs2 -= TWOPI;
					if (a->ttpulse.tphs2 <  0.0)   a->ttpulse.tphs2 += TWOPI;
				}
			}
			break;
		default:	// silence
			{
				memset (a->out, 0, a->size * sizeof (complex));
				break;
			}
		}
	}
	else if (a->in != a->out)
		memcpy (a->out, a->in, a->size * sizeof (complex));
}

void setBuffers_gen (GEN a, float* in, float* out)
{
	a->in = in;
	a->out = out;
}

void setSamplerate_gen (GEN a, int rate)
{
	decalc_gen (a);
	a->rate = (float)rate;
	calc_gen (a);
}

void setSize_gen (GEN a, int size)
{
	a->size = size;
	flush_gen (a);
}


/********************************************************************************************************
*																										*
*											RXA Properties												*
*																										*
********************************************************************************************************/

// 'PreGen', gen0
#if 0
PORT
void SetRXAPreGenRun (int channel, int run)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->run = run;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenMode (int channel, int mode)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->mode = mode;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenToneMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->tone.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenToneFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->tone.freq = freq;
	calc_tone (rxa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenNoiseMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->noise.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenSweepMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->sweep.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenSweepFreq (int channel, float freq1, float freq2)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->sweep.f1 = freq1;
	rxa[channel].gen0.p->sweep.f2 = freq2;
	calc_sweep (rxa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetRXAPreGenSweepRate (int channel, float rate)
{
	EnterCriticalSection (&ch[channel].csDSP);
	rxa[channel].gen0.p->sweep.sweeprate = rate;
	calc_sweep (rxa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

#endif
/********************************************************************************************************
*																										*
*											TXA Properties												*
*																										*
********************************************************************************************************/

// 'PreGen', gen0

PORT
void SetTXAPreGenRun (int channel, int run)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->run = run;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenMode (int channel, int mode)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->mode = mode;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenToneMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->tone.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenToneFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->tone.freq = freq;
	calc_tone (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenNoiseMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->noise.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenSweepMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->sweep.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenSweepFreq (int channel, float freq1, float freq2)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->sweep.f1 = freq1;
	txa[channel].gen0.p->sweep.f2 = freq2;
	calc_sweep (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenSweepRate (int channel, float rate)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->sweep.sweeprate = rate;
	calc_sweep (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenSawtoothMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->saw.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenSawtoothFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->saw.f = freq;
	calc_sawtooth (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenTriangleMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->tri.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenTriangleFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->tri.f = freq;
	calc_triangle (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenPulseMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->pulse.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenPulseFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->pulse.pf = freq;
	calc_pulse (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenPulseDutyCycle (int channel, float dc)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->pulse.pdutycycle = dc;
	calc_pulse (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenPulseToneFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->pulse.tf = freq;
	calc_pulse (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPreGenPulseTransition (int channel, float transtime)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen0.p->pulse.ptranstime = transtime;
	calc_pulse (txa[channel].gen0.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

// 'PostGen', gen1

PORT
void SetTXAPostGenRun (int channel, int run)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->run = run;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenMode (int channel, int mode)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->mode = mode;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenToneMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->tone.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenToneFreq (int channel, float freq)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->tone.freq = freq;
	calc_tone (txa[channel].gen1.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTMag (int channel, float mag1, float mag2)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->tt.mag1 = mag1;
	txa[channel].gen1.p->tt.mag2 = mag2;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTFreq (int channel, float freq1, float freq2)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->tt.f1 = freq1;
	txa[channel].gen1.p->tt.f2 = freq2;
	calc_tt (txa[channel].gen1.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenSweepMag (int channel, float mag)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->sweep.mag = mag;
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenSweepFreq (int channel, float freq1, float freq2)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->sweep.f1 = freq1;
	txa[channel].gen1.p->sweep.f2 = freq2;
	calc_sweep (txa[channel].gen1.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenSweepRate (int channel, float rate)
{
	EnterCriticalSection (&ch[channel].csDSP);
	txa[channel].gen1.p->sweep.sweeprate = rate;
	calc_sweep (txa[channel].gen1.p);
	LeaveCriticalSection (&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseMag(int channel, float mag)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.mag = mag;
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseFreq(int channel, float freq)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.pf = freq;
	calc_pulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseDutyCycle(int channel, float dc)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.pdutycycle = dc;
	calc_pulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseToneFreq(int channel, float freq)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.tf = freq;
	calc_pulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseTransition(int channel, float transtime)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.ptranstime = transtime;
	calc_pulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenPulseIQout(int channel, int IQout)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->pulse.IQout = IQout;
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseMag(int channel, float mag1, float mag2)
{
	// defaults are 0.5/0.5
	// total must not exceed 1.0
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->ttpulse.mag1 = mag1;
	txa[channel].gen1.p->ttpulse.mag2 = mag2;
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseFreq(int channel, float freq)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->ttpulse.pf = freq;
	calc_ttpulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseDutyCycle(int channel, float dc)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->ttpulse.pdutycycle = dc;
	calc_ttpulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseToneFreq(int channel, float freq1, float freq2)
{
	GEN a = txa[channel].gen1.p;
	EnterCriticalSection(&ch[channel].csDSP);
	a->ttpulse.tf1 = freq1;
	a->ttpulse.tf2 = freq2;
	calc_ttpulse(a);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseTransition(int channel, float transtime)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->ttpulse.ptranstime = transtime;
	calc_ttpulse(txa[channel].gen1.p);
	LeaveCriticalSection(&ch[channel].csDSP);
}

PORT
void SetTXAPostGenTTPulseIQout(int channel, int IQout)
{
	EnterCriticalSection(&ch[channel].csDSP);
	txa[channel].gen1.p->ttpulse.IQout = IQout;
	LeaveCriticalSection(&ch[channel].csDSP);
}
