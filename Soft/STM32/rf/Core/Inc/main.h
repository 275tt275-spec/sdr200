/* USER CODE BEGIN Header */
/**
  ******************************************************************************
  * @file           : main.h
  * @brief          : Header for main.c file.
  *                   This file contains the common defines of the application.
  ******************************************************************************
  * @attention
  *
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  *
  ******************************************************************************
  */
/* USER CODE END Header */

/* Define to prevent recursive inclusion -------------------------------------*/
#ifndef __MAIN_H
#define __MAIN_H

#ifdef __cplusplus
extern "C" {
#endif

/* Includes ------------------------------------------------------------------*/
#include "stm32f1xx_hal.h"

/* Private includes ----------------------------------------------------------*/
/* USER CODE BEGIN Includes */

/* USER CODE END Includes */

/* Exported types ------------------------------------------------------------*/
/* USER CODE BEGIN ET */

/* USER CODE END ET */

/* Exported constants --------------------------------------------------------*/
/* USER CODE BEGIN EC */

/* USER CODE END EC */

/* Exported macro ------------------------------------------------------------*/
/* USER CODE BEGIN EM */

/* USER CODE END EM */

/* Exported functions prototypes ---------------------------------------------*/
void Error_Handler(void);

/* USER CODE BEGIN EFP */

/* USER CODE END EFP */

/* Private defines -----------------------------------------------------------*/
#define ATT_LE1_Pin GPIO_PIN_14
#define ATT_LE1_GPIO_Port GPIOC
#define ATT_LE0_Pin GPIO_PIN_15
#define ATT_LE0_GPIO_Port GPIOC
#define BAND6_DIS_Pin GPIO_PIN_0
#define BAND6_DIS_GPIO_Port GPIOC
#define BAND5_EN_Pin GPIO_PIN_1
#define BAND5_EN_GPIO_Port GPIOC
#define BAND5_DIS_Pin GPIO_PIN_2
#define BAND5_DIS_GPIO_Port GPIOC
#define BAND4_EN_Pin GPIO_PIN_3
#define BAND4_EN_GPIO_Port GPIOC
#define BAND4_DIS_Pin GPIO_PIN_2
#define BAND4_DIS_GPIO_Port GPIOA
#define BAND3_EN_Pin GPIO_PIN_3
#define BAND3_EN_GPIO_Port GPIOA
#define BAND3_DIS_Pin GPIO_PIN_4
#define BAND3_DIS_GPIO_Port GPIOC
#define BAND2_EN_Pin GPIO_PIN_5
#define BAND2_EN_GPIO_Port GPIOC
#define BAND2_DIS_Pin GPIO_PIN_0
#define BAND2_DIS_GPIO_Port GPIOB
#define BAND1_EN_Pin GPIO_PIN_1
#define BAND1_EN_GPIO_Port GPIOB
#define BAND1_DIS_Pin GPIO_PIN_2
#define BAND1_DIS_GPIO_Port GPIOB
#define BAND0_EN_Pin GPIO_PIN_10
#define BAND0_EN_GPIO_Port GPIOB
#define BAND0_DIS_Pin GPIO_PIN_11
#define BAND0_DIS_GPIO_Port GPIOB
#define TX_EN_Pin GPIO_PIN_12
#define TX_EN_GPIO_Port GPIOB
#define RX_EN_Pin GPIO_PIN_13
#define RX_EN_GPIO_Port GPIOB
#define INPUT_TX_FAIL_Pin GPIO_PIN_6
#define INPUT_TX_FAIL_GPIO_Port GPIOC
#define INPUT_TXON_Pin GPIO_PIN_12
#define INPUT_TXON_GPIO_Port GPIOC
#define BAND8_EN_Pin GPIO_PIN_5
#define BAND8_EN_GPIO_Port GPIOB
#define BAND6_EN_Pin GPIO_PIN_6
#define BAND6_EN_GPIO_Port GPIOB
#define BAND7_EN_Pin GPIO_PIN_7
#define BAND7_EN_GPIO_Port GPIOB
#define BAND7_DIS_Pin GPIO_PIN_8
#define BAND7_DIS_GPIO_Port GPIOB
#define BAND8_DIS_Pin GPIO_PIN_9
#define BAND8_DIS_GPIO_Port GPIOB

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
