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

static void cmd_parse(char* msg, size_t len);
static void cmd_rx_data(const char* data, uint32_t len);


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

	gpio_tx_off();
	gpio_set_baypass(1);
	gpio_set_external(0);
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

static void cmd_parse(char* msg, size_t len)
{
	char value[4];
	if(len > 2)
	{
		if(msg[0] == 'A')
		{
			switch(msg[1]) {
			case 'B' : // bypass
				gpio_set_baypass(msg[2] == '0' ? 0 : 1);
				break;
			case 'C' : // capacitor select
				gpio_set_capacitor(msg[2] == '0' ? 0 : 1);
				break;
			case 'E' : // external amplifier
				gpio_set_external(msg[2] == '0' ? 0 : 1);
				break;
			case 'S' : // set inductor, capacitor
				if(len == 8)
				{
					value[3] = 0;
					memcpy(value, &msg[2], 3);
					gpio_set_L((uint8_t)atoi(value));
					memcpy(value, &msg[5], 3);
					gpio_set_C((uint8_t)atoi(value));
				}
				break;
			}
		}
	}
}
