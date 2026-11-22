/*
 * fft.c
 *
 *  Created on: 18 сент. 2026 г.
 *      Author: user
 */

#include "FreeRTOS.h"
#include "xparameters.h"
#include "xil_exception.h"
#include "xstreamer.h"
#include "xil_cache.h"
#include "xllfifo.h"
#include "xstatus.h"
#include "task.h"

#include "gui_spectrum.h"
#include "fft.h"

#define WORD_SIZE 4			/* Size of words in bytes */

static XLlFifo FifoInstance;
uint32_t fft_buffer_1[NFFT_SAMPLES * 2];
uint32_t fft_buffer_2[NFFT_SAMPLES * 2];
static int nInPtr;
static int nBuff;
static uint32_t* pBuff;
static int update_scr = SCREEN_UPDATE;

void fft_thread(void *p)
{
	int32_t *pUpdate = (int32_t *)fft_buffer_1;
	int Status;
	XLlFifo_Config *Config = XLlFfio_LookupConfig(XPAR_AXI_FIFO_0_DEVICE_ID);

	Status = XLlFifo_CfgInitialize(&FifoInstance, Config, Config->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/* Check for the Reset value */
	Status = XLlFifo_Status(&FifoInstance);
	XLlFifo_IntClear(&FifoInstance, 0xffffffff);
	Status = XLlFifo_Status(&FifoInstance);
	if(Status != 0x0) {
		return;
	}

	nInPtr = 0;
	nBuff = 0;
	pBuff = fft_buffer_1;
#if 0
	while(1)
	{
		if(XLlFifo_iRxOccupancy(&FifoInstance))
		{
			*pBuff++ = XLlFifo_RxGetWord(&FifoInstance);
			if(++nInPtr >= NFFT_SAMPLES)
			{
				nInPtr = 0;
				if(nBuff == 0)
				{
					nBuff = 1;
					pBuff = fft_buffer_2;
					pUpdate = (int32_t *)fft_buffer_1;
				}
				else
				{
					nBuff = 0;
					pBuff = fft_buffer_1;
					pUpdate = (int32_t *)fft_buffer_2;
				}
#if 1
				if(--update_scr == 0)
				{
					update_scr = SCREEN_UPDATE;
					gui_spectrum_load_data((int32_t*)pUpdate);
				}
#endif
			}
		}

		taskYIELD();
	}
#endif

}
