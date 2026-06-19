/*
    Copyright (C) 2017 Amazon.com, Inc. or its affiliates.  All Rights Reserved.
    Copyright (c) 2012 - 2022 Xilinx, Inc. All Rights Reserved.
	SPDX-License-Identifier: MIT


    http://www.FreeRTOS.org
    http://aws.amazon.com/freertos


    1 tab == 4 spaces!
*/

/* FreeRTOS includes. */
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "timers.h"
/* Xilinx includes. */
#include "xil_printf.h"
#include "xparameters.h"
#include "xscugic.h"		/* Interrupt controller device driver */
#include "xil_exception.h"
#include "xil_cache.h"
#include "xil_mmu.h"

#include "audio.h"
#include "fpga.h"
#include "ethernet.h"
#include "eeprom.h"
#include "hw.h"
#include "KenwoodCmd.h"
#include "uart_pl.h"
#include "ext_amp.h"
#include "cmd.h"
#include "../shared/shared_region.h"

#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID

#define DELAY_10_SECONDS	10000UL
#define DELAY_20_SECONDS	20000UL
#define DELAY_1_SECOND		1000UL
#define DELAY_4_MSECOND		4UL

extern void _boot();  // или адрес main Core 1

/* The Tx and Rx tasks as described at the top of this file. */
static void prvMainTask( void *pvParameters );
/*-----------------------------------------------------------*/

/* The queue used by the Tx and Rx tasks, as described at the top of this
file. */
static TaskHandle_t xMainTask;

XScuGic IntcInstance;
static int SetupIntrSystem(XScuGic *IntcInstancePtr);
void SendToCore1(uint32_t type, uint32_t len, void* value);
void RcvFromCore1Tick(void);
static void main_parse_cmd(uint32_t type, uint32_t len, const uint8_t* value);

volatile s_shared_buffer* Core0toCore1 = (volatile s_shared_buffer*)OCM_SHARED_SECTION;
volatile s_shared_buffer* Core1toCore0 = (volatile s_shared_buffer*)(OCM_SHARED_SECTION + SHARED_BUFFER_SIZE);

int main( void )
{
#if 1
    // 1. Срочно перенастраиваем регион OCM, чтобы он был доступен для записи
    // 0x10C02 - Strongly Ordered (без кэша), Read/Write
    Xil_SetTlbAttributes(0xFFF00000, 0x10C02);
    Xil_Out32(OCM_SHARED_SECTION, 0);
    Xil_Out32(OCM_SHARED_SECTION + 4, 0);

    // 2. Теперь запись не должна вызывать Data Abort
	Xil_Out32(CORE1_START_REG, 	0x10000000);  // Адрес старта Core 1 в DDR (из lscript.ld)
	dmb();                  // Data Memory Barrier
	__asm__("sev");         // Send Event для пробуждения Core 1
#endif
 	SetupIntrSystem(&IntcInstance);

	eeprom_init();

	xil_printf( "SDR200 Start\r\n" );
//	StartCore1();

	/* Create the two tasks.  The Tx task is given a lower priority than the
	Rx task, so the Rx task will leave the Blocked state and pre-empt the Tx
	task as soon as the Tx task places an item in the queue. */
	xTaskCreate( 	prvMainTask, 				/* The function that implements the task. */
					( const char * ) "Main", 	/* Text name for the task, provided to assist debugging only. */
					2048, 						/* The stack allocated to the task. */
					NULL, 						/* The task parameter is not used, so set to NULL. */
					tskIDLE_PRIORITY,			/* The task runs at the idle priority. */
					&xMainTask );

	/* Start the tasks and timer running. */
	vTaskStartScheduler();

	/* If all is well, the scheduler will now be running, and the following line
	will never be reached.  If the following line does execute, then there was
	insufficient FreeRTOS heap memory available for the idle and/or timer tasks
	to be created.  See the memory management section on the FreeRTOS web site
	for more details. */
	for( ;; );
}

/*-----------------------------------------------------------*/
static void prvMainTask( void *pvParameters )
{
	eeprom_read_const();
	eeprom_read_vars();

	uartPL_init();
	fpga_init();
	ethernet_init();
	hw_Init();
	audio_init();

	kenwood_init();
	extAmpInit();
	hw_Start();

	xil_printf( "prvMainTask: while\r\n" );

	for( ;; )
	{
		fpga_tick();
		RcvFromCore1Tick();
		taskYIELD();
	}
}

static int SetupIntrSystem(XScuGic *IntcInstancePtr)
{
	int Status;

	XScuGic_Config *IntcConfig; /* Instance of the interrupt controller */
	Xil_ExceptionInit();

	/*
	 * Initialize the interrupt controller driver so that it is ready to
	 * use.
	 */
	IntcConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
	if (NULL == IntcConfig) {
		return XST_FAILURE;
	}

	Status = XScuGic_CfgInitialize(IntcInstancePtr, IntcConfig,
				       IntcConfig->CpuBaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	/*
	 * Connect the interrupt controller interrupt handler to the hardware
	 * interrupt handling logic in the processor.
	 */
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
				     (Xil_ExceptionHandler)XScuGic_InterruptHandler,
				     IntcInstancePtr);
	/*
	 * Enable interrupts in the Processor.
	 */
	Xil_ExceptionEnable();
	return XST_SUCCESS;
}

void SendToCore1Uint32(uint32_t type, uint32_t value)
{
	SendToCore1(type, sizeof(uint32_t), &value);
}

void SendToCore1(uint32_t type, uint32_t len, void* value)
{
	volatile s_shared_buffer* pBuffer = Core0toCore1;
	static uint32_t counter = 0;
#if 1
	Xil_DCacheInvalidateRange((INTPTR)&pBuffer->rd_cnt, sizeof(uint32_t));
	if(pBuffer->rd_cnt != counter)
	{
		vTaskDelay(pdMS_TO_TICKS( DELAY_4_MSECOND ));
		Xil_DCacheInvalidateRange((INTPTR)&pBuffer->rd_cnt, 4);
		if(pBuffer->rd_cnt != counter)
		{
			return;
		}
	}

	pBuffer->wr_cnt = ++counter;
	pBuffer->type = type;
	pBuffer->lenght = len;
    memcpy((void*)&pBuffer->data, value, len);
    dmb();                  // Data Memory Barrier

    Xil_DCacheFlushRange((INTPTR)&pBuffer->wr_cnt, len + 3 * sizeof(uint32_t));
    XScuGic_SoftwareIntr(&IntcInstance, SGI_TO_CORE1, TARGET_CORE1);
#endif
}

void RcvFromCore1Tick(void)
{
	volatile s_shared_buffer* pBuffer = Core1toCore0;
	static uint32_t rd_cnt_old = -1;

    Xil_DCacheInvalidateRange((INTPTR)&pBuffer->wr_cnt, 3 * sizeof(uint32_t));
    if(rd_cnt_old != pBuffer->wr_cnt)
    {
		Xil_DCacheInvalidateRange((INTPTR)&pBuffer->data, pBuffer->lenght);
		if(pBuffer->lenght < (SHARED_BUFFER_SIZE - 4 * sizeof(uint32_t)))
		{
			main_parse_cmd(pBuffer->type, pBuffer->lenght, (const uint8_t*)&pBuffer->data);
		}
		rd_cnt_old = pBuffer->wr_cnt;
		pBuffer->rd_cnt = rd_cnt_old;
		Xil_DCacheFlushRange((INTPTR)&pBuffer->rd_cnt, sizeof(uint32_t));
    }
}

static void main_parse_cmd(uint32_t type, uint32_t len, const uint8_t* value)
{
}


