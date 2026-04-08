/*
 * hw.h
 *
 *  Created on: 27 окт. 2025 г.
 *      Author: VictorT
 */

#ifndef SRC_HW_H_
#define SRC_HW_H_

#include <stddef.h>

#include "FreeRTOS.h"
#include "event_groups.h"
#include "semphr.h"

#include "xparameters.h"
#include "xspips.h"
#include "xgpiops.h"
#include "xiicps.h"
#include "xscugic.h"
#include "fpga.h"

#define HW_ADC_SAMPLERATE	122880000

#define GPIO_ATT_LE0		22
#define GPIO_ATT_LE1		23
#define GPIO_DAC_RESET		33
#define IIC_DAC_SLAVE_ADDR  0x4C
#define IIC_LM75_SLAVE_ADDR (0x90 >> 1)
#define VREF_CORR_MULT	    322.98
#define VREF_CORR_OFFSET	24881
#define VREF_UPDATE_MS  	10000
#define LINEAR_SET_DELAY	50

typedef enum tag_trx_mode {
	TRX_MODE_USB,
	TRX_MODE_LSB,
	TRX_MODE_DIGITAL,
	TRX_MODE_AM,
	TRX_MODE_CW,
	TRX_MODE_FM,
} e_trx_mode;

typedef enum tag_agc_type {
	AGC_NONE,
	AGC_FAST,
	AGC_MIDDLE,
	AGC_SLOW,
} e_agc_type;

typedef enum tag_tx_input {
	TX_INPUT,
	TX_TUNE,
} e_tx_input;

typedef struct tag_hw_device {
	XScuGic* IntcInstance;
	XSpiPs SpiInstance;
	XGpioPs GpioInstance;
	XIicPs IicInstance;
	SemaphoreHandle_t xSPISemaphore;
	EventGroupHandle_t xSPIEventGroup;
	SemaphoreHandle_t xIICSemaphore;
	EventGroupHandle_t xIICEventGroup;
	SemaphoreHandle_t xUartSemaphore;
	int32_t RXANR_offset;
	int32_t TXA_offset;
	TickType_t xMaxBlockTime;
	int TxOn;
	char InternalSend[32];
	uint8_t RFBand;
	uint8_t attMB1;
	uint8_t attMB2;
	uint8_t txaCorr;
	int TestMode;
	TaskHandle_t xVrefTask;
	EventGroupHandle_t xVrefEvents;
	int lin;
} s_hw_device;

extern s_hw_device hw_device;

void hw_Init(void);
void hw_Start(void);
void hw_SetRXAFreq(uint32_t hz);
void hw_SetTXAFreq(uint32_t hz);
void hw_SetRXAAtt(float db);
void hw_SetTXAPower(float dBm);
void hw_SetTXAFBAtt(float db);
void hw_SetVREF(int16_t value);
void hw_SetRXAMode(e_trx_mode mode);
void hw_SetTXAMode(e_trx_mode mode);
void hw_SetRFGain(uint8_t value); /* 0 - 100*/
void hw_SetAFGain(uint8_t value); /* 0 - 255*/
void hw_SetAGC(e_agc_type type);
void hw_SetPTT(int on, e_tx_input in);
void hw_SetFBAtt(uint8_t valueV, uint8_t valueC);

void hw_SetAttMB1(uint8_t value);
void hw_SetAttMB2(uint8_t value);

void hw_SetRXACorrect(uint8_t dBm2);
void hw_SetTXACorrect(uint8_t dBm2);
int hw_IsTXOn(void);
float hw_GetRefTemperature(void);
void hw_SetTestMode(int set);
void hw_SetATUBypass(int set);
void hw_SetATU(uint8_t dir, uint8_t maskL, uint8_t maskC);
void hw_GetSWR(s_swr* swr);

void hw_SetLiner(int en);
void hw_SetLinerDDSIn(double freq);
void hw_SetLinerCorrect(uint8_t shift, uint32_t dci, uint32_t dcq, uint32_t gi, uint32_t gq);
void hw_SetLinerCoeff(uint32_t kDiff, uint32_t kStab, uint32_t kProp);

void hw_iic_write(uint16_t SlaveAddr, uint8_t* data, size_t len);
void hw_iic_read(uint16_t SlaveAddr, uint8_t* data, size_t len);


#endif /* SRC_HW_H_ */
