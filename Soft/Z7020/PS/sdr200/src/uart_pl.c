/*
 * uart_pl.c
 *
 *  Created on: 20 дек. 2025 г.
 *      Author: VictorT
 */

#include "xparameters.h"
#include "xuartlite.h"
#include "xil_exception.h"
#include <stdio.h>
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "queue.h"
#include "semphr.h"
#include "uart_pl.h"

#ifndef SDT
#ifdef XPAR_INTC_0_DEVICE_ID
#include "xintc.h"
#else
#include "xscugic.h"
#endif
#else
#include "xinterrupt_wrap.h"
#endif

#ifndef SDT
#define UARTLITE0_DEVICE_ID	  XPAR_UARTLITE_0_DEVICE_ID
#define UARTLITE1_DEVICE_ID	  XPAR_UARTLITE_1_DEVICE_ID

#ifdef XPAR_INTC_0_DEVICE_ID
#define INTC_DEVICE_ID		XPAR_INTC_0_DEVICE_ID
#define UARTLITE0_IRPT_INTR	  XPAR_INTC_0_UARTLITE_0_VEC_ID
#define UARTLITE1_IRPT_INTR	  XPAR_INTC_0_UARTLITE_1_VEC_ID
#else
#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define UARTLITE_IRPT_INTR	  XPAR_FABRIC_UARTLITE_0_VEC_ID
#endif /* XPAR_INTC_0_DEVICE_ID */
#else
#define XUARTLITE_BASEADDRESS	XPAR_XUARTLITE_0_BASEADDR
#endif

#ifndef SDT
#ifdef XPAR_INTC_0_DEVICE_ID
#define INTC		XIntc
#define INTC_HANDLER	XIntc_InterruptHandler
#else
#define INTC		XScuGic
#define INTC_HANDLER	XScuGic_InterruptHandler
#endif /* XPAR_INTC_0_DEVICE_ID */
#endif

#ifndef SDT
int UartLiteIntrExample(INTC *IntcInstancePtr,
			XUartLite *UartLiteInstancePtr,
			u16 UartLiteDeviceId,
			u16 UartLiteIntrId);
#else
int UartLiteIntrExample(XUartLite *UartLiteInstancePtr,
			UINTPTR BaseAddress);
#endif

#define THREAD_STACKSIZE        1024
#define DEFAULT_THREAD_PRIO 	2
#define MEMBER_SIZE(type, member) sizeof(((type *)0)->member)
static QueueHandle_t xQueueUart;
static xTaskHandle xCreatedTask;
static sUartLite uart[2];

static INTC IntcInstance;	/* The instance of the Interrupt Controller */

static void uartPL_thread(void *p);
static void Uart0LiteSendHandler(void *CallBackRef, unsigned int EventData);
static void Uart0LiteRecvHandler(void *CallBackRef, unsigned int EventData);
static void Uart1LiteSendHandler(void *CallBackRef, unsigned int EventData);
static void Uart1LiteRecvHandler(void *CallBackRef, unsigned int EventData);

