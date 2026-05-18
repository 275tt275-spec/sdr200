/******************************************************************************
* Copyright (C) 2023 Advanced Micro Devices, Inc. All Rights Reserved.
* SPDX-License-Identifier: MIT
******************************************************************************/
/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include "xparameters.h"
#include "xbram.h"
#include "xil_cache.h"
#include "xllfifo.h"
#include <stdio.h>
#include "platform.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_cache.h"

#include "comm.h"
#include "cmd.h"

#define IN_SIZE 32
#define DSP_SIZE 32

#define OCM_SHARED_SECTION 0xFFFF0000
#define SGI_FROM_CORE0  0  // Core 1 слушает SGI 0 (настроенный контроллером Core 0)
#define INTC_DEVICE_ID XPAR_SCUGIC_SINGLE_DEVICE_ID
#define FIFO_DEV_I2S_ID	 XPAR_AXI_FIFO_1_DEVICE_ID
#define FIFO_DEV_RESAMPLER_ID	 XPAR_AXI_FIFO_2_DEVICE_ID

XScuGic InterruptController; /* Экземпляр GIC */
static XLlFifo fifo_i2s, fifo_resampler;
static int in_ptr = 0;

volatile uint32_t *shared_buffer = (volatile uint32_t *)OCM_SHARED_SECTION;
volatile int data_ready = 0;
uint8_t value_buffer[2048];
static void main_parse_cmd(uint32_t type, uint32_t len, uint8_t* value);

// Обработчик прерывания на Core 1
void Core1_SgiHandler(void *CallbackRef) {
	data_ready = 1;  // Установка флага для основного цикла
}

void Intc_Init(u32 sgi_id, void *Handler) {
  XScuGic_Config *IntcConfig;
  IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);

  // Инициализация контроллера
  XScuGic_CfgInitialize(&InterruptController, IntcConfig,
                        IntcConfig->CpuBaseAddress);

  // Регистрация обработчика прерывания исключений ARM
  Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                               (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                               &InterruptController);
  Xil_ExceptionEnable();

  // Подключение пользовательского обработчика для SGI
  XScuGic_Connect(&InterruptController, sgi_id, (Xil_ExceptionHandler)Handler,
                  (void *)&InterruptController);

  // Разрешение конкретного SGI прерывания
  XScuGic_Enable(&InterruptController, sgi_id);
}

