/*
 * gpio.c
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#include "main.h"
#include "cmd.h"
#include "gpio.h"

extern DAC_HandleTypeDef hdac;
extern SPI_HandleTypeDef hspi1;
GPIO_PinState gpioTx = GPIO_PIN_RESET;
GPIO_PinState gpioFail = GPIO_PIN_RESET;
static uint8_t att_value = 0;

void gpio_tick(void)
{
	if(HAL_GPIO_ReadPin(INPUT_TXON_GPIO_Port, INPUT_TXON_Pin) != gpioTx)
	{
		gpioTx = HAL_GPIO_ReadPin(INPUT_TXON_GPIO_Port, INPUT_TXON_Pin);
		if(gpioTx == GPIO_PIN_SET)
		{
			gpio_tx_on();
		}
		else
		{
			gpio_tx_off();
		}
	}

	if(HAL_GPIO_ReadPin(INPUT_TX_FAIL_GPIO_Port, INPUT_TX_FAIL_Pin) != gpioFail)
	{
		gpioFail = HAL_GPIO_ReadPin(INPUT_TX_FAIL_GPIO_Port, INPUT_TX_FAIL_Pin);
		if(gpioFail == GPIO_PIN_SET)
		{
			gpio_tx_off();
		}
	}
}

void gpio_tx_on(void)
{
	HAL_GPIO_WritePin(RX_EN_GPIO_Port, RX_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(TX_EN_GPIO_Port, TX_EN_Pin, GPIO_PIN_SET);
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, DRV_DAC_VALUE);
}

void gpio_tx_off(void)
{
	HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, 0);
	HAL_GPIO_WritePin(TX_EN_GPIO_Port, TX_EN_Pin, GPIO_PIN_RESET);
	HAL_GPIO_WritePin(RX_EN_GPIO_Port, RX_EN_Pin, GPIO_PIN_SET);
}

void gpio_band(int band)
{
	  HAL_GPIO_WritePin(BAND0_EN_GPIO_Port, BAND0_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND1_EN_GPIO_Port, BAND1_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND2_EN_GPIO_Port, BAND2_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND3_EN_GPIO_Port, BAND3_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND4_EN_GPIO_Port, BAND4_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND5_EN_GPIO_Port, BAND5_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND6_EN_GPIO_Port, BAND6_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND7_EN_GPIO_Port, BAND7_EN_Pin, GPIO_PIN_RESET);
	  HAL_GPIO_WritePin(BAND8_EN_GPIO_Port, BAND8_EN_Pin, GPIO_PIN_RESET);

	  HAL_GPIO_WritePin(BAND0_DIS_GPIO_Port, BAND0_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND1_DIS_GPIO_Port, BAND1_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND2_DIS_GPIO_Port, BAND2_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND3_DIS_GPIO_Port, BAND3_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND4_DIS_GPIO_Port, BAND4_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND5_DIS_GPIO_Port, BAND5_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND6_DIS_GPIO_Port, BAND6_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND7_DIS_GPIO_Port, BAND7_DIS_Pin, GPIO_PIN_SET);
	  HAL_GPIO_WritePin(BAND8_DIS_GPIO_Port, BAND8_DIS_Pin, GPIO_PIN_SET);

	  switch (band) {
	  case 0:
		  HAL_GPIO_WritePin(BAND0_DIS_GPIO_Port, BAND0_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND0_EN_GPIO_Port, BAND0_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 1:
		  HAL_GPIO_WritePin(BAND1_DIS_GPIO_Port, BAND1_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND1_EN_GPIO_Port, BAND1_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 2:
		  HAL_GPIO_WritePin(BAND2_DIS_GPIO_Port, BAND2_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND2_EN_GPIO_Port, BAND2_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 3:
		  HAL_GPIO_WritePin(BAND3_DIS_GPIO_Port, BAND3_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND3_EN_GPIO_Port, BAND3_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 4:
		  HAL_GPIO_WritePin(BAND4_DIS_GPIO_Port, BAND4_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND4_EN_GPIO_Port, BAND4_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 5:
		  HAL_GPIO_WritePin(BAND5_DIS_GPIO_Port, BAND5_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND5_EN_GPIO_Port, BAND5_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 6:
		  HAL_GPIO_WritePin(BAND6_DIS_GPIO_Port, BAND6_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND6_EN_GPIO_Port, BAND6_EN_Pin, GPIO_PIN_SET);
		  break;
	  case 7:
		  HAL_GPIO_WritePin(BAND7_DIS_GPIO_Port, BAND7_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND7_EN_GPIO_Port, BAND7_EN_Pin, GPIO_PIN_SET); break;
	  default:
		  HAL_GPIO_WritePin(BAND8_DIS_GPIO_Port, BAND8_DIS_Pin, GPIO_PIN_RESET);
		  HAL_GPIO_WritePin(BAND8_EN_GPIO_Port, BAND8_EN_Pin, GPIO_PIN_SET);
	  }
}

void gpio_att(uint8_t value)
{
	att_value = value;
	HAL_SPI_Transmit(&hspi1, &value, 1, 10000);
	HAL_GPIO_WritePin(ATT_LE0_GPIO_Port, ATT_LE0_Pin, GPIO_PIN_SET);
	HAL_GPIO_WritePin(ATT_LE0_GPIO_Port, ATT_LE0_Pin, GPIO_PIN_RESET);
}

void gpio_pwr(uint8_t value)
{
	HAL_SPI_Transmit(&hspi1, &value, 1, 10000);
	HAL_GPIO_WritePin(ATT_LE1_GPIO_Port, ATT_LE1_Pin, GPIO_PIN_SET);
	HAL_GPIO_WritePin(ATT_LE1_GPIO_Port, ATT_LE1_Pin, GPIO_PIN_RESET);
}