int uartPL_init(void)
{
	int Status;
	XUartLite *UartLiteInstPtr = &uart[0].UartLiteInst;
	u16 UartLiteDeviceId = UARTLITE0_DEVICE_ID;
	INTC *IntcInstancePtr = &IntcInstance;
	u16 UartLiteIntrId = UARTLITE0_IRPT_INTR;

	xQueueUart = xQueueCreate(UARTPL_QUEUE_SIZE, sizeof(sUartMsg));
	uart[0].xSemaphore = xSemaphoreCreateMutex();
	uart[1].xSemaphore = xSemaphoreCreateMutex();

#ifdef SDT
	XUartLite_Config *CfgPtr;
#endif

#ifndef SDT
	Status = XUartLite_Initialize(UartLiteInstPtr, UartLiteDeviceId);
#else
	CfgPtr = XUartLite_LookupConfig(BaseAddress);
	Status = XUartLite_Initialize(UartLiteInstPtr, BaseAddress);
#endif
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XUartLite_SelfTest(UartLiteInstPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

#ifndef SDT
	Status = XIntc_Initialize(IntcInstancePtr, INTC_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XIntc_Connect(IntcInstancePtr, UartLiteIntrId,
			       (XInterruptHandler)XUartLite_InterruptHandler,
			       (void *)UartLiteInstPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XIntc_Start(IntcInstancePtr, XIN_REAL_MODE);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	XIntc_Enable(IntcInstancePtr, UartLiteIntrId);

#else
	XScuGic_SetPriorityTriggerType(IntcInstancePtr, UartLiteIntrId, 0xA0, 0x3);
	Status = XScuGic_Connect(IntcInstancePtr, UartLiteIntrId,
				 (Xil_ExceptionHandler) XUartLite_InterruptHandler,
				 UartLiteInstancePtr);
	if (Status != XST_SUCCESS) {
		return Status;
	}
	XScuGic_Enable(IntcInstancePtr, UartLiteIntrId);
#endif

	XUartLite_SetSendHandler(UartLiteInstPtr, Uart0LiteSendHandler, UartLiteInstPtr);
	XUartLite_SetRecvHandler(UartLiteInstPtr, Uart0LiteRecvHandler, UartLiteInstPtr);

	XUartLite_EnableInterrupt(UartLiteInstPtr);


	UartLiteInstPtr = &uart[1].UartLiteInst;
	UartLiteDeviceId = UARTLITE1_DEVICE_ID;
	UartLiteIntrId = UARTLITE1_IRPT_INTR;

#ifndef SDT
	Status = XUartLite_Initialize(UartLiteInstPtr, UartLiteDeviceId);
#else
	CfgPtr = XUartLite_LookupConfig(BaseAddress);
	Status = XUartLite_Initialize(UartLiteInstPtr, BaseAddress);
#endif
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XUartLite_SelfTest(UartLiteInstPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

#ifndef SDT
	Status = XIntc_Initialize(IntcInstancePtr, INTC_DEVICE_ID);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XIntc_Connect(IntcInstancePtr, UartLiteIntrId,
			       (XInterruptHandler)XUartLite_InterruptHandler,
			       (void *)UartLiteInstPtr);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	Status = XIntc_Start(IntcInstancePtr, XIN_REAL_MODE);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	XIntc_Enable(IntcInstancePtr, UartLiteIntrId);

#else
	XScuGic_SetPriorityTriggerType(IntcInstancePtr, UartLiteIntrId, 0xA0, 0x3);
	Status = XScuGic_Connect(IntcInstancePtr, UartLiteIntrId,
				 (Xil_ExceptionHandler) XUartLite_InterruptHandler,
				 UartLiteInstancePtr);
	if (Status != XST_SUCCESS) {
		return Status;
	}
	XScuGic_Enable(IntcInstancePtr, UartLiteIntrId);
#endif

	XUartLite_SetSendHandler(UartLiteInstPtr, Uart1LiteSendHandler, UartLiteInstPtr);
	XUartLite_SetRecvHandler(UartLiteInstPtr, Uart1LiteRecvHandler,	UartLiteInstPtr);

	XUartLite_EnableInterrupt(UartLiteInstPtr);

	uart[0].msg.uart = 0;
	uart[1].msg.uart = 1;

	xTaskCreate( (void(*)(void*))uartPL_thread, "uartPL thread", THREAD_STACKSIZE, NULL, DEFAULT_THREAD_PRIO, &xCreatedTask );

	return XST_SUCCESS;
}

void uartPL_sendDisplay(uint8_t* data, uint32_t bytes)
{
	sUartLite*pUart = &uart[0];
	xSemaphoreTake(pUart->xSemaphore, ( TickType_t ) 100 );
	XUartLite_Send(&pUart->UartLiteInst, data, bytes);
	xSemaphoreGive(pUart->xSemaphore );
}

void uartPL_sendInternal(uint8_t* data, uint32_t bytes)
{
	sUartLite*pUart = &uart[1];
	xSemaphoreTake(pUart->xSemaphore, ( TickType_t ) 100 );
	XUartLite_Send(&pUart->UartLiteInst, data, bytes);
	vTaskDelay(pdMS_TO_TICKS( 10 ));
	xSemaphoreGive(pUart->xSemaphore );
}

static void uartPL_thread(void *p)
{
	uint32_t msg;

	XUartLite_Recv(&uart[0].UartLiteInst, (uint8_t*)uart[0].rcv_buffer, 1);
	XUartLite_Recv(&uart[1].UartLiteInst, (uint8_t*)uart[1].rcv_buffer, 1);

	while(1) {
		if(xQueueReceive(xQueueUart, &msg, portMAX_DELAY) == pdPASS )
		{

		}
	}

	vTaskDelete(NULL);
}

static void Uart0LiteRecvHandler(void *CallBackRef, unsigned int EventData)
{
	sUartLite* p = &uart[0];
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	uint32_t n = 0;
	p->msg.payload = (uint8_t*)&p->rcv_data[p->m_in_msg][0];

	while(EventData > 0)
	{
		while(n < EventData)
		{
			p->msg.payload[p->m_in_ptr] = p->rcv_buffer[n++];
			if(p->msg.payload[p->m_in_ptr] == ';')
			{
				xQueueSendFromISR( xQueueUart, &p->msg, &xHigherPriorityTaskWoken);
				p->m_in_ptr = 0;
				if(++p->m_in_msg >= UARTPL_QUEUE_SIZE)
				{
					p->m_in_msg = 0;
				}
				p->msg.payload = (uint8_t*)&p->rcv_data[p->m_in_msg][0];
			}
			else
			{
				if(++p->m_in_ptr >= UARTPL_PACKET_SIZE)
					p->m_in_ptr = 0;
			}
		}

		XUartLite_Recv(&p->UartLiteInst, (uint8_t*)p->rcv_buffer, sizeof(p->rcv_buffer));
	}
}

static void Uart0LiteSendHandler(void *CallBackRef, unsigned int EventData)
{

}

static void Uart1LiteRecvHandler(void *CallBackRef, unsigned int EventData)
{
	sUartLite* p = &uart[1];
	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	uint32_t n = 0;
	p->msg.payload = (uint8_t*)&p->rcv_data[p->m_in_msg][0];

	while(EventData > 0)
	{
		while(n < EventData)
		{
			p->msg.payload[p->m_in_ptr] = p->rcv_buffer[n++];
			if(p->msg.payload[p->m_in_ptr] == ';')
			{
				xQueueSendFromISR( xQueueUart, &p->msg, &xHigherPriorityTaskWoken);
				p->m_in_ptr = 0;
				if(++p->m_in_msg >= UARTPL_QUEUE_SIZE)
				{
					p->m_in_msg = 0;
				}
				p->msg.payload = (uint8_t*)&p->rcv_data[p->m_in_msg][0];
			}
			else
			{
				if(++p->m_in_ptr >= UARTPL_PACKET_SIZE)
					p->m_in_ptr = 0;
			}
		}

		XUartLite_Recv(&p->UartLiteInst, (uint8_t*)p->rcv_buffer, sizeof(p->rcv_buffer));
	}
}

static void Uart1LiteSendHandler(void *CallBackRef, unsigned int EventData)
{

}


