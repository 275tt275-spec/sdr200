/*
 * max6651.c
 *
 *  Created on: May 30, 2024
 *      Author: VictorT
 */

#include "main.h"
#include "max6651.h"
#include "adc.h"

extern I2C_HandleTypeDef hi2c1;

uint8_t 		fan_tach0, fan_tach1, fan_tach2;
uint8_t 		fan_ctrl;
uint8_t 		fan_ctrl_old = 0;
uint8_t 		fan_speed;
extern int16_t	pa_degC;

static s_adc_poly			coeff_fan = {0, -10.2 * (1 << 16), 459 * (1 << 16)};  // 20 - 45 C

__IO uint32_t 		status_flags = 0;
#define	TX_IN_PROGRESS		(1 << 0)
#define	RX_NEED     		(1 << 1)

static void MX_I2C1_Init(void)
{

  /* USER CODE BEGIN I2C1_Init 0 */

  /* USER CODE END I2C1_Init 0 */

  /* USER CODE BEGIN I2C1_Init 1 */

  /* USER CODE END I2C1_Init 1 */
  hi2c1.Instance = I2C1;
  hi2c1.Init.ClockSpeed = 100000;
  hi2c1.Init.DutyCycle = I2C_DUTYCYCLE_2;
  hi2c1.Init.OwnAddress1 = 0;
  hi2c1.Init.AddressingMode = I2C_ADDRESSINGMODE_7BIT;
  hi2c1.Init.DualAddressMode = I2C_DUALADDRESS_DISABLE;
  hi2c1.Init.OwnAddress2 = 0;
  hi2c1.Init.GeneralCallMode = I2C_GENERALCALL_DISABLE;
  hi2c1.Init.NoStretchMode = I2C_NOSTRETCH_DISABLE;
  if (HAL_I2C_Init(&hi2c1) != HAL_OK)
  {
    Error_Handler();
  }
  /* USER CODE BEGIN I2C1_Init 2 */

  /* USER CODE END I2C1_Init 2 */

}

void max6651_init(void)
{
	if(hi2c1.Instance->SR2 & I2C_FLAG_BUSY)
		MX_I2C1_Init();

	uint8_t data[2] = { MAX6651_CONFIG_REG, MAX6651_OPEN_LOOP | MAX6651_12V | MAX6651_DIV_2};
	HAL_I2C_Master_Transmit(&hi2c1, MAX6650_ADDRESS, data, 2, 10000);
    data[0] = MAX6651_COUNT_REG; data[1] = 2;
    HAL_I2C_Master_Transmit(&hi2c1, MAX6650_ADDRESS, data, 2, 10000);
    data[0] = MAX6651_DAC_REG; data[1] = fan_ctrl_old;
    HAL_I2C_Master_Transmit(&hi2c1, MAX6650_ADDRESS, data, 2, 10000);
}

void max6651_deinit(void)
{
	uint8_t data[2] = { MAX6651_CONFIG_REG, MAX6651_OFF | MAX6651_12V | MAX6651_DIV_4 };
	HAL_I2C_Master_Transmit(&hi2c1, MAX6650_ADDRESS, data, 2, 10000);
}

HAL_StatusTypeDef max6651_set(uint8_t value)
{
	HAL_StatusTypeDef ret;
	uint8_t data[2] = { MAX6651_DAC_REG, value };
	ret = HAL_I2C_Master_Transmit(&hi2c1, MAX6650_ADDRESS, data, 2, 10000);
//	ret = HAL_I2C_Master_Transmit_IT(&hi2c1, MAX6650_ADDRESS, data, 2);
//	if(ret == HAL_OK)
//		ATOMIC_SET_BIT(status_flags, TX_IN_PROGRESS);

	return ret;
}

uint8_t max6651_get(uint8_t idx)
{
	uint8_t value = 0;
	uint16_t reg;

	switch (idx){
	case 1: reg = MAX6651_TACH1_REG; break;
	case 2: reg = MAX6651_TACH2_REG; break;
	case 3: reg = MAX6651_TACH3_REG; break;
	default: reg = MAX6651_TACH0_REG;
	}

	if((status_flags & TX_IN_PROGRESS) == 0)
	{
		if(HAL_I2C_Mem_Read(&hi2c1, MAX6650_ADDRESS, reg, I2C_MEMADD_SIZE_8BIT, &value, 1, 10000 ) == HAL_OK)
			fan_speed = value;
	}
	else
		ATOMIC_SET_BIT(status_flags, RX_NEED);
	return fan_speed;
}

static int32_t max6651_calculate(int32_t inValue, s_adc_poly* coeff)
{
	int64_t retValue64;
	int64_t in = inValue;

	if(coeff->a == 0)
		retValue64 = in * (int64_t)coeff->b + (int64_t)coeff->c;
	else
		retValue64 = in * (coeff->a * in + coeff->b) + (int64_t)coeff->c;

	if(retValue64 < 0)
		retValue64 = 0;

	return (int32_t)(retValue64 >> 16);
}

void max6651_tick(void)
{
	int32_t fan = max6651_calculate(pa_degC, &coeff_fan);
	if(fan < 0)
		fan = 0;
	else if(fan > 255)
		fan = 255;

	fan_ctrl = (uint8_t)fan;

	if(fan_ctrl_old != fan_ctrl)
	{
		if(max6651_set(fan_ctrl) == HAL_OK)
			fan_ctrl_old = fan_ctrl;
	}

	if(status_flags & RX_NEED)
	{
		max6651_get(0);
		ATOMIC_CLEAR_BIT(status_flags, RX_NEED);
	}
}

void HAL_I2C_MasterTxCpltCallback(I2C_HandleTypeDef *hi2c)
{
	ATOMIC_CLEAR_BIT(status_flags, TX_IN_PROGRESS);
}

void HAL_I2C_ErrorCallback(I2C_HandleTypeDef *hi2c)
{
	ATOMIC_CLEAR_BIT(status_flags, TX_IN_PROGRESS);
}
