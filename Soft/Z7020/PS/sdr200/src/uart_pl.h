/*
 * uart_pl.h
 *
 *  Created on: 21 дек. 2025 г.
 *      Author: user
 */

#ifndef SRC_UART_PL_H_
#define SRC_UART_PL_H_

#include "xuartlite.h"
#include "semphr.h"

#define UARTPL_QUEUE_SIZE			32
#define UARTPL_PACKET_SIZE			256

typedef struct tagUartMsg
{
	uint32_t uart;
	uint8_t* payload;
} sUartMsg;

typedef struct tagUartLite
{
	XUartLite UartLiteInst;
	char rcv_buffer[512];
	char rcv_data[UARTPL_QUEUE_SIZE][UARTPL_PACKET_SIZE];
	volatile int m_in_ptr;
	volatile int m_in_msg;
	sUartMsg msg;
	SemaphoreHandle_t xSemaphore;
} sUartLite;


int uartPL_init(void);
void uartPL_sendDisplay(uint8_t* data, uint32_t bytes);
void uartPL_sendInternal(uint8_t* data, uint32_t bytes);

#endif /* SRC_UART_PL_H_ */
