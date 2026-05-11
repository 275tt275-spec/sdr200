/*
 * hw.c
 *
 *  Created on: 27 окт. 2025 г.
 *      Author: VictorT
 */

#include <stdint.h>
#include <sleep.h>
#include <stdio.h>
#include "xparameters.h"
#include "xspips.h"
#include "xgpiops.h"
#include "xiicps.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "event_groups.h"
#include "semphr.h"
#include <math.h>

#include "hw.h"
#include "fpga.h"
#include "audio.h"
#include "fos_filters.h"
#include "eeprom.h"
#include "ad9783.h"
#include "uart_pl.h"
#include "atu.h"
#include "ext_amp.h"

#define SPI_DEVICE_ID		XPAR_XSPIPS_0_DEVICE_ID
#define SPI_INTR_ID			XPAR_XSPIPS_0_INTR
#define GPIO_DEVICE_ID		XPAR_XGPIOPS_0_DEVICE_ID
#define IIC_DEVICE_ID		XPAR_XIICPS_0_DEVICE_ID
#define IIC_INT_VEC_ID		XPAR_XIICPS_0_INTR
#define ATT_TRANSFER_BIT    0x01
#define IIC_TRANSFER_BIT    0x01
#define IIC_SCLK_RATE		100000
#define VREF_BIT		 	0x01

extern XScuGic IntcInstance;
s_hw_device hw_device;
static s_linear linear = {0};
static int isTuneMode = 0;

static void SpiHandler(void *CallBackRef, u32 StatusEvent, unsigned int ByteCount);
static void IICHandler(void *CallBackRef, u32 Event);
static void prvVrefTask( void *pvParameters );

