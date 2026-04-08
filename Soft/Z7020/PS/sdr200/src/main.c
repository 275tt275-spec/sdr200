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

#include "audio.h"
#include "fpga.h"
#include "ethernet.h"
#include "eeprom.h"
#include "hw.h"
#include "KenwoodCmd.h"
#include "uart_pl.h"

#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID

#define DELAY_10_SECONDS	10000UL
#define DELAY_20_SECONDS	20000UL
#define DELAY_1_SECOND		1000UL
#define DELAY_4_MSECOND		4UL

/* The Tx and Rx tasks as described at the top of this file. */
static void prvMainTask( void *pvParameters );
/*-----------------------------------------------------------*/

/* The queue used by the Tx and Rx tasks, as described at the top of this
file. */
static TaskHandle_t xMainTask;

XScuGic IntcInstance;
static int SetupIntrSystem(XScuGic *IntcInstancePtr);

int main( void )
{
 	SetupIntrSystem(&IntcInstance);

	eeprom_init();

	xil_printf( "SDR200 Start\r\n" );

	/* Create the two tasks.  The Tx task is given a lower priority than the
	Rx task, so the Rx task will leave the Blocked state and pre-empt the Tx
	task as soon as the Tx task places an item in the queue. */
	xTaskCreate( 	prvMainTask, 					/* The function that implements the task. */
					( const char * ) "Main", 		/* Text name for the task, provided to assist debugging only. */
					2048, 	/* The stack allocated to the task. */
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
	hw_Start();

	xil_printf( "prvMainTask: while\r\n" );
	for( ;; )
	{
		fpga_tick();
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

