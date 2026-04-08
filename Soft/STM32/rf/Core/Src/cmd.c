/*
 * cmd.c
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */
#include <string.h>
#include <stdlib.h>

#include "main.h"
#include "cmd.h"
#include "gpio.h"

static uint8_t rx_buffer[256];
extern UART_HandleTypeDef huart3;
extern DMA_HandleTypeDef hdma_usart3_rx;
static __IO uint32_t old_pos;
static uint32_t rx_ptr;
static uint32_t rx_cmd_ptr;
static char rx_cmd[256];
static char rx_ch;

static void cmd_parse(const char* msg, size_t len);
static void cmd_rx_data(const char* data, uint32_t len);
static const char chStartFreq[] = "RB08;";
static const char chStartAtt[] = "RA00;";

void cmd_start(void)
{
	__HAL_UART_CLEAR_NEFLAG(&huart3);
	__HAL_UART_CLEAR_OREFLAG(&huart3);
	__HAL_UART_CLEAR_FEFLAG(&huart3);
	__HAL_UART_CLEAR_PEFLAG(&huart3);
	__HAL_UART_FLUSH_DRREGISTER(&huart3);
	old_pos = 0;
	rx_ptr = 0;
	rx_cmd_ptr = 0;
	HAL_UART_Receive_DMA(&huart3, &rx_buffer[0], sizeof(rx_buffer));

	cmd_parse(chStartFreq, strlen(chStartFreq) - 1);
	cmd_parse(chStartAtt, strlen(chStartAtt) - 1);
	HAL_Delay(10);
	cmd_parse(chStartAtt, strlen(chStartAtt) - 1);
}

void cmd_stop(void)
{
	HAL_UART_AbortReceive_IT(&huart3);
	HAL_UART_DMAStop(&huart3);
}

void cmd_tick(void)
{
	// LL_DMA_GetDataLength(DMA1, LL_DMA_STREAM_1)
	__IO uint32_t pos = __HAL_DMA_GET_COUNTER(&hdma_usart3_rx);
	pos = sizeof(rx_buffer) - pos;
	if(old_pos != pos)
	{
		if (pos > old_pos) {                    /* Current position is over previous one */
			/* We are in "linear" mode */
			/* Process data directly by subtracting "pointers" */
			cmd_rx_data((const char*)&rx_buffer[old_pos], pos - old_pos);
		} else {
			/* We are in "overflow" mode */
			/* First process data to the end of buffer */
			cmd_rx_data((const char*)&rx_buffer[old_pos], sizeof(rx_buffer) - old_pos);
			/* Continue from beginning of buffer */
			cmd_rx_data((const char*)&rx_buffer[0], pos);
		}

		old_pos = pos;                              /* Save current position as old */

	    if (old_pos >= sizeof(rx_buffer)) {
	        old_pos = 0;
	    }
	}
}

static void cmd_rx_data(const char* data, uint32_t len)
{
	while(len--)
	{
		rx_ch = *data++;
		if(rx_ch == ';')
		{
			rx_cmd[rx_cmd_ptr] = 0;
			cmd_parse(&rx_cmd[0], rx_cmd_ptr);
			rx_cmd_ptr = 0;
		}
		else
		{
			rx_cmd[rx_cmd_ptr] = rx_ch;
			if(++rx_cmd_ptr == sizeof(rx_cmd))
			{
				rx_cmd_ptr = 0;
			}
		}
	}
}

static void cmd_parse(const char* msg, size_t len)
{
	char value[4];

#if 0
	if(memcmp(msg, "FA", 2) == 0) /* Sets the VFO A frequency Hz */
	{
		if(strlen(msg) > 2)
		{
			m_fa = atoi(&msg[2]);

			if(m_fa < 1800000)
				gpio_band(0);
			else if(m_fa < 2500000)
				gpio_band(1);
			else if(m_fa < 4000000)
				gpio_band(2);
			else if(m_fa < 7500000)
				gpio_band(3);
			else if(m_fa < 9500000)
				gpio_band(4);
			else if(m_fa < 14000000)
				gpio_band(5);
			else if(m_fa < 18500000)
				gpio_band(6);
			else if(m_fa < 40000000)
				gpio_band(7);
			else
				gpio_band(8);
		}
	}
	else if(memcmp(msg, "RA", 2) == 0) /* Sets the Attenuator function status 0-63 */
	{
		memcpy(value, &msg[2], 2); value[2] = 0;
		m_ra = (uint8_t)atoi(value);
		gpio_att(m_ra);
	}
	else if(memcmp(msg, "PC", 2) == 0) /* Sets the output power 0-63 */
	{
		memcpy(value, &msg[2], 2); value[2] = 0;
		m_pc = (uint8_t)atoi(value);
		gpio_pwr(m_pc);
	}

#else
	if(len > 2)
	{
		if(msg[0] == 'R')
		{
			switch(msg[1]) {
			case 'B': // band
				value[3] = 0;
				memcpy(value, &msg[2], 2);
				gpio_band((uint8_t)atoi(value));
				break;
			case 'A': // Sets the Attenuator function status 0-63
				value[3] = 0;
				memcpy(value, &msg[2], 2);
				gpio_att((uint8_t)atoi(value));
				break;
			case 'T': // Sets the output power 0-63
				value[3] = 0;
				memcpy(value, &msg[2], 2);
				gpio_pwr((uint8_t)atoi(value));
				break;
			}
		}
	}
#endif
}
