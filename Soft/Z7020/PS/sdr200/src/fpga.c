/*
 * fpga.c
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#include "xparameters.h"
#include "xbram.h"
#include "xil_cache.h"
#include "xllfifo.h"
#include <stdio.h>
#include <math.h>

#include "ethernet.h"
#include "fpga.h"
#include "status.h"
#include "hw.h"

static XBram Bram;
static XLlFifo Fifo;
static uint32_t iq_buffer[UDPIO_PACKET_SIZE/sizeof(uint32_t)];

void fpga_init(void)
{
	int Status;
	XBram_Config *XBramConfig = XBram_LookupConfig(BRAM_DEVICE_ID);

	if (XBramConfig == (XBram_Config *) NULL) {
		return;
	}

	Status = XBram_CfgInitialize(&Bram, XBramConfig,
			XBramConfig->CtrlBaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	Status = XBram_SelfTest(&Bram, XBRAM_IR_ALL_MASK);
	if (Status != XST_SUCCESS) {
		return;
	}

	XLlFifo_Config *FifoConfig = XLlFfio_LookupConfig(FIFO_DEV_ID);
	Status = XLlFifo_CfgInitialize(&Fifo, FifoConfig, FifoConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	XLlFifo_IntClear(&Fifo, 0xffffffff);

	fpga_write(FPGA_HW_RESET, 0);
}

void fpga_tick(void)
{
	static int nReadStatus = 0;
	int n;
	uint32_t words = XLlFifo_iRxOccupancy(&Fifo);
	if(words >= (UDPIO_PACKET_SIZE / sizeof(iq_buffer[0])))
	{
		for(n = 0; n < (UDPIO_PACKET_SIZE / sizeof(iq_buffer[0])); n++)
		{
			iq_buffer[n] = XLlFifo_RxGetWord(&Fifo);
		}

		ethernet_SendIQ((uint8_t*)iq_buffer, sizeof(iq_buffer));
	}

	if(++nReadStatus == READ_STATUS_TIMEOUT)
	{
		nReadStatus = 0;
		status_update();
	}
}

inline void fpga_RXA_DDSNR(uint32_t value)
{
	fpga_write(FPGA_RXA_DDS_NR, value);
}

inline void fpga_RXA_DDSWB(uint32_t value)
{
	fpga_write(FPGA_RXA_DDS_WB, value);
}

inline void fpga_RXA_MOD(uint32_t value)
{
	fpga_write(FPGA_RXA_MOD, value);
}

inline void fpga_RXA_LSB(uint32_t value)
{
	fpga_write(FPGA_RXA_LSB, value);
}

inline void fpga_RXA_FOSGAIN(uint32_t value)
{
	fpga_write(FPGA_RXA_FOS_GAIN, value);
}

inline void fpga_RXA_OFFSET(uint32_t value)
{
	fpga_write(FPGA_RXA_OFFSET, value);
}

inline void fpga_RXA_GainRF(uint32_t value)
{
	fpga_write(FPGA_RXA_RF_GAIN, value);
}

void fpga_RXA_AGC(s_agc* agc)
{
	fpga_write(FPGA_RXA_AGC_ON, agc->on);
	fpga_write(FPGA_RXA_AGC_MAX, agc->rssi_max);
	fpga_write(FPGA_RXA_AGC_MAX2, agc->rssi_max_fast);
	fpga_write(FPGA_RXA_AGC_MIN, agc->rssi_min);
	fpga_write(FPGA_RXA_AGC_MIN2, agc->rssi_min_fast);
	fpga_write(FPGA_RXA_AGC_INC, (agc->gain_inc_fast << 16) | agc->gain_inc);
	fpga_write(FPGA_RXA_AGC_DEC, (agc->gain_dec_fast << 16) | agc->gain_dec);
}

void fpga_RXA_FOS(const uint32_t* p)
{
	fpga_write(FPGA_RXA_FOS_COEFF, *p++ | (1 << 31));

	for(int n = 0; n < 63; n++)
		fpga_write(FPGA_RXA_FOS_COEFF, *p++);
}

void fpga_RXA_LP(const uint32_t* p)
{
	fpga_write(FPGA_RXA_AUDIO_LP, *p++ | (1 << 31));

	for(int n = 0; n < 31; n++)
		fpga_write(FPGA_RXA_AUDIO_LP, *p++);
}

void fpga_RXA_HP(const uint32_t* p)
{
	fpga_write(FPGA_RXA_AUDIO_HP, *p++ | (1 << 31));

	for(int n = 0; n < 63; n++)
		fpga_write(FPGA_RXA_AUDIO_HP, *p++);
}

inline void fpga_RXA_AudioCorrect(uint8_t value)
{
	fpga_write(FPGA_RXA_AUDIO_CORR, value);
}

inline uint32_t fpga_RXA_GetRSSI(void)
{
	return fpga_read(FPGA_RXA_GET);
}

void fpga_TXA_Enable(int enable)
{
	uint32_t ctrl_reg;

	if(enable == 1)
	{
		ctrl_reg = FPGA_TXA_CTRL_ON;
		fpga_write(FPGA_TXA_CTRL, ctrl_reg);
		ctrl_reg = FPGA_TXA_CTRL_ON | FPGA_TXA_CTRL_HW;
		fpga_write(FPGA_TXA_CTRL, ctrl_reg);
	}
	else
	{
		ctrl_reg = 0;
		fpga_write(FPGA_TXA_CTRL, ctrl_reg);
	}
}

inline void fpga_TXA_DDS(uint32_t value)
{
	fpga_write(FPGA_TXA_DDS, value);
}

inline void fpga_TXA_OFFSET(uint32_t value)
{
	fpga_write(FPGA_TXA_J3E, value);
}

inline void fpga_TXA_CTRL(uint32_t value)
{
	fpga_write(FPGA_TXA_CTRL, value);
}

inline void fpga_TXA_MOD(uint32_t value)
{
	fpga_write(FPGA_TXA_MOD, value);
}

inline void fpga_TXA_LSB(uint32_t value)
{
	fpga_write(FPGA_TXA_LSB, value);
}

void fpga_TXA_FOS(const uint32_t* p)
{
	fpga_write(FPGA_TXA_FOS_COEFF, *p++ | (1 << 31));

	for(int n = 0; n < 63; n++)
		fpga_write(FPGA_TXA_FOS_COEFF, *p++);
}

inline void fpga_TXA_FOSGAIN(uint32_t value)
{
	fpga_write(FPGA_TXA_FOS_GAIN, value);
}

inline void fpga_TXA_AUDIOGAIN(uint32_t value)
{
	fpga_write(FPGA_TXA_AUDIO_GAIN, value);
}

inline void fpga_TXA_ResamplerGain(uint32_t value)
{
	fpga_write(FPGA_TXA_RESAMPLER_G, value);
}

void fpga_GetSWR(s_swr* swr)
{
	uint32_t value;
	value = fpga_read(FPGA_REG_SWR);
	swr->ref = (uint16_t)(value >> 16);
	swr->inc = (uint16_t)value;
	value = fpga_read(FPGA_REG_MAG);
	swr->magB = (uint16_t)(value >> 16);
	swr->magA = (uint16_t)value;
	value = fpga_read(FPGA_REG_ANGLE);
	swr->angB = (uint16_t)(value >> 16);
	swr->angA = (uint16_t)value;
}

void fpga_LIM_Enable(int enable)
{
	uint32_t ctrl_reg;

	if(enable == 1)
	{
		ctrl_reg = 1;
	}
	else
	{
		ctrl_reg = 0;
	}

	fpga_write(FPGA_LIM_CTRL, ctrl_reg);
}

void fpga_LinearReset(void)
{
    uint32_t lin_ctrl = 0;
    lin_ctrl = FPGA_LINER_CLR;
    fpga_write(FPGA_LIN_CTRL, lin_ctrl);
    lin_ctrl = 0;
    fpga_write(FPGA_LIN_CTRL, lin_ctrl);
}

void fpga_LinearEnable(s_linear* lin, int enable)
{
    uint32_t lin_ctrl = FPGA_LINER_CLR;
    fpga_write(FPGA_LIN_CTRL, lin_ctrl);

    if(enable == 1)
        lin_ctrl = FPGA_LINER_ON | FPGA_LINER_AGC | FPGA_LIN_PHASE_SLOW;
    else
        lin_ctrl = 0;

    fpga_write(FPGA_LIN_CTRL, lin_ctrl);
}

void fpga_LinearInit(s_linear* lin)
{
	fpga_LinearReset();
	fpga_write(FPGA_LIN_AGC_K, lin->agc_k);
	fpga_write(FPGA_LIN_PHASE_K, lin->phase_k);
	fpga_LinearSetShift(lin);
    fpga_LinearSetCoeff(lin);
}

void fpga_LinearSetIQGain(s_linear* lin)
{
	fpga_write(FPGA_LIN_GAINI, lin->gain_i);
	fpga_write(FPGA_LIN_GAINQ, lin->gain_q);
}

void fpga_LinearSetIQCorr(s_linear* lin)
{
	fpga_write(FPGA_LIN_AMPI, lin->i_corr_gain);
	fpga_write(FPGA_LIN_AMPQ, lin->q_corr_gain);
}

void fpga_LinearSetIQDC(s_linear* lin)
{
	fpga_write(FPGA_LIN_DCI, lin->dc_i);
	fpga_write(FPGA_LIN_DCQ, lin->dc_q);
}

void fpga_LinearSetIQPhi(s_linear* lin)
{
	fpga_write(FPGA_LIN_PHI_SIN, lin->phi_sin);
	fpga_write(FPGA_LIN_PHI_COS, lin->phi_cos);
}

inline void fpga_LinearSetShift(s_linear* lin)
{
	fpga_write(FPGA_LIN_ADC_SHIFT, lin->adc_shift);
}

void fpga_LinearSetCoeff(s_linear* lin)
{
    fpga_write(FPGA_LIN_CORR_KPROP, lin->prop);
    fpga_write(FPGA_LIN_CORR_KDIFF, lin->diff);
    fpga_write(FPGA_LIN_CORR_KSTAB, lin->stab);
}

inline void fpga_write(uint16_t addr, uint32_t value)
{
	XBram_WriteReg(XPAR_BRAM_0_BASEADDR, addr << 2, value);
}

inline uint32_t fpga_read(uint16_t addr)
{
	return XBram_ReadReg(XPAR_BRAM_0_BASEADDR, addr << 2);
}