int main()
{
	int Status;
	uint32_t data;
    init_platform();

	struct _create_runs runs;
	runs.rsmpin = 1;				// input resampler
	runs.panel = 0;					// includes MIC gain
	runs.phrot = 0;					// phase rotator
	runs.micmeter = 0;				// MIC meter
	runs.amsq = 0;					// downward expander capture
	runs.eqp = 0;					// pre-EQ
	runs.eqmeter = 0;				// EQ meter
	runs.preemph = 0;				// FM pre-emphasis
	runs.leveler = 0;				// Leveler
	runs.lvlrmeter = 0;				// Leveler Meter
	runs.cfcomp = 0;				// Continuous Frequency Compressor with post-EQ
	runs.cfcmeter = 0;				// CFC+PostEQ Meter
	runs.bp0 = 0;					// primary bandpass filter
	runs.compressor = 0;			// COMP compressor
	runs.osctrl = 0;				// CESSB Overshoot Control
	runs.compmeter = 0;				// COMP meter
	runs.alc = 0;					// ALC
	runs.ammod = 0;					// AM Modulator
	runs.fmmod = 0;					// FM Modulator
	runs.alcmeter = 0;				// ALC Meter
	runs.iqc = 0;					// PureSignal correction
	runs.cfir = 0;					// compensating FIR filter (used Protocol_2 only)
	runs.rsmpout = 1;				// output resampler
	runs.outmeter = 0;				// output meter

    // Инициализация прерывания SGI 0 для Core 1
    Intc_Init(SGI_FROM_CORE0, Core1_SgiHandler);

	XLlFifo_Config *FifoConfig = XLlFfio_LookupConfig(FIFO_DEV_I2S_ID);
	Status = XLlFifo_CfgInitialize(&fifo_i2s, FifoConfig, FifoConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return 0;
	}
	XLlFifo_IntClear(&fifo_i2s, 0xffffffff);

	FifoConfig = XLlFfio_LookupConfig(FIFO_DEV_RESAMPLER_ID);
	Status = XLlFifo_CfgInitialize(&fifo_resampler, FifoConfig, FifoConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return 0;
	}
	XLlFifo_IntClear(&fifo_resampler, 0xffffffff);

	int channel = 0;
	set_dsp(IN_SIZE, DSP_SIZE, 16000, 16000, 16000);
	create_txa(channel, &runs);

    while(1)
    {
    	if (data_ready) {
    	      // Инвалидация кэша перед чтением
    	      Xil_DCacheInvalidateRange((INTPTR)&shared_buffer[1], 3 * sizeof(uint32_t));
    	      uint32_t counter = shared_buffer[1];
    	      uint32_t len = shared_buffer[3];
    	      Xil_DCacheInvalidateRange((INTPTR)&shared_buffer[4], len);
    	      if(len < sizeof(value_buffer))
    	      {
    	    	  memcpy(value_buffer, (void*)&shared_buffer[4], len);
    	    	  main_parse_cmd(shared_buffer[2], len, value_buffer);
    	      }
    	      shared_buffer[0] = counter;
    	      Xil_DCacheFlushRange((INTPTR)shared_buffer, 1);
    	      data_ready = 0;  // Сброс флага
    	}
#if 0
    	uint32_t world = XLlFifo_iRxOccupancy(&fifo_i2s);
    	if(world)
    	{
    		data = XLlFifo_RxGetWord(&fifo_i2s);
    		txa[channel].inbuff[in_ptr * 2] = *(float*)&data;
    		txa[channel].inbuff[in_ptr * 2 + 1] = *(float*)&data;

    		if(++in_ptr >= IN_SIZE)
    		{
    			in_ptr = 0;
    			xtxa(channel);
    			for(int n = 0; n < DSP_SIZE; n++)
    			{
					XLlFifo_TxPutWord(&fifo_resampler, *(uint32_t*)&txa[channel].outbuff[n * 2]);
					XLlFifo_TxPutWord(&fifo_resampler, *(uint32_t*)&txa[channel].outbuff[n * 2 + 1]);
					XLlFifo_iTxSetLen(&fifo_resampler, sizeof(complex));
    			}
    		}
    	}
#endif
    }

    cleanup_platform();
    return 0;
}

