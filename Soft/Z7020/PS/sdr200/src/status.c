/*
 * status.c
 *
 *  Created on: 23 но€б. 2025 г.
 *      Author: user
 */

#include "xil_printf.h"

#include <math.h>

#include "status.h"
#include "KenwoodCmd.h"
#include "hw.h"
#include "fpga.h"

static int64_t sAccum = 0;
static uint32_t value;
static s_swr swr;
static int nSend;

void status_update(void)
{
	if(hw_IsTXOn() == 0)
	{
		value = fpga_RXA_GetRSSI();
		int32_t s = (int32_t)(sAccum >> 3);
		sAccum -= s;
		sAccum += value;
		kenwood_SetSMeter(s);
	}
	else
	{
		hw_GetSWR(&swr);
		if(swr.swr < 1.1f) nSend = 0;
		else if(swr.swr < 1.2f) nSend = 1;
		else if(swr.swr < 1.3f) nSend = 2;
		else if(swr.swr < 1.4f) nSend = 3;
		else if(swr.swr< 1.5f) nSend = 4;
		else if(swr.swr < 1.6f) nSend = 5;
		else if(swr.swr < 1.7f) nSend = 6;
		else if(swr.swr < 1.8f) nSend = 7;
		else if(swr.swr < 1.9f) nSend = 8;
		else if(swr.swr< 2.0f) nSend = 9;
		else nSend = 10;
		kenwood_SetMeter(1, nSend);

//		nSend = (float)swr.inc * 10.0f / 16383; // FIXME:
//		kenwood_SetMeter(0, nSend);
	}
}
