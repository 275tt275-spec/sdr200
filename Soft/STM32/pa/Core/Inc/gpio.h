/*
 * gpio.h
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#ifndef INC_GPIO_H_
#define INC_GPIO_H_

void gpio_tick(void);
void gpio_tx_on(void);
void gpio_tx_off(void);
void gpio_set_fail(void);
void gpio_band(uint8_t band);

#endif /* INC_GPIO_H_ */