static void main_parse_cmd(uint32_t type, uint32_t len, uint8_t* value)
{
	s_wxpAGC* pAGC = (s_wxpAGC*)value;
	s_ps_control* ps_control = (s_ps_control*)value;

	switch(type)
	{
	case SET_TXA_MODE:
		SetTXAMode(0, *(uint32_t*)value);
		break;
	case SET_TXA_BANDPASS:
		SetTXABandpassFreqs (0, *(float*)value, *(float*)&value[sizeof(float)]);
		break;
#if 0 // UNCOMMENT properties when pointers in place in txa[channel]
	case SET_TXA_BPSRUN:
		SetTXABPSRun(0, *(uint32_t*)value);
		break;
	case SET_TXA_BPSFREQS:
		SetTXABPSFreqs(0, *(float*)value, *(float*)&value[sizeof(float)]);
		break;
#endif
	case SET_TXA_AM_CARRIER:
		SetTXAAMCarrierLevel (0, *(float*) value);
		break;
	case SET_TXA_FM_DEVIATION:
		SetTXAFMDeviation (0, *(float*)value);
		break;
	case SET_TXA_FM_CTCSSFREQ:
		SetTXACTCSSFreq (0, *(float*)value);
		break;
	case SET_TXA_FM_CTCSSRUN:
		SetTXACTCSSRun (0, *(uint32_t*)value);
		break;
	case SET_TXA_FM_MP:
		SetTXAFMMP (0, *(uint32_t*)value);
		break;
	case SET_TXA_FM_NC:
		SetTXAFMNC (0, *(uint32_t*)value);
		break;
	case SET_TXA_FM_AFFREQ:
		SetTXAFMAFFreqs (0, *(float*)value, *(float*)&value[sizeof(float)]);
		break;
	case SET_TXA_AMSQ_RUN:
		SetTXAAMSQRun (0, *(uint32_t*)value);
		break;
	case SET_TXA_AMSQ_MUTED_GAIN:
		SetTXAAMSQMutedGain ( 0, *(float*) value);
		break;
	case SET_TXA_AMSAQ_TRESHOLD:
		SetTXAAMSQThreshold (0, *(float*) value);
		break;
	case SET_TXA_ALC:
		SetTXAALCSt (0, pAGC->state);
		SetTXAALCAttack (0, pAGC->attack);
		SetTXAALCDecay (0, pAGC->decay);
		SetTXAALCHang (0, pAGC->hang);
		SetTXAALCMaxGain (0, pAGC->maxgain);
		break;
	case SET_TXA_LEVELER:
		SetTXALevelerSt (0, pAGC->state);
		SetTXALevelerAttack (0, pAGC->attack);
		SetTXALevelerDecay (0, pAGC->decay);
		SetTXALevelerHang (0, pAGC->hang);
		SetTXALevelerTop (0, pAGC->maxgain);
		break;
	case SET_TXA_USLEW_TIME:
		SetTXAuSlewTime (0, *(float*) value);
		break;
	case SET_TXA_PANEL_RUN:
		SetTXAPanelRun (0, *(uint32_t*)value);
		break;
	case SET_TXA_OSCTRL_RUN:
		SetTXAosctrlRun (0, *(uint32_t*)value);
		break;

	case SET_TXA_SET_PS_RUN:
		SetPSRunCal(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_MOX:
		SetPSMox(0, *(uint32_t*)value);
		break;
	case GET_TXA_SET_PS_INFO:
		break;
	case SET_TXA_SET_PS_RESET:
		SetPSReset(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_MANCAL:
		SetPSMancal(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_AUTOMODE:
		SetPSAutomode(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_TURNON:
		SetPSTurnon(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_CONTROL:
		SetPSControl(0, ps_control->reset, ps_control->mancal, ps_control->automode, ps_control->reset);
		break;
	case SET_TXA_SET_PS_LOOPDELAY:
		SetPSLoopDelay(0, *(float*)value);
		break;
	case SET_TXA_SET_PS_MOXDELAY:
		SetPSMoxDelay(0, *(float*)value);
		break;
	case SET_TXA_SET_PS_TXDELAY:
		SetPSTXDelay(0, *(float*)value);
		break;
	case SET_TXA_SET_PS_PSCCF:
		break;
	case SET_TXA_PS_SAVE_CORR:
		break;
	case SET_TXA_PS_RESTORE_CORR:
		break;
	case SET_TXA_SET_PS_HWPEAK:
		SetPSHWPeak(0, *(float*)value);
		break;
	case SET_TXA_GET_PS_HWPEAK:
		break;
	case SET_TXA_GET_PS_MAXTX:
		break;
	case SET_TXA_SET_PS_PTOL:
		SetPSPtol(0, *(float*)value);
		break;
	case SET_TXA_GET_PS_DISP:
		break;
	case SET_TXA_SET_PS_FBRATE:
		SetPSFeedbackRate(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_PINMODE:
		SetPSPinMode(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_MAPMODE:
		SetPSMapMode(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_STABILIZE:
		SetPSStabilize(0, *(uint32_t*)value);
		break;
	case SET_TXA_SET_PS_INTSSPI:
		SetPSIntsAndSpi(0, *(uint32_t*)value, *(uint32_t*)&value[sizeof(uint32_t)]);
		break;

//void GetPSInfo(int channel, int* info);
//void psccF(int channel, int size, float* Itxbuff, float* Qtxbuff, float* Irxbuff, float* Qrxbuff, bool mox, bool solidmox);
//void PSSaveCorr(int channel, string filename);
//void PSRestoreCorr(int channel, string filename);
//void GetPSHWPeak(int channel, double* peak);
//void GetPSMaxTX(int channel, double* maxtx);
//void GetPSDisp(int channel, IntPtr x, IntPtr ym, IntPtr yc, IntPtr ys, IntPtr cm, IntPtr cc, IntPtr cs);
	}
}

int _gettimeofday(struct timeval *tv, void *tz) {
    if (tv) {
        tv->tv_sec = 0;
        tv->tv_usec = 0;
    }
    return 0;
}