void hw_Init(void)
{
	XSpiPs_Config *SpiConfig;
	int Status;

	hw_device.RXANR_offset = 1475;
	hw_device.TXA_offset = 1475;
	hw_device.xSPISemaphore = xSemaphoreCreateMutex();
	hw_device.xSPIEventGroup = xEventGroupCreate();
	hw_device.xIICSemaphore = xSemaphoreCreateMutex();
	hw_device.xIICEventGroup = xEventGroupCreate();
	hw_device.xUartSemaphore = xSemaphoreCreateMutex();
	hw_device.xMaxBlockTime = pdMS_TO_TICKS( 4000 );
	hw_device.IntcInstance = &IntcInstance;
	hw_device.RFBand = 255;
	hw_device.TXAlpf = 255;
	hw_device.attMB1 = 255;
	hw_device.attMB2 = 255;
	hw_device.txaCorr = 255;
	hw_device.TestMode = 0;
	hw_device.lin = 0;

	linear.adc_shift = 0;
	linear.agc_k = 5;
	linear.phase_k = 5;
	linear.diff = 0;
	linear.prop = 6000;
	linear.stab = 4000;
	linear.dc_i = 0;
	linear.dc_q = 0;
	linear.gain_i = 32767;
	linear.gain_q = 32767;
	linear.phi_sin = 0;
	linear.phi_cos = 32767;

	SpiConfig = XSpiPs_LookupConfig(SPI_DEVICE_ID);
	if (NULL == SpiConfig) {
		return;
	}

	Status = XSpiPs_CfgInitialize(&hw_device.SpiInstance, SpiConfig,
					  SpiConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Perform a self-test to check hardware build
	 */
	Status = XSpiPs_SelfTest(&hw_device.SpiInstance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Setup the handler for the SPI that will be called from the
	 * interrupt context when an SPI status occurs, specify a pointer to
	 * the SPI driver instance as the callback reference so the handler is
	 * able to access the instance data
	 */
	XSpiPs_SetStatusHandler(&hw_device.SpiInstance, &hw_device.SpiInstance,
				(XSpiPs_StatusHandler) SpiHandler);

	/*
	 * Connect the Spi device to the interrupt subsystem such that
	 * interrupts can occur. This function is application specific
	 */
	Status = XScuGic_Connect(&IntcInstance, SPI_INTR_ID,
				 (Xil_ExceptionHandler)XSpiPs_InterruptHandler,
				 (void *)&hw_device.SpiInstance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Enable the interrupt for the Spi device.
	 */
	XScuGic_Enable(&IntcInstance, SPI_INTR_ID);

	/*
	 * Set the Spi device as a master. External loopback is required.
	 */
	XSpiPs_SetOptions(&hw_device.SpiInstance, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION | XSPIPS_CLK_ACTIVE_LOW_OPTION);
	XSpiPs_SetClkPrescaler(&hw_device.SpiInstance, XSPIPS_CLK_PRESCALE_256);

	XGpioPs_Config *GpioConfigPtr = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
	Status = XGpioPs_CfgInitialize(&hw_device.GpioInstance, GpioConfigPtr, GpioConfigPtr->BaseAddr);
	if (Status != XST_SUCCESS) {
		return;
	}

	XIicPs_Config *IICConfig = XIicPs_LookupConfig(IIC_DEVICE_ID);
	if (NULL == IICConfig) {
		return;
	}

	Status = XIicPs_CfgInitialize(&hw_device.IicInstance, IICConfig, IICConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Perform a self-test to ensure that the hardware was built correctly.
	 */
	Status = XIicPs_SelfTest(&hw_device.IicInstance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Setup the handlers for the IIC that will be called from the
	 * interrupt context when data has been sent and received, specify a
	 * pointer to the IIC driver instance as the callback reference so
	 * the handlers are able to access the instance data.
	 */
	XIicPs_SetStatusHandler(&hw_device.IicInstance, (void *) &hw_device.IicInstance, IICHandler);

	/*
	 * Set the IIC serial clock rate.
	 */
	XIicPs_SetSClk(&hw_device.IicInstance, IIC_SCLK_RATE);

	/*
	 * Connect the device driver handler that will be called when an
	 * interrupt for the device occurs, the handler defined above performs
	 * the specific interrupt processing for the device.
	 */
	Status = XScuGic_Connect(&IntcInstance, IIC_INT_VEC_ID,
				 (Xil_InterruptHandler)XIicPs_MasterInterruptHandler,
				 (void *)&hw_device.IicInstance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Enable the interrupt for the Iic device.
	 */
	XScuGic_Enable(&IntcInstance, IIC_INT_VEC_ID);

	XGpioPs_SetDirectionPin(&hw_device.GpioInstance, GPIO_ATT_LE0, 1);
	XGpioPs_SetOutputEnablePin(&hw_device.GpioInstance, GPIO_ATT_LE0, 1);
	XGpioPs_SetDirectionPin(&hw_device.GpioInstance, GPIO_ATT_LE1, 1);
	XGpioPs_SetOutputEnablePin(&hw_device.GpioInstance, GPIO_ATT_LE1, 1);
	XGpioPs_SetDirectionPin(&hw_device.GpioInstance, GPIO_DAC_RESET, 1);
	XGpioPs_SetOutputEnablePin(&hw_device.GpioInstance, GPIO_DAC_RESET, 1);
	XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE0, 0x0);
	XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE1, 0x0);
	XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_DAC_RESET, 0x0);

	hw_device.xVrefEvents = xEventGroupCreate();
	xTaskCreate( prvVrefTask, 					/* The function that implements the task. */
					( const char * ) "Vref", 		/* Text name for the task, provided to assist debugging only. */
					2048, 	/* The stack allocated to the task. */
					NULL, 						/* The task parameter is not used, so set to NULL. */
					tskIDLE_PRIORITY,			/* The task runs at the idle priority. */
					&hw_device.xVrefTask );
}

void hw_Start(void)
{
	ad9783_InitTXADac();

	hw_SetVREF(e_vars->vRef);
	hw_SetRXAFreq(e_vars->vfoA);
	hw_SetTXAFreq(e_vars->vfoA);
	hw_SetRXAAtt(e_vars->RXAATT);
	hw_SetRXAMode(e_vars->mode);
	hw_SetTXAMode(e_vars->mode);
	hw_SetRFGain(e_vars->RFGain);
	hw_SetAFGain(e_vars->AFGain);
	hw_SetAGC(e_vars->AGCType);

	fpga_LinearInit(&linear);
	fpga_LinearSetShift(&linear);
	fpga_LinearSetIQGain(&linear);
	fpga_LinearSetIQDC(&linear);

	fpga_TXA_ResamplerGain(38698);
}

void hw_iic_write(uint16_t SlaveAddr, uint8_t* data, size_t len)
{
	xSemaphoreTake( hw_device.xIICSemaphore, ( TickType_t ) 100 );
	xEventGroupClearBits(hw_device.xIICEventGroup, IIC_TRANSFER_BIT);
	XIicPs_MasterSend(&hw_device.IicInstance, data, len, SlaveAddr);

	xEventGroupWaitBits(
			hw_device.xIICEventGroup,   /* The event group being tested. */
			IIC_TRANSFER_BIT, /* The bits within the event group to wait for. */
			pdTRUE,        /* BIT_0 & BIT_4 should be cleared before returning. */
			pdFALSE,       /* Don't wait for both bits, either bit will do. */
			hw_device.xMaxBlockTime );
	xSemaphoreGive( hw_device.xIICSemaphore );
}

void hw_iic_read(uint16_t SlaveAddr, uint8_t* data, size_t len)
{
	xSemaphoreTake( hw_device.xIICSemaphore, ( TickType_t ) 100 );
	xEventGroupClearBits(hw_device.xIICEventGroup, IIC_TRANSFER_BIT);
	XIicPs_MasterRecv(&hw_device.IicInstance, data, len, SlaveAddr);

	xEventGroupWaitBits(
			hw_device.xIICEventGroup,   /* The event group being tested. */
			IIC_TRANSFER_BIT, /* The bits within the event group to wait for. */
			pdTRUE,        /* BIT_0 & BIT_4 should be cleared before returning. */
			pdFALSE,       /* Don't wait for both bits, either bit will do. */
			hw_device.xMaxBlockTime );
	xSemaphoreGive( hw_device.xIICSemaphore );
}

static void IICHandler(void *CallBackRef, u32 Event)
{
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	/*
	 * All of the data transfer has been finished.
	 */
	if (0 != (Event & XIICPS_EVENT_COMPLETE_RECV)) {
		xEventGroupSetBitsFromISR(hw_device.xIICEventGroup, IIC_TRANSFER_BIT, &xHigherPriorityTaskWoken);
	} else if (0 != (Event & XIICPS_EVENT_COMPLETE_SEND)) {
		xEventGroupSetBitsFromISR(hw_device.xIICEventGroup, IIC_TRANSFER_BIT, &xHigherPriorityTaskWoken);
	} else if (0 == (Event & XIICPS_EVENT_SLAVE_RDY)) {
		xEventGroupSetBitsFromISR(hw_device.xIICEventGroup, IIC_TRANSFER_BIT, &xHigherPriorityTaskWoken);
	}
}

static void SpiHandler(void *CallBackRef, u32 StatusEvent, unsigned int ByteCount)
{
	/*
	 * Indicate the transfer on the SPI bus is no longer in progress
	 * regardless of the status event
	 */

	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	xEventGroupSetBitsFromISR(hw_device.xSPIEventGroup, ATT_TRANSFER_BIT, &xHigherPriorityTaskWoken );

	/*
	 * If the event was not transfer done, then track it as an error
	 */
	if (StatusEvent != XST_SPI_TRANSFER_DONE) {
	}
}

void hw_SetRXAFreq(uint32_t hz)
{
    uint8_t RFNewBand;
    uint8_t rxaNewCorr;
    uint64_t code64 = (uint64_t)hz * (uint64_t)0x100000000 / (uint64_t)HW_ADC_SAMPLERATE;
    uint32_t dds_data = (uint32_t)code64;
    fpga_RXA_DDSWB(dds_data);

    rxaNewCorr = eeprom_rxa_att(hz);
    hz = (uint32_t)((int32_t)hz + hw_device.RXANR_offset);
    code64 = (uint64_t)hz * (uint64_t)0x100000000 / (uint64_t)HW_ADC_SAMPLERATE;
	dds_data = (uint32_t)code64;
    fpga_RXA_DDSNR(dds_data);

    if(!hw_device.TxOn)
    {
		if(hz < 1800000)
			RFNewBand = 0;
		else if(hz < 2500000)
			RFNewBand = 1;
		else if(hz < 4000000)
			RFNewBand = 2;
		else if(hz < 7500000)
			RFNewBand = 3;
		else if(hz < 9500000)
			RFNewBand = 4;
		else if(hz < 14000000)
			RFNewBand = 5;
		else if(hz < 18500000)
			RFNewBand = 6;
		else if(hz < 40000000)
			RFNewBand = 7;
		else
			RFNewBand = 8;

		if(RFNewBand != hw_device.RFBand)
		{
			hw_device.RFBand = RFNewBand;
			xSemaphoreTake( hw_device.xUartSemaphore, ( TickType_t ) 100 );
			sprintf(hw_device.InternalSend, "RB%02d;", hw_device.RFBand);
			uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
			xSemaphoreGive(hw_device.xUartSemaphore );
		}

		if(hw_device.TestMode == 0)
			hw_SetAttMB1(rxaNewCorr);
		else
			hw_SetAttMB1(0);
    }
}

void hw_SetTXAFreq(uint32_t hz)
{
	hz = (uint32_t)((int32_t)hz + hw_device.TXA_offset);
    uint64_t code64 = (uint64_t)hz * (uint64_t)0x100000000 / (uint64_t)HW_ADC_SAMPLERATE;
    uint32_t dds_data = (uint32_t)code64;
    fpga_TXA_DDS(dds_data);

    uint8_t txaNewCorr = eeprom_txa_att(hz);
    uint8_t LPFNew;

    if(txaNewCorr > 4) txaNewCorr -= 4;

	if(txaNewCorr != hw_device.txaCorr)
	{
		hw_SetTXACorrect(txaNewCorr);
	}

	hw_SetLinerDDSIn(hz);

	if(hz < 2200000)
		LPFNew = 6;
	else if(hz < 3900000)
		LPFNew = 5;
	else if(hz < 7400000)
		LPFNew = 4;
	else if(hz < 14500000)
		LPFNew = 3;
	else if(hz < 21700000)
		LPFNew = 2;
	else if(hz < 31000000)
		LPFNew = 1;
	else
		LPFNew = 0;

	if(LPFNew != hw_device.TXAlpf)
	{
		hw_device.TXAlpf = LPFNew;
		xSemaphoreTake( hw_device.xUartSemaphore, ( TickType_t ) 100 );
		sprintf(hw_device.InternalSend, "PB%02d;", hw_device.TXAlpf);
		uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
		xSemaphoreGive(hw_device.xUartSemaphore);
		vTaskDelay(pdMS_TO_TICKS( 10 ));
	}
}

inline void hw_SetExtAmpFreq(uint32_t hz)
{
	extAmpSetFreq(hz);
}

void hw_SetAttMB1(uint8_t value)
{
	if(value != hw_device.attMB1)
	{
		hw_device.attMB1 = value;
		xSemaphoreTake( hw_device.xSPISemaphore, ( TickType_t ) 100 );
		XSpiPs_Transfer(&hw_device.SpiInstance, &hw_device.attMB1, NULL, 1);
		/* Wait to be notified of an interrupt. */
		xEventGroupWaitBits(
				hw_device.xSPIEventGroup,   /* The event group being tested. */
						   ATT_TRANSFER_BIT, /* The bits within the event group to wait for. */
						   pdTRUE,        /* BIT should be cleared before returning. */
						   pdFALSE,       /* Don't wait for both bits, either bit will do. */
						   hw_device.xMaxBlockTime );

		XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE1, 1);
		usleep(1);
		XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE1, 0);
		xSemaphoreGive( hw_device.xSPISemaphore );
	}
}

void hw_SetAttMB2(uint8_t value)
{
	if(value != hw_device.attMB2)
	{
		hw_device.attMB2 = value;
		xSemaphoreTake( hw_device.xSPISemaphore, ( TickType_t ) 100 );
		XSpiPs_Transfer(&hw_device.SpiInstance, &hw_device.attMB2, NULL, 1);
		/* Wait to be notified of an interrupt. */
		xEventGroupWaitBits(
				hw_device.xSPIEventGroup,   /* The event group being tested. */
						   ATT_TRANSFER_BIT, /* The bits within the event group to wait for. */
						   pdTRUE,        /* BIT should be cleared before returning. */
						   pdFALSE,       /* Don't wait for both bits, either bit will do. */
						   hw_device.xMaxBlockTime );

		XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE0, 1);
		usleep(1);
		XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_ATT_LE0, 0);
		xSemaphoreGive( hw_device.xSPISemaphore );
	}
}

