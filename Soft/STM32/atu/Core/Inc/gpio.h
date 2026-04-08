/*
 * gpio.h
 *
 *  Created on: Nov 30, 2025
 *      Author: user
 */

#ifndef INC_GPIO_H_
#define INC_GPIO_H_

#define DRV_DAC_VALUE	2150

void gpio_tick(void);
void gpio_tx_on(void);
void gpio_tx_off(void);
void gpio_set_baypass(uint8_t bypass);
void gpio_set_capacitor(uint8_t set);
void gpio_set_external(uint8_t set);
void gpio_set_C(uint8_t mask);
void gpio_set_L(uint8_t mask);


#endif /* INC_GPIO_H_ */
