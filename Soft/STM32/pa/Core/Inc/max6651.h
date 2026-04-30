/*
 * max6651.h
 *
 *  Created on: May 30, 2024
 *      Author: VictorT
 */

#ifndef INC_MAX6651_H_
#define INC_MAX6651_H_

#define MAX6651_ADDRESS 	0x3E

#define MAX6651_SPEED_REG 	0x0
#define MAX6651_CONFIG_REG 	0x2
#define MAX6651_DEF_REG 	0x4
#define MAX6651_DAC_REG 	0x6
#define MAX6651_ALARM_EN_REG 	0x8
#define MAX6651_ALARM_REG 	0xA
#define MAX6651_TACH0_REG 	0xC
#define MAX6651_TACH1_REG 	0xE
#define MAX6651_TACH2_REG 	0x10
#define MAX6651_TACH3_REG 	0x12
#define MAX6651_STAT_REG 	0x14
#define MAX6651_COUNT_REG 	0x16

#define MAX6651_ON 			0
#define MAX6651_OFF 		(1 << 4)
#define MAX6651_CLOSE_LOOP 	(2 << 4)
#define MAX6651_OPEN_LOOP 	(3 << 4)
#define MAX6651_5V 			0
#define MAX6651_12V 		(1 << 3)
#define MAX6651_DIV_1 		0
#define MAX6651_DIV_2 		1
#define MAX6651_DIV_4 		2
#define MAX6651_DIV_8		3
#define MAX6651_DIV_16 		4

#define MAX6650_ADDRESS 	0x90

void max6651_init(void);
void max6651_deinit(void);
HAL_StatusTypeDef max6651_set(uint8_t value);
uint8_t max6651_get(uint8_t idx);
void max6651_tick(void);

#endif /* INC_MAX6651_H_ */