void hw_SetFBAtt(uint8_t valueV, uint8_t valueC)
{
	if(valueV > 63) valueV = 63;
	hw_SetAttMB1(valueV);
	if(valueC > 63) valueC = 63;
	hw_SetAttMB2(valueC);
}

void hw_SetVREF(int16_t value)
{
	xEventGroupSetBits(hw_device.xVrefEvents, VREF_BIT);
#if 0
	float temperature = hw_GetRefTemperature();
	float fvalue = temperature * VREF_CORR_MULT + VREF_CORR_OFFSET + value * 29;
	uint16_t vref = (uint16_t)fvalue;
	uint8_t data[3] = {(1 << 4), (uint8_t)(vref >> 8), (uint8_t)vref};

 	hw_iic_write(IIC_DAC_SLAVE_ADDR, data, sizeof(data));
#endif
}

float hw_GetRefTemperature(void)
{
	uint8_t data[2] = {0, 0};
	hw_iic_write(IIC_LM75_SLAVE_ADDR, data, 1);
	hw_iic_read(IIC_LM75_SLAVE_ADDR, data, sizeof(data));

	return (float)(data[0] << 7 | data[1]) / 128.;
}

void hw_SetRXAMode(e_trx_mode mode)
{
	/* 	0 j3e 2400 yes offset 1850 Hz
		1 a3e
		2 a1a
		3 f3e */

	const uint32_t* lp_filter;
	const uint32_t* hp_filter;
	const uint32_t* fos_filter;
	uint32_t fos_correct = 0;  /* fos gain */
	uint32_t fpga_mode = 0;
	uint32_t fpga_lsb = 0;
	uint32_t out_correct = 2;  /* audio hp and lp gain*/
	uint32_t freq_offset;

	switch (mode)
	{
	case TRX_MODE_USB:
		hw_device.RXANR_offset = 1475;
		hw_device.TXA_offset = 1475;
		fpga_lsb = 0;
		fpga_mode = FPGA_MOD_J3E;
		fos_filter = fos_ssb;
		lp_filter = lp_2800;
		hp_filter = hp_200;
		out_correct = 2;
		fos_correct = 7;
		freq_offset = 6041; // 1475 Hz
		break;
	case TRX_MODE_LSB:
		hw_device.RXANR_offset = -1475;
		hw_device.TXA_offset = -1475;
		fpga_mode = FPGA_MOD_J3E;
		fpga_lsb = 1;
		fos_filter = fos_ssb;
		lp_filter = lp_2800;
		hp_filter = hp_200;
		out_correct = 2;
		fos_correct = 7;
		freq_offset = 6041; // 1475 Hz
		break;
	case TRX_MODE_DIGITAL:
		hw_device.RXANR_offset = 2100;
		hw_device.TXA_offset = 2100;
		fpga_mode = FPGA_MOD_J3E;
		fpga_lsb = 0;
		fos_filter = fos_digital;
		lp_filter = lp_4000;
		hp_filter = hp_200;
		out_correct = 2;
		fos_correct = 7;
		freq_offset = 8602; // 2100 Hz
		break;
	case TRX_MODE_AM:
		hw_device.RXANR_offset = 0;
		hw_device.TXA_offset = 0;
		fpga_mode = FPGA_MOD_A3E;
		fos_filter = fos_am;
		lp_filter = lp_5000;
		hp_filter = hp_50;
		out_correct = 3;
		fos_correct = 7;
		break;
	case TRX_MODE_CW:
		hw_device.RXANR_offset = 0;
		hw_device.TXA_offset = 0;
		fpga_mode = FPGA_MOD_A1A;
		fpga_lsb = 0;
		fos_filter = fos_cw;
		lp_filter = lp_1400;
		hp_filter = hp_400;
		out_correct = 0;
		fos_correct = 7;
		freq_offset = 3277; // 800 Hz
		break;
	case TRX_MODE_FM:
		hw_device.RXANR_offset = 0;
		hw_device.TXA_offset = 0;
		fpga_mode = FPGA_MOD_F3E;
		fpga_lsb = 0;
		fos_filter = fos_fm;
		lp_filter = lp_5000;
		hp_filter = hp_50;
		out_correct = 3;
		freq_offset = 0;
		fos_correct = 7;
		break;
	default:
		hw_device.RXANR_offset = 1475;
		hw_device.TXA_offset = 1475;
		fpga_mode = FPGA_MOD_J3E;
		fos_filter = fos_ssb;
		fpga_lsb = 0;
		lp_filter = lp_2800;
		hp_filter = hp_200;
		out_correct = 2;
		fos_correct = 7;
		freq_offset = 6041; // 1475 Hz
	}

	fpga_RXA_MOD(fpga_mode);
	fpga_RXA_OFFSET(freq_offset);
	fpga_RXA_LSB(fpga_lsb);
	fpga_RXA_FOS(fos_filter);
	fpga_RXA_FOSGAIN(fos_correct);
	fpga_RXA_LP(lp_filter);
	fpga_RXA_HP(hp_filter);
	fpga_RXA_AudioCorrect(out_correct);
}

