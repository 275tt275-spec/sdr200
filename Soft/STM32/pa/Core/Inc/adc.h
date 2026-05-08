/*
 * adc.h
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#ifndef INC_ADC_H_
#define INC_ADC_H_

#define MAX_TEMPERATURE		110
#define MAX_CURRENT		    15000
#define MAX_VOLTAGE		    3400
#define MIN_VOLTAGE		    1100

typedef struct tag_adc_values
{
	uint16_t in1;  // Voltage
	uint16_t in2;  // Temperature
	uint16_t in3;  // Current
} s_adc_values;

typedef struct tag_adc_poly
{
	int32_t a;
	int32_t b;
	int32_t c;
} s_adc_poly;

void adc_start(void);
void adc_stop(void);
void adc_tick(void);

#endif /* INC_ADC_H_ */
