/*
 * gpio.c
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#include "main.h"
#include "cmd.h"
#include "adc.h"
#include "gpio.h"

extern DAC_HandleTypeDef hdac;
GPIO_PinState 	gpioTx = GPIO_PIN_RESET;
uint32_t 		dac_out[2] = {0};
int 			isTxOn = 0;

void gpio_tick(void)
{
	if(HAL_GPIO_ReadPin(CON_TX_ON_GPIO_Port, CON_TX_ON_Pin) != gpioTx)
	{
		gpioTx = HAL_GPIO_ReadPin(CON_TX_ON_GPIO_Port, CON_TX_ON_Pin);
		if(gpioTx == GPIO_PIN_SET)
		{
			gpio_tx_on();
		}
		else
		{
			gpio_tx_off();
		}
	}
}

void gpio_tx_on(void)
{
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, dac_out[0]);
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_2, DAC_ALIGN_12B_R, dac_out[1]);
	isTxOn = 1;
}

void gpio_tx_off(void)
{
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, 0);
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_2, DAC_ALIGN_12B_R, 0);
	HAL_GPIO_WritePin(TX_FAIL_GPIO_Port, TX_FAIL_Pin, GPIO_PIN_RESET);
	isTxOn = 0;
}

void gpio_set_fail(void)
{
	gpio_tx_off();
	HAL_GPIO_WritePin(TX_FAIL_GPIO_Port, TX_FAIL_Pin, GPIO_PIN_SET);
}

void gpio_band(uint8_t band)
{
	HAL_GPIO_WritePin(BAND0_EN_GPIO_Port, BAND0_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND1_EN_GPIO_Port, BAND1_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND2_EN_GPIO_Port, BAND2_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND3_EN_GPIO_Port, BAND3_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND4_EN_GPIO_Port, BAND4_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND5_EN_GPIO_Port, BAND5_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(BAND6_EN_GPIO_Port, BAND6_EN_Pin, GPIO_PIN_RESET);

	switch (band) {
	case 0:
	  HAL_GPIO_WritePin(BAND0_EN_GPIO_Port, BAND0_EN_Pin, GPIO_PIN_SET);
	  break;
	case 1:
	  HAL_GPIO_WritePin(BAND1_EN_GPIO_Port, BAND1_EN_Pin, GPIO_PIN_SET);
	  break;
	case 2:
	  HAL_GPIO_WritePin(BAND2_EN_GPIO_Port, BAND2_EN_Pin, GPIO_PIN_SET);
	  break;
	case 3:
	  HAL_GPIO_WritePin(BAND3_EN_GPIO_Port, BAND3_EN_Pin, GPIO_PIN_SET);
	  break;
	case 4:
	  HAL_GPIO_WritePin(BAND4_EN_GPIO_Port, BAND4_EN_Pin, GPIO_PIN_SET);
	  break;
	case 5:
	  HAL_GPIO_WritePin(BAND5_EN_GPIO_Port, BAND5_EN_Pin, GPIO_PIN_SET);
	  break;
	case 6:
	  HAL_GPIO_WritePin(BAND6_EN_GPIO_Port, BAND6_EN_Pin, GPIO_PIN_SET);
	  break;
	}
}
