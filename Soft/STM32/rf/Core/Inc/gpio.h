/*
 * gpio.h
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#ifndef INC_GPIO_H_
#define INC_GPIO_H_

#define DRV_DAC_VALUE	1700

void gpio_tick(void);
void gpio_tx_on(void);
void gpio_tx_off(void);
void gpio_band(int band);
void gpio_att(uint8_t value);
void gpio_pwr(uint8_t value);

#endif /* INC_GPIO_H_ */