void hw_SetRFGain(uint8_t value)
{
	uint32_t data = value * 100 + 256;
	fpga_RXA_GainRF(data);
}

void hw_SetAFGain(uint8_t value)
{
	audio_dac_volume(value, value);
}

void hw_SetAGC(e_agc_type type)
{
	s_agc agc;

	switch(type) {
	case AGC_FAST:
		agc.on = 1;
		agc.rssi_max = 0x08000000;
		agc.rssi_max_fast = 0x10000000;
		agc.rssi_min = 0x04000000;
		agc.rssi_min_fast = 0x02000000;
		agc.gain_inc = 10;
		agc.gain_inc_fast = 20;
		agc.gain_dec = 100;
		agc.gain_dec_fast = 200;
		break;
	case AGC_MIDDLE:
		agc.on = 1;
		agc.rssi_max = 0x08000000;
		agc.rssi_max_fast = 0x10000000;
		agc.rssi_min = 0x04000000;
		agc.rssi_min_fast = 0x02000000;
		agc.gain_inc = 5;
		agc.gain_inc_fast = 10;
		agc.gain_dec = 50;
		agc.gain_dec_fast = 100;
		break;
	case AGC_SLOW:
		agc.on = 1;
		agc.rssi_max = 0x08000000;
		agc.rssi_max_fast = 0x10000000;
		agc.rssi_min = 0x04000000;
		agc.rssi_min_fast = 0x02000000;
		agc.gain_inc = 1;
		agc.gain_inc_fast = 2;
		agc.gain_dec = 10;
		agc.gain_dec_fast = 20;
		break;
	default:
		agc.on = 0;
	}

	fpga_RXA_AGC(&agc);
}

