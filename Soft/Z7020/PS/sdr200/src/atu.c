/*
 * swr.cpp
 *
 *  Created on: 13 февр. 2026 г.
 *      Author: VictorT
 */

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#define _USE_MATH_DEFINES
#include <math.h>
#include <complex.h>

#include "atu.h"
#include "hw.h"

#define ATU_SET_DELAY   20
#define ATU_MAX_IND     127
#define ATU_MAX_CAP     127
#define ATU_INDUCTOR_STEP      60
#define ATU_CAPACITOR_STEP     17
#define ATU_CAPACITOR_OFFSET   0
#define ATU_CORR_COEFF	0.0f

#define ATU_CORR_CAPACITOR		30
#define ATU_CORR_INDUCTOR		230

static float m_fswr = 100;
static int m_cap = 0;
static int m_ind = 0;
static int m_SW = 0;
static float m_Freq = 0;
static float complex m_Z = 50.0 + -0.0 * I;
static int m_BestCap = 0;
static int m_BestInd = 0;
static int m_BestSW = 0;
static float m_BestSWR = 100;
static int m_BestBypass = 0;
static int m_Bypass = 1;
static s_swr swr;

enum CapPosition {
	TX_SIDE,
	ANT_SIDE,
	UNMATCHABLE
};

struct StrictATUResult {
	enum CapPosition cap_pos;
	float c_pf;
	float l_nh;
	float estimated_swr;
};

struct StrictATUResult calculate_strict_l_network(float R, float X, float r_0, float freq_hz)
{
	const float PI = 3.14159265f;
	struct StrictATUResult res = { UNMATCHABLE, 0.0f, 0.0f, 999.0f };
	float omega = 2.0f * PI * freq_hz;

	// Защита от нулевого сопротивления
	if (R <= 0.0f) return res;

	// === ТЕСТ ДЛЯ СХЕМЫ ANT_SIDE (Конденсатор параллельно антенне, катушка последовательно к TX) ===
	// Находим проводимость антенны: Y = G + jB
	float denom = R * R + X * X;
	float G_ant = R / denom;
	float B_ant = -X / denom; // знак минус, так как Y = 1/(R+jX) = R/den - jX/den

	// Чтобы схема ANT_SIDE работала, должно выполняться: G_ant < 1.0 / r_0
	if (G_ant < (1.0f / r_0)) {
		// Требуемая полная проводимость параллельной части, чтобы получить активные 50 Ом
		float B_total = sqrtf((1.0f / r_0 - G_ant) * G_ant);

		// Нам нужно получить +B_total (для согласования требуется знак, зависящий от направления)
		// Проверяем оба корня уравнения (+B_total и -B_total)
		float B_c_opt1 = B_total - B_ant;
		float B_c_opt2 = -B_total - B_ant;

		// Конденсатор имеет положительную проводимость (B_c = omega * C > 0)
		float B_c = -1.0f;
		float sign_fixed = 1.0f;

		if (B_c_opt1 > 0.0f) { B_c = B_c_opt1; sign_fixed = 1.0f; }
		else if (B_c_opt2 > 0.0f) { B_c = B_c_opt2; sign_fixed = -1.0f; }

		if (B_c > 0.0f) {
			// Находим реактивное сопротивление последовательной катушки
			float X_l = sign_fixed * sqrtf(r_0 / G_ant - r_0 * r_0);

			// Нам нужна именно катушка (X_l >= 0)
			if (X_l >= 0.0f) {
				res.cap_pos = ANT_SIDE;
				res.c_pf = (B_c / omega) * 1e12f;
				res.l_nh = (X_l / omega) * 1e9f;
				res.estimated_swr = 1.0f;
				return res;
			}
		}
	}

