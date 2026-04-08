/*
 * gpio.c
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#include "main.h"
#include "cmd.h"
#include "gpio.h"

GPIO_PinState gpioTx = GPIO_PIN_RESET;

void gpio_tick(void)
{
	if(HAL_GPIO_ReadPin(TX_ON_GPIO_Port, TX_ON_Pin) != gpioTx)
	{
		gpioTx = HAL_GPIO_ReadPin(TX_ON_GPIO_Port, TX_ON_Pin);
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
	HAL_GPIO_WritePin(RX_EN_GPIO_Port, RX_EN_Pin, GPIO_PIN_SET);
	HAL_GPIO_WritePin(TX_EN_GPIO_Port, TX_EN_Pin, GPIO_PIN_RESET);
}

void gpio_tx_off(void)
{
	HAL_GPIO_WritePin(TX_EN_GPIO_Port, TX_EN_Pin, GPIO_PIN_SET);
	HAL_GPIO_WritePin(RX_EN_GPIO_Port, RX_EN_Pin, GPIO_PIN_RESET);
}

void gpio_set_baypass(uint8_t bypass)
{
	if(bypass == 1)
		HAL_GPIO_WritePin(BYPASS0_GPIO_Port, BYPASS0_Pin, GPIO_PIN_SET);
	else
		HAL_GPIO_WritePin(BYPASS0_GPIO_Port, BYPASS0_Pin, GPIO_PIN_RESET);
}

void gpio_set_capacitor(uint8_t set)
{
	if(set == 1)
		HAL_GPIO_WritePin(CAP_SEL_GPIO_Port, CAP_SEL_Pin, GPIO_PIN_SET);
	else
		HAL_GPIO_WritePin(CAP_SEL_GPIO_Port, CAP_SEL_Pin, GPIO_PIN_RESET);
}

void gpio_set_external(uint8_t set)
{
	if(set == 1)
		HAL_GPIO_WritePin(EXT_AMP_GPIO_Port, EXT_AMP_Pin, GPIO_PIN_RESET);
	else
		HAL_GPIO_WritePin(EXT_AMP_GPIO_Port, EXT_AMP_Pin, GPIO_PIN_SET);
}

void gpio_set_C(uint8_t mask)
{
	HAL_GPIO_WritePin(SEL_C1_GPIO_Port, SEL_C1_Pin, mask & (1 << 0) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C2_GPIO_Port, SEL_C2_Pin, mask & (1 << 1) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C3_GPIO_Port, SEL_C3_Pin, mask & (1 << 2) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C4_GPIO_Port, SEL_C4_Pin, mask & (1 << 3) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C5_GPIO_Port, SEL_C5_Pin, mask & (1 << 4) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C6_GPIO_Port, SEL_C6_Pin, mask & (1 << 5) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_C7_GPIO_Port, SEL_C7_Pin, mask & (1 << 6) ? GPIO_PIN_RESET : GPIO_PIN_SET);
}

void gpio_set_L(uint8_t mask)
{
	HAL_GPIO_WritePin(SEL_L1_GPIO_Port, SEL_L1_Pin, mask & (1 << 0) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L2_GPIO_Port, SEL_L2_Pin, mask & (1 << 1) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L3_GPIO_Port, SEL_L3_Pin, mask & (1 << 2) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L4_GPIO_Port, SEL_L4_Pin, mask & (1 << 3) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L5_GPIO_Port, SEL_L5_Pin, mask & (1 << 4) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L6_GPIO_Port, SEL_L6_Pin, mask & (1 << 5) ? GPIO_PIN_RESET : GPIO_PIN_SET);
	HAL_GPIO_WritePin(SEL_L7_GPIO_Port, SEL_L7_Pin, mask & (1 << 6) ? GPIO_PIN_RESET : GPIO_PIN_SET);
}
