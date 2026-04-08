/*
 * eeprom.c
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#include "xparameters.h"	/* EDK generated parameters */
#include "xspips.h"		/* SPI device driver */
#include "xscugic.h"		/* Interrupt controller device driver */
#include "xil_exception.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "semphr.h"
#include "event_groups.h"
#include "crc16.h"
#include "eeprom.h"
#include "hw.h"
#ifdef SDT
#include "xinterrupt_wrap.h"
#endif

#include "default_const.h"

#ifndef SDT
#define SPI_DEVICE_ID		XPAR_XSPIPS_1_DEVICE_ID
#define INTC_DEVICE_ID		XPAR_SCUGIC_SINGLE_DEVICE_ID
#define SPI_INTR_ID		    XPAR_XSPIPS_1_INTR
#endif

/*
 * The following constants define the commands which may be sent to the EEPROM
 * device.
 */
#define WRITE_STATUS_CMD	1
#define WRITE_CMD			2
#define READ_CMD			3
#define WRITE_DISABLE_CMD	4
#define READ_STATUS_CMD		5
#define WRITE_ENABLE_CMD	6

#define COMMAND_OFFSET		0 /* EEPROM instruction */
#define ADDRESS_OFFSET		1 /* MSB of address to read or write */
#define DATA_OFFSET			4
#define OVERHEAD_SIZE		4

#define TRANSFER_BIT     0x01
#define COMPLETED_BIT    0x02
#define CHANGED_BIT		 0x01

#define DEFAULT_THREAD_PRIO 	2
#define MAIN_THREAD_STACKSIZE   2048

static uint8_t eeprom_const[16384];
static uint8_t eeprom_vars[EEPROM_VARS_LENGHT];
s_eeprom_vars* e_vars = (s_eeprom_vars*)&eeprom_vars[sizeof(uint32_t)];
s_eeprom_const* e_const = (s_eeprom_const*)&eeprom_const[sizeof(uint32_t)];

extern XScuGic IntcInstance;
XSpiPs Spi1Instance;
static uint8_t write_buffer[1024];
static uint8_t read_buffer[1024];
static SemaphoreHandle_t xSemaphore = NULL;
SemaphoreHandle_t xSPI1Sem = NULL;
static SemaphoreHandle_t xChangeSem = NULL;
static const TickType_t xMaxBlockTime = pdMS_TO_TICKS( 4000 );
static xTaskHandle xCreatedTask;
static xTaskHandle xChangedTask;
static QueueHandle_t xQueue = NULL;
static EventGroupHandle_t xCreatedEventGroup;
static EventGroupHandle_t xChangedEvents;
static uint32_t vars_page = 0;

void SpiHandler(void *CallBackRef, u32 StatusEvent, unsigned int ByteCount);
static void eeprom_thread(void *p);
static void eeprom_change_thread(void *p);
static void eeprom_readfn(uint32_t address, size_t bytes, uint8_t* data);
static void eeprom_writefn(uint32_t address, size_t bytes, uint8_t* data);
static void eeprom_set_const(void);
static void eeprom_set_vars(void);

static u16 SpiDeviceId = SPI_DEVICE_ID;