	// === ТЕСТ ДЛЯ СХЕМЫ TX_SIDE (Конденсатор параллельно TX, катушка последовательно к антенне) ===
	// Для этой схемы необходимо, чтобы R < r_0
	if (R < r_0) {
		float sqrt_term = sqrtf((r_0 - R) / R);
		float X_c = r_0 / sqrt_term; // Реактивное сопротивление конденсатора (величина)
		float X_l_total = R * sqrt_term;
		float X_l_needed = X_l_total - X; // Катушка должна компенсировать и реактивность антенны

		if (X_l_needed >= 0.0f) {
			res.cap_pos = TX_SIDE;
			res.c_pf = (1.0f / (omega * X_c)) * 1e12f;
			res.l_nh = (X_l_needed / omega) * 1e9f;
			res.estimated_swr = 1.0f;
			return res;
		}
	}

	return res; // Если ни одна схема строго на L и C_на_землю не подошла
}

static float complex ZhpLsd(float freq, float complex Zin, int L, int C)
{
	float omega = 2.0*M_PI*freq;
	float complex Zc = 1.0/(I*omega*C*1E-12);
	float complex Zl = I*omega*L*1E-9;
	float complex Zout = Zin*Zc / (Zin+Zc) + Zl;
	return Zout;
}

static void atu_SetATU(void)
{
	hw_SetATUBypass(m_Bypass);
	hw_SetATU(m_SW, m_ind, m_cap);
	vTaskDelay(pdMS_TO_TICKS( ATU_SET_DELAY ));
}

static void atu_GetSwr(void)
{
	hw_GetSWR(&swr);
	m_fswr = swr.swr;
	m_Z = swr.R + swr.X * I;
}

static void atu_BestSwr(void)
{
    if(m_BestSWR > m_fswr)
    {
        m_BestSWR = m_fswr;
        m_BestCap = m_cap;
        m_BestInd = m_ind;
        m_BestSW = m_SW;
        m_BestBypass = m_Bypass;
    }
}

static void atu_SetGetValue(void)
{
	atu_SetATU();
	atu_GetSwr();
	atu_BestSwr();
}

static int atu_CoarseInd(void)
{
    float complex Y;
    float complex Zcorr;
    float complex Zl;
    int ind, best_ind = 0;
    float best_Y = 1.0;
    float Y_offset;

    atu_GetSwr();
//    Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
    Zcorr = ZhpLsd(m_Freq, m_Z, ATU_CORR_INDUCTOR, ATU_CORR_CAPACITOR);

    for(ind = 0; ind <= ATU_MAX_IND; ind++)
    {
        Zl = ZhpLsd(m_Freq, Zcorr, ind * ATU_INDUCTOR_STEP, 1);
        Y = 1 / Zl;
//        printf("atu_CoarseInd: ind = %d, Y = %.6f%+.6fi\n", ind, creal(Y), cimag(Y));

        if(cimag(Zl) > 0)
        {
            if(creal(Y) > 0.02)
                Y_offset = creal(Y) - 0.02;
            else
                Y_offset = 0.02 - creal(Y);

            if(creal(Y) < 0.02)
            {
                if(best_Y < Y_offset)
                    ind = best_ind;
                break;
            }

            if(best_Y > Y_offset)
            {
                best_Y = Y_offset;
                best_ind = ind;
            }
        }
    }

    if(ind > ATU_MAX_IND) ind = ATU_MAX_IND;
    return ind;
}

static int atu_CoarseCap(void)
{
//    float complex Y;
    float complex Zcorr;
    float complex Zc;
    int cap, best_cap = 0;
    float best_Z = 1000.0;
    float Z_offset;

    atu_GetSwr();
//    Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
    Zcorr = ZhpLsd(m_Freq, m_Z, ATU_CORR_INDUCTOR, ATU_CORR_CAPACITOR);

    for(cap = 0; cap <= ATU_MAX_CAP; cap++)
    {
        Zc = ZhpLsd(m_Freq, Zcorr, 0, cap * ATU_CAPACITOR_STEP + ATU_CAPACITOR_OFFSET);
//        printf("atu_CoarseCap: cap = %d, Y = %.2f%+.2fi\n", cap, creal(Zc), cimag(Zc));

        if(cimag(Zc) < 0)
        {
            if(creal(Zc) > 50.0)
                Z_offset = creal(Zc) - 50.0;
            else
                Z_offset = 50.0 - creal(Zc);

            if(creal(Zc) < 50.0)
            {
                if(best_Z < Z_offset)
                    cap = best_cap;
                break;
            }

            if(best_Z > Z_offset)
            {
                best_Z = Z_offset;
                best_cap = cap;
            }
        }
    }

    if(cap > ATU_MAX_CAP) cap = ATU_MAX_CAP;
    return cap;
}

