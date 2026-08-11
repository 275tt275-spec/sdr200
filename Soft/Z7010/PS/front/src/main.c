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
#include "xgpiops.h"
#include "xstatus.h"
#include "sleep.h"

#define GUI_THREAD_STACKSIZE 		2048 * 4
#define GUI_PRIORITY				2
#define GPIO_DEVICE_ID				XPAR_XGPIOPS_0_DEVICE_ID

#define GPIO_EMIO_OFFSET			54
#define LCD_EN_GPIO					(GPIO_EMIO_OFFSET + 0)
#define VGA_MODE_GPIO				(GPIO_EMIO_OFFSET + 1)
#define VGA_UD_GPIO					(GPIO_EMIO_OFFSET + 2)
#define VGA_DITHB_GPIO				(GPIO_EMIO_OFFSET + 3)
#define VGA_RST_GPIO				(GPIO_EMIO_OFFSET + 4)
#define VGA_LR_GPIO					(GPIO_EMIO_OFFSET + 5)

extern void gui_thread(void *p);

XGpioPs Gpio;

int main( void )
{
	XGpioPs_Config* ConfigPtr = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
	XGpioPs_CfgInitialize(&Gpio, ConfigPtr, ConfigPtr->BaseAddr);
	XGpioPs_SetDirectionPin(&Gpio, VGA_MODE_GPIO, 1);
	XGpioPs_SetDirectionPin(&Gpio, VGA_UD_GPIO, 1);
	XGpioPs_SetDirectionPin(&Gpio, VGA_DITHB_GPIO, 1);
	XGpioPs_SetDirectionPin(&Gpio, VGA_RST_GPIO, 1);
	XGpioPs_SetDirectionPin(&Gpio, VGA_LR_GPIO, 1);
	XGpioPs_SetDirectionPin(&Gpio, LCD_EN_GPIO, 1);

	XGpioPs_SetOutputEnablePin(&Gpio, VGA_MODE_GPIO, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, VGA_UD_GPIO, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, VGA_DITHB_GPIO, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, VGA_RST_GPIO, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, VGA_LR_GPIO, 1);
	XGpioPs_SetOutputEnablePin(&Gpio, LCD_EN_GPIO, 1);

	XGpioPs_WritePin(&Gpio, LCD_EN_GPIO, 0);
	XGpioPs_WritePin(&Gpio, VGA_LR_GPIO, 1);
	XGpioPs_WritePin(&Gpio, VGA_UD_GPIO, 1);
	XGpioPs_WritePin(&Gpio, VGA_MODE_GPIO, 0);
	XGpioPs_WritePin(&Gpio, VGA_DITHB_GPIO, 0);
	XGpioPs_WritePin(&Gpio, VGA_RST_GPIO, 0);
	usleep(5000);
	XGpioPs_WritePin(&Gpio, VGA_RST_GPIO, 1);
	XGpioPs_WritePin(&Gpio, LCD_EN_GPIO, 1);

	xTaskCreate( 	gui_thread, 					/* The function that implements the task. */
					( const char * ) "GUI Scheduler", 		/* Text name for the task, provided to assist debugging only. */
					GUI_THREAD_STACKSIZE, 	/* The stack allocated to the task. */
					NULL, 						/* The task parameter is not used, so set to NULL. */
					GUI_PRIORITY,			/* The task runs at the idle priority. */
					NULL );


	/* Start the tasks and timer running. */
	vTaskStartScheduler();

	/* If all is well, the scheduler will now be running, and the following line
	will never be reached.  If the following line does execute, then there was
	insufficient FreeRTOS heap memory available for the idle and/or timer tasks
	to be created.  See the memory management section on the FreeRTOS web site
	for more details. */
	for( ;; );
}