void hw_SetPTT(int on, e_tx_input in)
{
	if(on == 1)
	{
		fpga_LinearEnable(&linear, 0);
		if(in == TX_TUNE)
		{
			isTuneMode = 1;
			hw_SetTXAMode(TRX_MODE_CW);
		}
		else
		{
			isTuneMode = 0;
			hw_SetTXAMode(e_vars->mode);
		}

		hw_SetTXAPower(e_vars->RFPower);
		hw_SetTXAFreq(e_vars->vfoA);
		uint8_t att_value = eeprom_txafbV_att(e_vars->vfoA);
		att_value += 2 * (53 - e_vars->RFPower);
		if(att_value >= 63 ) att_value = 63;
		hw_SetAttMB1(att_value);
		att_value = eeprom_txafbC_att(e_vars->vfoA);
		att_value += 2 * (53 - e_vars->RFPower);
		if(att_value >= 63 ) att_value = 63;
		hw_SetAttMB2(att_value);
		hw_device.TxOn = 1;
		fpga_TXA_Enable(1);
		if(hw_device.lin == 1)
		{
			vTaskDelay(pdMS_TO_TICKS( LINEAR_SET_DELAY ));
			fpga_LinearEnable(&linear, 1);
		}

#if 0
		if(in == TX_TUNE)
		{
			atu_tune(e_vars->vfoA);
		}
#endif
	}
	else
	{
		fpga_TXA_Enable(0);
		fpga_LinearEnable(&linear, 0);
		hw_device.TxOn = 0;
		hw_SetRXAFreq(e_vars->vfoA);
		hw_SetRXAAtt(e_vars->RXAATT);
	}
}

