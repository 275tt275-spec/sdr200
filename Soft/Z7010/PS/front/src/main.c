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
#include "vga.h"

#define GUI_THREAD_STACKSIZE 		2048 * 8
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

uint32_t *lcd_framebuffer = (uint32_t *)0x0F000000;
extern struct vga_creg_map					*vga;

/**
 * @brief Заполняет видеобуфер тестовой таблицей (вертикальные цветные полосы и сетка)
 * @param framebuffer_addr Указатель на начало фреймбуфера в DDR (значение из ddr_fbuf_addr)
 */
void vga_fill_test_pattern(uint32_t *framebuffer_addr) {
    if (!framebuffer_addr) return;

    // Массив стандартных RGB888 цветов для полос:
    // Белый, Желтый, Голубой, Зеленый, Пурпурный, Красный, Синий, Черный
    uint32_t test_colors[8] = {
        0xFFFFFF, // Белый
        0xFFFF00, // Желтый
        0x00FFFF, // Голубой
        0x00FF00, // Зеленый
        0xFF00FF, // Пурпурный
        0xFF0000, // Красный
        0x0000FF, // Синий
        0x000000  // Черный
    };

    uint32_t width_per_strip = LCD_WIDTH / 8;

    for (uint32_t y = 0; y < LCD_HEIGHT; y++) {
        for (uint32_t x = 0; x < LCD_WIDTH; x++) {
            uint32_t pixel_color = 0;

            // 1. Рисуем сетку поверх (каждые 40 пикселей) и белую рамку по краям экрана
            if (x == 0 || x == (LCD_WIDTH - 1) || y == 0 || y == (LCD_HEIGHT - 1) ||
                (x % 40 == 0) || (y % 40 == 0)) {

                pixel_color = 0xFFFFFF; // Белая сетка
            }
            // 2. Внутри сетки выводим вертикальные цветные полосы
            else {
                uint32_t strip_index = x / width_per_strip;
                if (strip_index > 7) strip_index = 7;
                pixel_color = test_colors[strip_index];
            }

            // Запись пикселя в память фреймбуфера
            // Формат в памяти обычно XRGB, где старший байт не используется
            framebuffer_addr[y * LCD_WIDTH + x] = pixel_color;
        }
    }

    // Очистка кэша данных (Data Cache), чтобы Zynq принудительно сбросил данные из кэша в DDR3
    // Без этого DMA-контроллер в FPGA может прочитать старые/пустые данные из физической памяти
//    #ifdef XILINX_XILCACHES_H
    Xil_DCacheFlushRange((INTPTR)framebuffer_addr, LCD_WIDTH * LCD_HEIGHT * sizeof(uint32_t));
 //   #endif
}

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

	XGpioPs_WritePin(&Gpio, LCD_EN_GPIO, 1);
	XGpioPs_WritePin(&Gpio, VGA_LR_GPIO, 1);
	XGpioPs_WritePin(&Gpio, VGA_UD_GPIO, 0);
	XGpioPs_WritePin(&Gpio, VGA_MODE_GPIO, 1);
	XGpioPs_WritePin(&Gpio, VGA_DITHB_GPIO, 0);
	XGpioPs_WritePin(&Gpio, VGA_RST_GPIO, 0);
	usleep(5000);
	XGpioPs_WritePin(&Gpio, VGA_RST_GPIO, 1);

//	vga_fill_test_pattern(lcd_framebuffer);
//	set_vga_prams(VGA_1024X600_60HZ);
//	vga->total_pixels = (vga_data->h_px * vga_data->v_ln) | DMA_FRAME_READY;


#if 1

	xTaskCreate( 	gui_thread, 					/* The function that implements the task. */
					( const char * ) "GUI Scheduler", 		/* Text name for the task, provided to assist debugging only. */
					GUI_THREAD_STACKSIZE, 	/* The stack allocated to the task. */
					NULL, 						/* The task parameter is not used, so set to NULL. */
					GUI_PRIORITY,			/* The task runs at the idle priority. */
					NULL );


	/* Start the tasks and timer running. */
	vTaskStartScheduler();
#endif
	/* If all is well, the scheduler will now be running, and the following line
	will never be reached.  If the following line does execute, then there was
	insufficient FreeRTOS heap memory available for the idle and/or timer tasks
	to be created.  See the memory management section on the FreeRTOS web site
	for more details. */
	for( ;; );
}