void eeprom_init(void)
{
	XSpiPs_Config *SpiConfig;
	int Status;

	xSemaphore = xSemaphoreCreateMutex();
	xChangeSem = xSemaphoreCreateMutex();
	xSPI1Sem = xSemaphoreCreateMutex();
	xCreatedEventGroup = xEventGroupCreate();
	xChangedEvents = xEventGroupCreate();

#ifndef SDT
	SpiConfig = XSpiPs_LookupConfig(SpiDeviceId);
#else
	SpiConfig = XSpiPs_LookupConfig(BaseAddress);
#endif
	if (NULL == SpiConfig) {
		return;
	}

	Status = XSpiPs_CfgInitialize(&Spi1Instance, SpiConfig,
				      SpiConfig->BaseAddress);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Perform a self-test to check hardware build
	 */
	Status = XSpiPs_SelfTest(&Spi1Instance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Setup the handler for the SPI that will be called from the
	 * interrupt context when an SPI status occurs, specify a pointer to
	 * the SPI driver instance as the callback reference so the handler is
	 * able to access the instance data
	 */
	XSpiPs_SetStatusHandler(&Spi1Instance, &Spi1Instance,
				(XSpiPs_StatusHandler) SpiHandler);


	/*
	 * Set the Spi device as a master. External loopback is required.
	 */
	XSpiPs_SetOptions(&Spi1Instance, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
	XSpiPs_SetClkPrescaler(&Spi1Instance, XSPIPS_CLK_PRESCALE_64);

	/* Create the queue used by the tasks.  The Rx task has a higher priority
	than the Tx task, so will preempt the Tx task and remove values from the
	queue as soon as the Tx task writes to the queue - therefore the queue can
	never have more than one item in it. */
	xQueue = xQueueCreate( 	2,						/* There is only one space in the queue. */
							sizeof( s_eeprom_message ) );	/* Each space in the queue is large enough to hold a uint32_t. */

	/* Check the queue was created. */
	configASSERT( xQueue );

	xTaskCreate( (void(*)(void*))eeprom_thread, "eeprom thread", MAIN_THREAD_STACKSIZE, NULL, DEFAULT_THREAD_PRIO, &xCreatedTask );
	xTaskCreate( (void(*)(void*))eeprom_change_thread, "eeprom change", MAIN_THREAD_STACKSIZE, NULL, tskIDLE_PRIORITY, &xChangedTask );
}

void eeprom_vars_changed(void)
{
	xSemaphoreTake( xChangeSem, ( TickType_t ) 100 );
	xEventGroupSetBits(xChangedEvents, CHANGED_BIT);
	xSemaphoreGive( xChangeSem );
}

void eeprom_write_const(void)
{
	uint16_t crc16 = CalcCrcFast(eeprom_const, sizeof(eeprom_const) - 2);
	eeprom_const[sizeof(eeprom_const) - 2] = (uint8_t)(crc16 & (0x00FF));
	eeprom_const[sizeof(eeprom_const) - 1] = (uint8_t)((crc16 >> 8) & (0x00FF));
	eeprom_write(EEPROM_CONST_OFFSET, sizeof(eeprom_const), eeprom_const);
}

void eeprom_write_vars(void)
{
	*(uint32_t*)eeprom_vars = vars_page;
	uint16_t crc16 = CalcCrcFast(eeprom_vars, sizeof(eeprom_vars) - 2);
	eeprom_vars[sizeof(eeprom_vars) - 2] = (uint8_t)(crc16 & (0x00FF));
	eeprom_vars[sizeof(eeprom_vars) - 1] = (uint8_t)((crc16 >> 8) & (0x00FF));
	eeprom_write((vars_page * EEPROM_VARS_LENGHT) + EEPROM_VARS_OFFSET, sizeof(eeprom_vars), eeprom_vars);
	vars_page++;
}

void eeprom_read_const(void)
{
	eeprom_read(EEPROM_CONST_OFFSET, sizeof(eeprom_const), eeprom_const);
	uint16_t crc16 = CalcCrcFast(eeprom_const, sizeof(eeprom_const) - 2);
	if((eeprom_const[sizeof(eeprom_const) - 2] != (uint8_t)(crc16 & (0x00FF))) ||
			(eeprom_const[sizeof(eeprom_const) - 1] != (uint8_t)((crc16 >> 8) & (0x00FF))))
	{
		eeprom_set_const();
		eeprom_write_const();
	}
}

void eeprom_read_vars(void)
{
	uint16_t crc16;
	uint32_t page = 0, read_page;
	uint32_t last_page = 0;

	for(read_page = 0; read_page < (EEPROM_VARS_SIZE / EEPROM_VARS_LENGHT); read_page ++)
	{
		eeprom_read(EEPROM_VARS_OFFSET + (read_page * EEPROM_VARS_LENGHT), EEPROM_VARS_LENGHT, eeprom_vars);
		crc16 = CalcCrcFast(eeprom_vars, EEPROM_VARS_LENGHT - 2);
		if((eeprom_vars[EEPROM_VARS_LENGHT - 2] == (uint8_t)(crc16 & (0x00FF))) &&
				(eeprom_vars[EEPROM_VARS_LENGHT - 1] == (uint8_t)((crc16 >> 8) & (0x00FF))))
		{
			if(last_page < *(uint32_t*)eeprom_vars)
			{
				last_page = *(uint32_t*)eeprom_vars;
				page = read_page;
			}
		}
	}

	if(last_page == 0)
	{
		vars_page = 1;
		eeprom_set_vars();
		eeprom_write_vars();
	}
	else
	{
		eeprom_read(EEPROM_VARS_OFFSET + (page * EEPROM_VARS_LENGHT), EEPROM_VARS_LENGHT, eeprom_vars);
		vars_page = *(uint32_t*)eeprom_vars;
	}
}

void eeprom_read(uint32_t address, size_t bytes, uint8_t* data)
{
	s_eeprom_message msg;
	msg.type = READ_CMD;
	msg.address = address;
	msg.bytes = bytes;
	msg.data = data;
	xSemaphoreTake( xSemaphore, ( TickType_t ) 100 );
	xEventGroupClearBits(xCreatedEventGroup, COMPLETED_BIT);
	if(xQueueSend(xQueue, &msg, 0UL) != pdPASS)
		return;

	xEventGroupWaitBits(
			xCreatedEventGroup,   /* The event group being tested. */
				   COMPLETED_BIT, /* The bits within the event group to wait for. */
	               pdTRUE,        /* BIT_0 & BIT_4 should be cleared before returning. */
	               pdFALSE,       /* Don't wait for both bits, either bit will do. */
				   xMaxBlockTime );
	xSemaphoreGive( xSemaphore );
}

static void eeprom_readfn(uint32_t address, size_t bytes, uint8_t* data)
{
	size_t byte_count;
	int StatusTransfer;

	XSpiPs_SetSlaveSelect(&Spi1Instance, EEPROM_SPI_SELECT);

	while(bytes)
	{
		write_buffer[COMMAND_OFFSET]     = READ_CMD;
		write_buffer[ADDRESS_OFFSET] = (uint8_t)((address & 0xFF0000) >> 16);
		write_buffer[ADDRESS_OFFSET + 1] = (uint8_t)((address & 0x00FF00) >> 8);
		write_buffer[ADDRESS_OFFSET + 2] = (uint8_t)(address & 0x0000FF);

		if(bytes > (sizeof(write_buffer) - DATA_OFFSET))
		{
			byte_count = (sizeof(write_buffer) - DATA_OFFSET);
		}
		else
		{
			byte_count = bytes;
		}
		StatusTransfer = XSpiPs_Transfer(&Spi1Instance, write_buffer, read_buffer, byte_count + OVERHEAD_SIZE);
		if(StatusTransfer == XST_SUCCESS)
		{
		      /* Wait to be notified of an interrupt. */
			EventBits_t bits = xEventGroupWaitBits(
							xCreatedEventGroup,   /* The event group being tested. */
							TRANSFER_BIT, /* The bits within the event group to wait for. */
			               pdTRUE,        /* BIT should be cleared before returning. */
			               pdFALSE,       /* Don't wait for both bits, either bit will do. */
						   xMaxBlockTime );
		    if(bits & TRANSFER_BIT)
		    {
		    	memcpy(data, &read_buffer[DATA_OFFSET], byte_count);
		    	address += byte_count;
		    	data += byte_count;
		    	bytes -= byte_count;
		    }
		    else
		    	break;
		}
		else
			break;
	}
}

void eeprom_write(uint32_t address, size_t bytes, uint8_t* data)
{
	s_eeprom_message msg;
	msg.type = WRITE_CMD;
	msg.address = address;
	msg.bytes = bytes;
	msg.data = data;
	xSemaphoreTake( xSemaphore, ( TickType_t ) 100 );
	xEventGroupClearBits(xCreatedEventGroup, COMPLETED_BIT);
	if(xQueueSend(xQueue, &msg, 0UL) != pdPASS)
		return;

	xEventGroupWaitBits(
					xCreatedEventGroup,   /* The event group being tested. */
				   COMPLETED_BIT, /* The bits within the event group to wait for. */
	               pdTRUE,        /* BIT should be cleared before returning. */
	               pdFALSE,       /* Don't wait for both bits, either bit will do. */
				   xMaxBlockTime );
	xSemaphoreGive( xSemaphore );
}

static void eeprom_writefn(uint32_t address, size_t bytes, uint8_t* data)
{
	uint8_t WriteEnableCmd = { WRITE_ENABLE_CMD };
	uint8_t ReadStatusCmd[] = { READ_STATUS_CMD, 0 };  /* must send 2 bytes */
	uint8_t EepromStatus[2];
	size_t byte_count;

	XSpiPs_SetSlaveSelect(&Spi1Instance, EEPROM_SPI_SELECT);
	while(bytes)
	{
		/*
		 * Send the write enable command to the SEEPOM so that it can be
		 * written to, this needs to be sent as a separate transfer before
		 * the write
		 */
		XSpiPs_Transfer(&Spi1Instance, &WriteEnableCmd, NULL, sizeof(WriteEnableCmd));
	    /* Wait to be notified of an interrupt. */
		EventBits_t bits = xEventGroupWaitBits(
							xCreatedEventGroup,   /* The event group being tested. */
							TRANSFER_BIT, /* The bits within the event group to wait for. */
			               pdTRUE,        /* BIT should be cleared before returning. */
			               pdFALSE,       /* Don't wait for both bits, either bit will do. */
						   xMaxBlockTime );


	    if((bits & TRANSFER_BIT) == 0)
	    {
	    	return;
	    }

		/*
		 * Setup the write command with the specified address and data for the
		 * EEPROM
		 */
		write_buffer[COMMAND_OFFSET]     = WRITE_CMD;
		write_buffer[ADDRESS_OFFSET] = (uint8_t)((address & 0xFF0000) >> 16);
		write_buffer[ADDRESS_OFFSET + 1] = (uint8_t)((address & 0x00FF00) >> 8);
		write_buffer[ADDRESS_OFFSET + 2] = (uint8_t)(address & 0x0000FF);

		if(bytes > 256)
		{
			byte_count = 256;
		}
		else
		{
			byte_count = bytes;
		}

		memcpy(&write_buffer[DATA_OFFSET], data, byte_count);

		/*
		 * Send the write command, address, and data to the EEPROM to be
		 * written, no receive buffer is specified since there is nothing to
		 * receive
		 */
		XSpiPs_Transfer(&Spi1Instance, write_buffer, NULL, byte_count + OVERHEAD_SIZE);
	      /* Wait to be notified of an interrupt. */
		bits = xEventGroupWaitBits(
									xCreatedEventGroup,   /* The event group being tested. */
									TRANSFER_BIT, /* The bits within the event group to wait for. */
					               pdTRUE,        /* BIT should be cleared before returning. */
					               pdFALSE,       /* Don't wait for both bits, either bit will do. */
								   xMaxBlockTime );
	    if((bits & TRANSFER_BIT) == 0)
	    {
	    	return;
	    }
		/*
		 * Wait for a bit of time to allow the programming to occur as reading
		 * the status while programming causes it to fail because of noisy power
		 * on the board containing the EEPROM, this loop does not need to be
		 * very long but is longer to hopefully work for a faster processor
		 */
	    vTaskDelay(1);

		/*
		 * Wait for the write command to the EEPROM to be completed, it takes
		 * some time for the data to be written
		 */
		while (1) {
			/*
			 * Poll the status register of the device to determine when it
			 * completes by sending a read status command and receiving the
			 * status byte
			 */
			XSpiPs_Transfer(&Spi1Instance, ReadStatusCmd, EepromStatus,
					sizeof(ReadStatusCmd));
			/*
			 * Wait for the transfer on the SPI bus to be complete before
			 * proceeding
			 */
		      /* Wait to be notified of an interrupt. */
			bits = xEventGroupWaitBits(
										xCreatedEventGroup,   /* The event group being tested. */
										TRANSFER_BIT, /* The bits within the event group to wait for. */
						               pdTRUE,        /* BIT should be cleared before returning. */
						               pdFALSE,       /* Don't wait for both bits, either bit will do. */
									   xMaxBlockTime );
		    if((bits & TRANSFER_BIT) == 0)
		    {
		    	return;
		    }

			/*
			 * If the status indicates the write is done, then stop waiting,
			 * if a value of 0xFF in the status byte is read from the
			 * device and this loop never exits, the device slave select is
			 * possibly incorrect such that the device status is not being
			 * read
			 */
			if ((EepromStatus[1] & 0x03) == 0) {
				break;
			}
		}

		address += byte_count;
		data += byte_count;
		bytes -= byte_count;
	}
}

void SpiHandler(void *CallBackRef, u32 StatusEvent, unsigned int ByteCount)
{
	/*
	 * Indicate the transfer on the SPI bus is no longer in progress
	 * regardless of the status event
	 */

	BaseType_t xHigherPriorityTaskWoken = pdFALSE;
	xEventGroupSetBitsFromISR(xCreatedEventGroup, TRANSFER_BIT, &xHigherPriorityTaskWoken );

	/*
	 * If the event was not transfer done, then track it as an error
	 */
	if (StatusEvent != XST_SPI_TRANSFER_DONE) {
	}
}

static void eeprom_thread(void *p)
{
	s_eeprom_message msg;
	int Status;

	/*
	 * Connect the Spi device to the interrupt subsystem such that
	 * interrupts can occur. This function is application specific
	 */
	Status = XScuGic_Connect(&IntcInstance, SPI_INTR_ID,
				 (Xil_ExceptionHandler)XSpiPs_InterruptHandler,
				 (void *)&Spi1Instance);
	if (Status != XST_SUCCESS) {
		return;
	}

	/*
	 * Enable the interrupt for the Spi device.
	 */
	XScuGic_Enable(&IntcInstance, SPI_INTR_ID);

	for( ;; )
	{
		/* Block to wait for data arriving on the queue. */
		xQueueReceive( 	xQueue,				/* The queue being read. */
						&msg,				/* Data is read into this address. */
						portMAX_DELAY );	/* Wait without a timeout for data. */
		xSemaphoreTake( xSPI1Sem, pdMS_TO_TICKS( 400 ));
		switch(msg.type)
		{
		case READ_CMD:
			eeprom_readfn(msg.address, msg.bytes, msg.data);
			break;
		case WRITE_CMD:
			eeprom_writefn(msg.address, msg.bytes, msg.data);
			break;
		}
		xSemaphoreGive(xSPI1Sem);
		xEventGroupSetBits(xCreatedEventGroup, COMPLETED_BIT);
	}
}

static void eeprom_change_thread(void *p)
{
	int nDelay = 0;
	EventBits_t bits;

	while(1)
	{
		bits = xEventGroupWaitBits(xChangedEvents, CHANGED_BIT, pdTRUE, pdFALSE, portMAX_DELAY);
		nDelay = 1;
		while(nDelay)
		{
			 bits = xEventGroupWaitBits(xChangedEvents, CHANGED_BIT, pdTRUE, pdFALSE, pdMS_TO_TICKS(4000));
			 if(bits == 0)
			 {
				 eeprom_write_vars();
				 nDelay = 0;
			 }
		}
	}
}

static void eeprom_set_const(void)
{
	memset(eeprom_const, 0, sizeof(eeprom_const));

	int points = sizeof(rxa_default) / sizeof(rxa_default[0]);
	e_const->rxa_cnt = points;
	points = sizeof(txafbV_default) / sizeof(txafbV_default[0]);
	e_const->txafbV_cnt = points;
	points = sizeof(txafbC_default) / sizeof(txafbC_default[0]);
	e_const->txafbC_cnt = points;
	points = sizeof(txa_default) / sizeof(txa_default[0]);
	e_const->txa_cnt = points;
	for(int nPos = 0; nPos < points; nPos++)
	{
		e_const->rxa_att[nPos] = rxa_default[nPos];
		e_const->txa_att[nPos] = txa_default[nPos];
		e_const->txafbC_att[nPos] = txafbC_default[nPos];
		e_const->txafbV_att[nPos] = txafbV_default[nPos];
	}
}

static void eeprom_set_vars(void)
{
	memset(eeprom_vars, 0, sizeof(eeprom_vars));

	e_vars->AFGain = 250;
	e_vars->RFGain = 30;
	e_vars->AGCType = AGC_FAST;
	e_vars->mode = TRX_MODE_USB;
	e_vars->vfoA = 14074000;
	e_vars->vfoB = 14074000;
	e_vars->RFPower = 40;
	e_vars->RXAATT = 10;
	e_vars->vRef = 0;
}

uint8_t eeprom_rxa_att(uint32_t freq)
{
	uint8_t value = 0;
	float dValue;
	int nPos;
	for(nPos = 0; nPos < e_const->rxa_cnt; nPos ++)
	{
		if(e_const->rxa_att[nPos].freq > freq)
			break;
	}

	if((nPos > 0) && (nPos < e_const->rxa_cnt))
	{
		float startAtt = e_const->rxa_att[nPos - 1].att;
		float startFreq = e_const->rxa_att[nPos - 1].freq;
		float dFreq = (float)e_const->rxa_att[nPos].freq - startFreq;
		float dAtt = (float)e_const->rxa_att[nPos].att - startAtt;
		dValue = startAtt + ((freq - startFreq) * dAtt / dFreq);
		if(dValue > 63) dValue = 63;
		value = (uint8_t)(dValue + 0.5);
	}

	return value;
}

uint8_t eeprom_txa_att(uint32_t freq)
{
	uint8_t value = 0;
	float dValue;
	int nPos;
	for(nPos = 0; nPos < e_const->txa_cnt; nPos ++)
	{
		if(e_const->txa_att[nPos].freq > freq)
			break;
	}

	if((nPos > 0) && (nPos < e_const->txa_cnt))
	{
		float startAtt = e_const->txa_att[nPos - 1].att;
		float startFreq = e_const->txa_att[nPos - 1].freq;
		float dFreq = (float)e_const->txa_att[nPos].freq - startFreq;
		float dAtt = (float)e_const->txa_att[nPos].att - startAtt;
		dValue = startAtt + ((freq - startFreq) * dAtt / dFreq);
		if(dValue > 63) dValue = 63;
		value = (uint8_t)(dValue + 0.5);
	}

	return value;
}

uint8_t eeprom_txafbV_att(uint32_t freq)
{
	uint8_t value = 0;
	float dValue;
	int nPos;
	for(nPos = 0; nPos < e_const->txafbV_cnt; nPos ++)
	{
		if(e_const->txafbV_att[nPos].freq > freq)
			break;
	}

	if((nPos > 0) && (nPos < e_const->txafbV_cnt))
	{
		float startAtt = e_const->txafbV_att[nPos - 1].att;
		float startFreq = e_const->txafbV_att[nPos - 1].freq;
		float dFreq = (float)e_const->txafbV_att[nPos].freq - startFreq;
		float dAtt = (float)e_const->txafbV_att[nPos].att - startAtt;
		dValue = startAtt + ((freq - startFreq) * dAtt / dFreq);
		if(dValue > 63) dValue = 63;
		value = (uint8_t)(dValue + 0.5);
	}

	return value;
}


uint8_t eeprom_txafbC_att(uint32_t freq)
{
	uint8_t value = 0;
	float dValue;
	int nPos;
	for(nPos = 0; nPos < e_const->txafbC_cnt; nPos ++)
	{
		if(e_const->txafbC_att[nPos].freq > freq)
			break;
	}

	if((nPos > 0) && (nPos < e_const->txafbC_cnt))
	{
		float startAtt = e_const->txafbC_att[nPos - 1].att;
		float startFreq = e_const->txafbC_att[nPos - 1].freq;
		float dFreq = (float)e_const->txafbC_att[nPos].freq - startFreq;
		float dAtt = (float)e_const->txafbC_att[nPos].att - startAtt;
		dValue = startAtt + ((freq - startFreq) * dAtt / dFreq);
		if(dValue > 63) dValue = 63;
		value = (uint8_t)(dValue + 0.5);
	}

	return value;
}
