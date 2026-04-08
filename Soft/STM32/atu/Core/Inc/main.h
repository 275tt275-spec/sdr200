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
#define TX_EN_Pin GPIO_PIN_13
#define TX_EN_GPIO_Port GPIOC
#define RX_EN_Pin GPIO_PIN_14
#define RX_EN_GPIO_Port GPIOC
#define BYPASS0_Pin GPIO_PIN_15
#define BYPASS0_GPIO_Port GPIOC
#define CAP_SEL_Pin GPIO_PIN_0
#define CAP_SEL_GPIO_Port GPIOD
#define SEL_L1_Pin GPIO_PIN_1
#define SEL_L1_GPIO_Port GPIOD
#define SEL_L2_Pin GPIO_PIN_0
#define SEL_L2_GPIO_Port GPIOA
#define SEL_L3_Pin GPIO_PIN_1
#define SEL_L3_GPIO_Port GPIOA
#define SEL_L4_Pin GPIO_PIN_2
#define SEL_L4_GPIO_Port GPIOA
#define SEL_L5_Pin GPIO_PIN_3
#define SEL_L5_GPIO_Port GPIOA
#define SEL_L6_Pin GPIO_PIN_4
#define SEL_L6_GPIO_Port GPIOA
#define SEL_L7_Pin GPIO_PIN_5
#define SEL_L7_GPIO_Port GPIOA
#define EXT_AMP_Pin GPIO_PIN_6
#define EXT_AMP_GPIO_Port GPIOA
#define SEL_C7_Pin GPIO_PIN_7
#define SEL_C7_GPIO_Port GPIOA
#define SEL_C6_Pin GPIO_PIN_4
#define SEL_C6_GPIO_Port GPIOC
#define SEL_C5_Pin GPIO_PIN_5
#define SEL_C5_GPIO_Port GPIOC
#define SEL_C4_Pin GPIO_PIN_0
#define SEL_C4_GPIO_Port GPIOB
#define SEL_C3_Pin GPIO_PIN_8
#define SEL_C3_GPIO_Port GPIOA
#define SEL_C1_Pin GPIO_PIN_10
#define SEL_C1_GPIO_Port GPIOA
#define SEL_C2_Pin GPIO_PIN_11
#define SEL_C2_GPIO_Port GPIOA
#define TX_ON_Pin GPIO_PIN_12
#define TX_ON_GPIO_Port GPIOC

/* USER CODE BEGIN Private defines */

/* USER CODE END Private defines */

#ifdef __cplusplus
}
#endif

#endif /* __MAIN_H */