inline int hw_IsTXOn(void)
{
	return hw_device.TxOn;
}

void hw_SetRXAAtt(float db)
{
	uint8_t att_value = (uint8_t)((db * 2.0) + 0.5);
	if(att_value > 63) att_value = 63;

	if(hw_device.TestMode == 0)
		sprintf(hw_device.InternalSend, "RA%02d;", (uint8_t)((db * 2.0) + 0.5));
	else
		sprintf(hw_device.InternalSend, "RA00;");
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
}

void hw_SetTXAPower(float dBm)
{
	uint8_t value = (uint8_t)((53 - dBm) * 2);
	if(isTuneMode == 1) value = TXA_TUNE_PWR;
	if(value > 63) value = 63;

    sprintf(hw_device.InternalSend, "RT%02d;", value);
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
}

void hw_SetTXACorrect(uint8_t dBm2)
{
	if(dBm2 > 63) dBm2 = 63;
    sprintf(hw_device.InternalSend, "RA%02d;", dBm2);
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
}

void hw_SetTXAMode(e_trx_mode mode)
{
	if(hw_device.TxOn == 0)
	{
		uint32_t fpga_mode = 0;
		uint32_t fpga_lsb = 0;
		const uint32_t* fos_filter;
		uint32_t fos_gain = 5;
		e_audio_input audio;
		uint32_t freq_offset = 0;
		uint32_t audio_gain = 16383;

		switch (mode)
		{
		case TRX_MODE_USB:
			fpga_mode = FPGA_MOD_J3E;
			fpga_lsb = 0;
			fos_gain = 5;
			fos_filter = fos_ssb;
			audio = AUDIO_IN_MIC;
			fpga_LIM_Enable(1);
			freq_offset = 6041; // 1475 Hz
			break;
		case TRX_MODE_LSB:
			fpga_mode = FPGA_MOD_J3E;
			fpga_lsb = 1;
			fos_gain = 5;
			fos_filter = fos_ssb;
			audio = AUDIO_IN_MIC;
			fpga_LIM_Enable(1);
			freq_offset = 6041; // 1475 Hz
			break;
		case TRX_MODE_DIGITAL:
			fpga_mode = FPGA_MOD_J3E;
			fpga_lsb = 0;
			fos_gain = 7;
			fos_filter = fos_digital;
			audio = AUDIO_IN_USB;
			fpga_LIM_Enable(0);
			freq_offset = 8602; // 2100 Hz
//			audio_gain = 131069;
			audio_gain = 71000;
			break;
		case TRX_MODE_AM:
			fpga_mode = FPGA_MOD_A3E;
			fos_gain = 7;
			fos_filter = fos_am;
			audio = AUDIO_IN_MIC;
			fpga_LIM_Enable(1);
			break;
		case TRX_MODE_CW:
			fpga_mode = FPGA_MOD_A1A;
			fpga_lsb = 0;
			fos_gain = 5;
			fos_filter = fos_ssb;
			audio = AUDIO_IN_USB;
			fpga_LIM_Enable(0);
			break;
		default:
			fpga_mode = FPGA_MOD_J3E;
			fpga_lsb = 0;
			fos_gain = 5;
			fos_filter = fos_ssb;
			audio = AUDIO_IN_MIC;
			fpga_LIM_Enable(1);
			freq_offset = 6041; // 1475 Hz
		}

		audio_set_input(audio);
		fpga_TXA_MOD(fpga_mode);
		fpga_TXA_LSB(fpga_lsb);
		fpga_TXA_FOSGAIN(fos_gain);
		fpga_TXA_FOS(fos_filter);
		fpga_TXA_OFFSET(freq_offset);
		fpga_TXA_AUDIOGAIN(audio_gain);
	}
}