static void atu_CoarseTune(void)
{
    float complex Y;
    float complex Zcorr;
    float best_Y = 1.0;
    float best_Z = 1000.0;
    int best_ind = 0;
    int best_cap = 0;
    m_ind = 0;
    m_cap = 0;

    if(m_SW == 0)
    {
        m_ind = atu_CoarseInd();
        if(m_ind > 0) m_ind--;
        for(; m_ind <= ATU_MAX_IND; m_ind++)
        {
        	atu_SetGetValue();
//            Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
            Zcorr = m_Z;
            Y = 1 / Zcorr;
//            printf("Zcorr = %.2f%+.2fi\n", creal(Zcorr), cimag(Zcorr));
//            printf("Y = %.6f%+.6fi\n", creal(Y), cimag(Y));

            if(cimag(Zcorr) > 0)
            {
                float Y_offset;
                if(creal(Y) > 0.02)
                    Y_offset = creal(Y) - 0.02;
                else
                    Y_offset = 0.02 - creal(Y);

                if(creal(Y) < 0.02)
                {
                    if(best_Y < Y_offset)
                    {
                        m_ind = best_ind;
                        m_cap = best_cap;
                    }
                    break;
                }

                if(best_Y > Y_offset)
                {
                    best_Y = Y_offset;
                    best_ind = m_ind;
                    best_cap = m_cap;
                }
            }
        }
        if(m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
        m_SW = 0;  // Вернем

//        Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
        Zcorr = m_Z;
        float complex Zc = (50.0 * Zcorr) / (Zcorr - 50.0);
//        printf("Zc = %.2f%+.2fi\n", creal(Zc), cimag(Zc));
        float fCap = (m_Freq / 1000000) * 2 * M_PI * cimag(Zc);
        fCap = fabs(1000000 / fCap);
//        printf("Capacitor = %.2f\n", fCap);

        m_cap = ((fCap - 140) / ATU_CAPACITOR_STEP) - 1;
        if(m_cap > 63) m_cap = 63;
        else if(m_cap < 0) m_cap = 0;

        for(; m_cap <= ATU_MAX_CAP; m_cap++)
        {
        	atu_SetGetValue();
//            Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
            Zcorr = m_Z;
            if(cimag(Zcorr) < 0)
                break;
        }
        if(m_cap > ATU_MAX_CAP) m_cap = ATU_MAX_CAP;
    }
    else
    {
        m_cap = atu_CoarseCap();
        if(m_cap > 0) m_cap--;
        for(; m_cap <= ATU_MAX_CAP; m_cap++)
        {
        	atu_SetGetValue();
//            Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
            Zcorr = m_Z;
//            printf("Zcorr = %.6f%+.6fi\n", creal(Zcorr), cimag(Zcorr));

            if(cimag(Zcorr) < 0)
            {
                float Z_offset;
                if(creal(Zcorr) > 50.0)
                    Z_offset = creal(Zcorr) - 50.0;
                else
                    Z_offset = 50.0 - creal(Zcorr);

//                printf("Zbest = %.2f %.2f\n", best_Z, Z_offset);

                if(creal(Zcorr) < 50.0)
                {
                    if(best_Z < Z_offset)
                    {
                        m_ind = best_ind;
                        m_cap = best_cap;
                    }
                    break;
                }

                if(best_Z > Z_offset)
                {
                    best_Z = Z_offset;
                    best_ind = m_ind;
                    best_cap = m_cap;
                }
            }
        }
        if(m_cap > ATU_MAX_CAP) m_cap = ATU_MAX_CAP;

//        float complex Zl = (50.0 * Zcorr) / (Zcorr - 50.0);
//        printf("Zl = %.2f%+.2fi\n", creal(Zl), cimag(Zl));
//        Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
        Zcorr = m_Z;
        float fInd = cimag(Zcorr) / ((m_Freq / 1000000) * 2 * M_PI);
        fInd = fabs(1000 * fInd);
//        printf("Inductor = %.6f\n", fInd);

        m_ind = fInd / ATU_INDUCTOR_STEP;
        if(m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
        if(m_ind > 0) m_ind--;

        for(; m_ind <= ATU_MAX_IND; m_ind++)
        {
        	atu_SetGetValue();
//            Zcorr = 50.0 * ((m_Z + I * 50.0 * m_Omega) / (50.0 + I * m_Z * m_Omega));
            Zcorr = m_Z;
            if(cimag(Zcorr) > 0)
                break;
        }
        if(m_ind > ATU_MAX_IND) m_ind = ATU_MAX_IND;
    }

//    if(m_BestSW == 2) m_BestSW = 0;
    m_ind = m_BestInd;
    m_cap = m_BestCap;
    m_SW = m_BestSW;
}

static void atu_SharpTune(void)
{
	int mem_I = m_ind, mem_C = m_cap;
	int startI = -3, startC = -3;
	int stopI = 3, stopC = 3;

	if((m_ind + startI) > 0)
		startI = m_ind + startI;
	else
		startI = 0;

	if ((m_cap + startC) > 0)
		startC = m_cap + startC;
	else
		startC = 0;

	if ((m_ind + stopI) < ATU_MAX_IND)
		stopI = m_ind + stopI;
	else
		stopI = ATU_MAX_IND;

	if ((m_cap + stopI) < ATU_MAX_CAP)
		stopC = m_cap + stopC;
	else
		stopC = ATU_MAX_CAP;

//    printf("atu_SharpTune: ind: %d %d, cap %d %d\n", startI, stopI, startC, stopC);

    for(m_ind = startI; m_ind <= stopI; m_ind++)
    {
        for(m_cap = startC; m_cap <= stopC; m_cap++)
        {
            if((m_ind == mem_I) && (m_cap == mem_C))
                continue;
            atu_SetGetValue();
            atu_BestSwr();
        }
    }

    m_ind = m_BestInd;
    m_cap = m_BestCap;
    m_SW = m_BestSW;

    atu_SetATU();
}

void atu_tune(uint32_t freq)
{
//	float l_corr = ATU_CORR_COEFF;
//	float b = 2.0 * M_PI * (float) freq / 300000000;
//	m_Omega = tanf(b * l_corr);
	m_Freq = freq;

	m_ind = 0;
	m_cap = 0;
	m_SW = 0;
	m_BestSWR = 1000.0f;
	m_Bypass = 1;

	atu_SetATU();
	atu_GetSwr();

	struct StrictATUResult atu = calculate_strict_l_network(creal(m_Z), cimag(m_Z), 50.0, freq);
	if (atu.cap_pos == TX_SIDE)
	{
		m_SW = 0;
		m_cap = (int)(atu.c_pf * 0.0688 + 7.0542);
	}
	else if (atu.cap_pos == ANT_SIDE)
	{
		m_SW = 1;
		m_cap = (int)(atu.c_pf * 0.071 - 1.9637);
	}
	else
		return;

	m_ind = (int)(atu.l_nh * (atu.l_nh * 0.000003 + 0.0078) + 0.4047);

	m_Bypass = 0;
	atu_SetGetValue();
	atu_SharpTune();

	if(m_cap == 0)
	{
//		printf("ATU: cap = 0, check switch\n");
		m_SW = 0;
		atu_SetGetValue();
		m_SW = 1;
		atu_SetGetValue();
//		printf("ATU:BEST values sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_BestSW, m_BestInd, m_BestCap, m_BestSWR);

		m_ind = m_BestInd;
		m_cap = m_BestCap;
		m_SW = m_BestSW;
		m_Bypass = m_BestBypass;
		atu_SetATU();
	}

	atu_GetSwr();
//	printf("ATU: tune sw:%d, ind:%d, cap:%d, swr:%.2f\n", m_SW, m_ind, m_cap, m_swr);
}

inline int atu_GetBypass(void)
{
	return m_Bypass;
}
