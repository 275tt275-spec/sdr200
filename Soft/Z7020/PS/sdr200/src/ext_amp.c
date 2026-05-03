/*
 * ext_amp.c
 *
 *  Created on: 22 мар. 2026 г.
 *      Author: user
 */

#include <string.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <stdbool.h>

#include "xparameters.h"
#include "xplatform_info.h"
#include "xuartps.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "semphr.h"
#include "queue.h"
#include "xscugic.h"

#include "ext_amp.h"

#define UART_DEVICE_ID			XPAR_XUARTPS_0_DEVICE_ID
#define UART_INT_IRQ_ID			XPAR_XUARTPS_0_INTR
#define THREAD_STACKSIZE        1024
#define DEFAULT_THREAD_PRIO 	2
#define UART_QUEUE_SIZE			32
#define UART_PACKET_SIZE		256
#define EXT_AMP_FREQ_STEP		500000

extern XScuGic IntcInstance;
static SemaphoreHandle_t xUartSem = NULL;
static XUartPs UartPs;
static void UartHandler(void *CallBackRef, u32 Event, unsigned int EventData);
static QueueHandle_t xQueueUart;
static char m_out[1024];
static char rcv_buffer[1024];
static char rcv_data[UART_QUEUE_SIZE][UART_PACKET_SIZE];
static volatile int m_in_ptr = 0;
static volatile int m_in_msg = 0;
static uint32_t m_freq = 0;

void extAmpInit(void)
{
	int Status;
	u32 IntrMask;

	xQueueUart = xQueueCreate( UART_QUEUE_SIZE, sizeof(uint32_t) );
	xUartSem = xSemaphoreCreateMutex();

	XUartPs_Config *Config = XUartPs_LookupConfig(UART_DEVICE_ID);
	if (NULL == Config) {
		return;
	}

	Status = XUartPs_CfgInitialize(&UartPs, Config, Config->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/* Check hardware build */
	Status = XUartPs_SelfTest(&UartPs);
	if (Status != XST_SUCCESS) {
		return;
	}

	XUartPs_SetHandler(&UartPs, (XUartPs_Handler)UartHandler, &UartPs);
	Status = XScuGic_Connect(&IntcInstance, UART_INT_IRQ_ID,
				 (Xil_ExceptionHandler) XUartPs_InterruptHandler,
				 (void *) &UartPs);
	if (Status != XST_SUCCESS) {
		return;
	}

	/* Enable the interrupt for the device */
	XScuGic_Enable(&IntcInstance, UART_INT_IRQ_ID);
	IntrMask =
			XUARTPS_IXR_TOUT | XUARTPS_IXR_PARITY | XUARTPS_IXR_FRAMING |
			XUARTPS_IXR_OVER | XUARTPS_IXR_TXEMPTY | XUARTPS_IXR_RXFULL |
			XUARTPS_IXR_RXOVR;

	if (UartPs.Platform == XPLAT_ZYNQ_ULTRA_MP) {
		IntrMask |= XUARTPS_IXR_RBRK;
	}
	XUartPs_SetInterruptMask(&UartPs, IntrMask);
	XUartPs_SetOperMode(&UartPs, XUARTPS_OPER_MODE_NORMAL);
	XUartPs_SetBaudRate(&UartPs, 115200);
	XUartPs_SetRecvTimeout(&UartPs, 8);

//	xTaskCreate( (void(*)(void*))uart_thread, "uart thread", THREAD_STACKSIZE, NULL, DEFAULT_THREAD_PRIO, &xCreatedTask );
}

void extAmpSend(uint8_t* data, size_t len)
{
	xSemaphoreTake( xUartSem, ( TickType_t ) 100 );
	XUartPs_Send(&UartPs, data, len);
	xSemaphoreGive( xUartSem );
}

void extAmpSetFreq(uint32_t freq)
{
	int freqDelta = (int)freq - (int)m_freq;
	if(abs(freqDelta) >= EXT_AMP_FREQ_STEP)
	{
		m_freq = freq;
		sprintf(m_out, "FA%011d;", (int)freq);
		extAmpSend((uint8_t*)m_out, strlen(m_out));
	}
}

static void UartHandler(void *CallBackRef, u32 Event, unsigned int EventData)
{
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	uint32_t n = 0;
	uint8_t* msg = (uint8_t*)&rcv_data[m_in_msg][0];

	/* All of the data has been sent */
	if (Event == XUARTPS_EVENT_SENT_DATA) {
	}

	/* All of the data has been received */
	if (Event == XUARTPS_EVENT_RECV_DATA) {
		while(EventData > 0)
		{
			while(n < EventData)
			{
				msg[m_in_ptr] = rcv_buffer[n++];
				if(msg[m_in_ptr] == ';')
				{
					xQueueSendFromISR( xQueueUart, &msg, &xHigherPriorityTaskWoken);
					m_in_ptr = 0;
					if(++m_in_msg >= UART_QUEUE_SIZE)
					{
						m_in_msg = 0;
					}
					msg = (uint8_t*)&rcv_data[m_in_msg][0];
				}
				else
				{
					if(++m_in_ptr >= UART_PACKET_SIZE)
						m_in_ptr = 0;
				}
			}

			EventData = XUartPs_Recv(&UartPs, (uint8_t*)rcv_buffer, sizeof(rcv_buffer));
		}
	}

	/*
	 * Data was received, but not the expected number of bytes, a
	 * timeout just indicates the data stopped for 8 character times
	 */
	if (Event == XUARTPS_EVENT_RECV_TOUT) {
		while(EventData > 0)
		{
			while(n < EventData)
			{
				msg[m_in_ptr] = rcv_buffer[n++];
				if(msg[m_in_ptr] == ';')
				{
					xQueueSendFromISR( xQueueUart, &msg, &xHigherPriorityTaskWoken);
					m_in_ptr = 0;
					if(++m_in_msg >= UART_QUEUE_SIZE)
					{
						m_in_msg = 0;
					}
					msg = (uint8_t*)&rcv_data[m_in_msg][0];
				}
				else
				{
					if(++m_in_ptr >= UART_PACKET_SIZE)
						m_in_ptr = 0;
				}
			}

			EventData = XUartPs_Recv(&UartPs, (uint8_t*)rcv_buffer, sizeof(rcv_buffer));
		}
	}

	/*
	 * Data was received with an error, keep the data but determine
	 * what kind of errors occurred
	 */
	if (Event == XUARTPS_EVENT_RECV_ERROR) {
	}

	/*
	 * Data was received with an parity or frame or break error, keep the data
	 * but determine what kind of errors occurred. Specific to Zynq Ultrascale+
	 * MP.
	 */
	if (Event == XUARTPS_EVENT_PARE_FRAME_BRKE) {
	}

	/*
	 * Data was received with an overrun error, keep the data but determine
	 * what kind of errors occurred. Specific to Zynq Ultrascale+ MP.
	 */
	if (Event == XUARTPS_EVENT_RECV_ORERR) {

	}
}