void hw_SetTestMode(int set)
{
	hw_device.TestMode = set;
}

void hw_SetATUBypass(int set)
{
    sprintf(hw_device.InternalSend, set == 1 ? "AB1;" : "AB0;");
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
}

void hw_SetATU(uint8_t dir, uint8_t maskL, uint8_t maskC)
{
    sprintf(hw_device.InternalSend, dir == 1 ? "AC1;" : "AC0;");
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
    sprintf(hw_device.InternalSend, "AS%03d%03d;", maskL, maskC);
    uartPL_sendInternal((uint8_t*)hw_device.InternalSend, strlen(hw_device.InternalSend));
}

inline void hw_GetSWR(s_swr* swr)
{
	fpga_GetSWR(swr);
}

inline void hw_SetLiner(int en)
{
	hw_device.lin = en;
	if(hw_device.TxOn)
		fpga_LinearEnable(&linear, en);
}

void hw_SetLinerDDSIn(double freq)
{
    const float mult_k = 1.0;
    float i_corr = mult_k * 2048 / (2 * sinf(M_PI * freq / HW_ADC_SAMPLERATE));
    float q_corr = mult_k * 2048 / (2 * cosf(M_PI * freq / HW_ADC_SAMPLERATE));
    linear.i_corr_gain = (uint32_t)i_corr;
    linear.q_corr_gain = (uint32_t)q_corr;

    fpga_LinearSetIQCorr(&linear);
}

