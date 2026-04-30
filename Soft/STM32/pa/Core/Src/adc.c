/*
 * adc.c
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#include <string.h>

#include "main.h"
#include "cmd.h"
#include "adc.h"
#include "gpio.h"
#include "ntc_therm.h"

extern ADC_HandleTypeDef 	hadc1;
extern TIM_HandleTypeDef 	htim3;
extern DAC_HandleTypeDef 	hdac;

static s_adc_values         adc_data[2];
static s_adc_values		    inValues;
static __IO uint32_t 		status_flags = 0;
#define	ADC_HALF_CPLT		(1 << 0)
#define ADC_CONV_CPLT		(1 << 1)
#define ADC_WEIGHT_FACTOR	8

extern uint32_t 	dac_out[2];
extern int 			isTxOn;
int16_t				pa_degC = 0;
uint16_t 			pa_ImA = 0;
uint16_t 			pa_VmV = 0;
static uint32_t 	acc_temperature = 0;
static uint32_t 	acc_current = 0;
static uint32_t 	acc_voltage = 0;
static s_adc_poly	coeff_ImA = {0, 4.06504065 * (1 << 16), 0 * (1 << 16)};
static s_adc_poly	coeff_VmV = {0, 4.06504065 * (1 << 16), 0 * (1 << 16)};
static s_adc_poly	coeff_biasPA0 = {0, -1.3251 * (1 << 16), 2331 * (1 << 16)};
static s_adc_poly	coeff_biasPA1 = {0, -1.3251 * (1 << 16), 2331 * (1 << 16)};

void adc_start(void)
{
	HAL_ADCEx_Calibration_Start(&hadc1);
	HAL_ADC_Start_DMA(&hadc1, (uint32_t*) adc_data, sizeof(s_adc_values));
	HAL_TIM_Base_Start_IT(&htim3);
}

void adc_stop(void)
{
	HAL_ADC_Stop_DMA(&hadc1);
	HAL_TIM_Base_Stop_IT(&htim3);
}

static int32_t adc_calculate(int32_t inValue, s_adc_poly* coeff)
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

static void adc_measure(void)
{
	acc_voltage -= acc_voltage >> ADC_WEIGHT_FACTOR;
	acc_voltage += inValues.in1;
	acc_temperature -= acc_temperature >> ADC_WEIGHT_FACTOR;
	acc_temperature += inValues.in2;
	acc_current -= acc_current >> ADC_WEIGHT_FACTOR;
	acc_current += inValues.in3;

	pa_degC = ntc_get_t(ntcalug01t103fl, acc_temperature >> ADC_WEIGHT_FACTOR);
	pa_ImA = (uint16_t)(adc_calculate(acc_current >> ADC_WEIGHT_FACTOR, &coeff_ImA) & 0xFFFF);
	pa_VmV = (uint16_t)(adc_calculate(acc_voltage >> ADC_WEIGHT_FACTOR, &coeff_VmV) & 0xFFFF);

	dac_out[0] = (uint16_t)adc_calculate(pa_degC, &coeff_biasPA0);
	dac_out[1] = (uint16_t)adc_calculate(pa_degC, &coeff_biasPA1);
	if(isTxOn == 1)
	{
		HAL_DAC_SetValue(&hdac, DAC_CHANNEL_1, DAC_ALIGN_12B_R, dac_out[0]);
		HAL_DAC_SetValue(&hdac, DAC_CHANNEL_2, DAC_ALIGN_12B_R, dac_out[1]);

		if(pa_degC > MAX_TEMPERATURE)
		{
			gpio_set_fail();
		}
		if(pa_ImA > MAX_CURRENT)
		{
			gpio_set_fail();
		}
		if((pa_VmV > MAX_VOLTAGE) || (pa_VmV < MIN_VOLTAGE))
		{
			gpio_set_fail();
		}
	}
}

void adc_tick(void)
{
	__IO uint32_t status = status_flags;

	if((status & ADC_HALF_CPLT) && (status & ADC_CONV_CPLT)) // Пропустили, теперь не знаем откуда считывать
	{
		ATOMIC_CLEAR_BIT(status_flags, ADC_HALF_CPLT || ADC_CONV_CPLT);
	}
	else if(status & ADC_HALF_CPLT)
	{
		memcpy(&inValues, &adc_data[0], sizeof(s_adc_values));
		ATOMIC_CLEAR_BIT(status_flags, ADC_HALF_CPLT);
		adc_measure();
	}

	if(status & ADC_CONV_CPLT)
	{
		memcpy(&inValues, &adc_data[1], sizeof(s_adc_values));
		ATOMIC_CLEAR_BIT(status_flags, ADC_CONV_CPLT);
		adc_measure();
	}
}

void HAL_ADC_ConvCpltCallback(ADC_HandleTypeDef* hadc)
{
	ATOMIC_SET_BIT(status_flags, ADC_CONV_CPLT);
}

void HAL_ADC_ConvHalfCpltCallback(ADC_HandleTypeDef* hadc)
{
	ATOMIC_SET_BIT(status_flags, ADC_HALF_CPLT);
}
