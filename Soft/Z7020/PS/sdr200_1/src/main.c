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

#include <stdio.h>
#include "platform.h"

#include "comm.h"

#define IN_SIZE 32
#define DSP_SIZE 32

int main()
{
    init_platform();

	int channel = 0;
	set_dsp(IN_SIZE, DSP_SIZE, 8000, 16000, 16000);
	create_txa(channel);

    while(1)
    {
    	xtxa(channel);
    }

    cleanup_platform();
    return 0;
}

int _gettimeofday(struct timeval *tv, void *tz) {
    if (tv) {
        tv->tv_sec = 0;
        tv->tv_usec = 0;
    }
    return 0;
}