void hw_SetLinerCorrect(uint8_t shift, uint32_t dci, uint32_t dcq, uint32_t gi, uint32_t gq)
{
	linear.adc_shift = shift;
	linear.dc_i = dci;
	linear.dc_q = dcq;
	linear.gain_i = gi;
	linear.gain_q = gq;

	fpga_LinearSetShift(&linear);
	fpga_LinearSetIQGain(&linear);
	fpga_LinearSetIQDC(&linear);
}

void hw_SetLinerCoeff(uint32_t kDiff, uint32_t kStab, uint32_t kProp)
{
	linear.diff = kDiff;
	linear.stab = kStab;
	linear.prop = kProp;
	fpga_LinearSetCoeff(&linear);
}

void hw_StartTune(uint32_t freq)
{
	hw_SetTXAPower(TXA_TUNE_PWR);
	hw_SetPTT(1, TX_TUNE);
	if(hw_IsTXOn())
		atu_tune(freq);
	hw_SetPTT(0, TX_INPUT);
}

static void prvVrefTask( void *pvParameters )
{
	float temperature;
	float fvalue;
	uint16_t vref;
	uint8_t data[3];
	data[0] = (1 << 4);

	while(1)
	{
		xEventGroupWaitBits(hw_device.xVrefEvents, VREF_BIT, pdTRUE, pdFALSE, pdMS_TO_TICKS(VREF_UPDATE_MS));

		temperature = hw_GetRefTemperature();
		fvalue = temperature * VREF_CORR_MULT + VREF_CORR_OFFSET + e_vars->vRef * 29;
		vref = (uint16_t)fvalue;
		data[1] = (uint8_t)(vref >> 8);
		data[2] = (uint8_t)vref;

	 	hw_iic_write(IIC_DAC_SLAVE_ADDR, data, sizeof(data));
	}
}
