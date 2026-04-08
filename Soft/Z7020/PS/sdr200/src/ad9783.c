/*
 * ad9783.c
 *
 *  Created on: 7 но€б. 2025 г.
 *      Author: user
 */

#include "xparameters.h"	/* EDK generated parameters */
#include "xspips.h"			/* SPI device driver */
#include "FreeRTOS.h"
#include "semphr.h"
#include "xil_printf.h"
#include "xgpiops.h"
#ifdef SDT
#include "xinterrupt_wrap.h"
#endif

#include "hw.h"
#include "ad9783.h"

extern XSpiPs Spi1Instance;
extern SemaphoreHandle_t xSPI1Sem;

static uint8_t ad9783_read(uint8_t reg);
static void ad9783_write(uint8_t reg, uint8_t value);
static void ad9783_SetTxDacImage(uint32_t value);
static void ad9783_SetTxDacReal(uint32_t value);

#define GPIO_DAC_RESET		33

/* AD9783 Registers */
#define AD9783_REG_SPI_CONTROL          0x00
#define AD9783_REG_DATA_CONTROL         0x02
#define AD9783_REG_POWER_DOWN           0x03
#define AD9783_REG_SETUP_AND_HOLD       0x04
#define AD9783_REG_TIMING_ADJUST        0x05
#define AD9783_REG_SEEK                 0x06
#define AD9783_REG_MIX_MODE             0x0A
#define AD9783_REG_DAC1_FSC             0x0B
#define AD9783_REG_DAC1_FSC_MSBS        0x0C
#define AD9783_REG_AUXDAC1              0x0D
#define AD9783_REG_AUXDAC1_MSB          0x0E
#define AD9783_REG_DAC2_FSC             0x0F
#define AD9783_REG_DAC2_FSC_MSBS        0x10
#define AD9783_REG_AUXDAC2              0x11
#define AD9783_REG_AUXDAC2_MSB          0x12
#define AD9783_REG_BIST_CONTROL         0x1A
#define AD9783_REG_BIST_RESULT_1_LOW    0x1B
#define AD9783_REG_BIST_RESULT_1_HIGH   0x1C
#define AD9783_REG_BIST_RESULT_2_LOW    0x1D
#define AD9783_REG_BIST_RESULT_2_HIGH   0x1E
#define AD9783_REG_HARDWARE_REVISION    0x1F

/* AD9783_REG_SETUP_AND_HOLD */
#define AD9783_SET               0xF0
#define AD9783_HLD               0x0F
#define AD9783_SH_RESET          0x00
#define AD9783_SEEK             (1 << 0)
#define AD9783_MAX_SAMPL_DLY	(1 << 5)
#define AD9783_MAX_SET			(1 << 4)
#define AD9783_MAX_HLD			(1 << 4)

/* AD9783 timing defs */
#define SEEK                            0
#define SET                             1
#define HLD                             2

static int ad9783_seek(void)
{
	uint8_t val = ad9783_read(AD9783_REG_SEEK);
	return val & AD9783_SEEK;
}

static void regmap_update_bits( unsigned int reg, unsigned int mask, unsigned int val)
{
    unsigned int tmp, orig;

    orig = ad9783_read(reg);

    tmp = orig& ~mask;
    tmp |= val & mask;

    if (tmp != orig) {
    	ad9783_write(reg, tmp);
    }
}

static void ad9783_timing_adjust(void)
{
	int ret, i, smp, set, hld, min = AD9783_MAX_SET;
	unsigned char table[AD9783_MAX_SAMPL_DLY][3];

	for (smp = 0; smp < AD9783_MAX_SAMPL_DLY; smp++) {
		ad9783_write(AD9783_REG_SETUP_AND_HOLD, AD9783_SH_RESET);

		ad9783_write(AD9783_REG_TIMING_ADJUST, smp);

		ret = ad9783_seek();
		if (ret < 0)
			return;

		table[smp][SEEK] = ret;
		set = 0;
		hld = 0;
		do {
			hld++;
			regmap_update_bits(AD9783_REG_SETUP_AND_HOLD, AD9783_HLD, hld);

			ret = ad9783_seek();
			if (ret < 0)
				return;
		} while ((ret == table[smp][SEEK]) && hld < (AD9783_MAX_HLD - 1));

		table[smp][HLD] = hld;
		hld = 0;
		ad9783_write(AD9783_REG_SETUP_AND_HOLD, AD9783_SH_RESET);

		do {
			set++;
			regmap_update_bits(AD9783_REG_SETUP_AND_HOLD, AD9783_SET, set << 4);

			ret = ad9783_seek();
			if (ret < 0)
				return;

		} while ((ret == table[smp][SEEK]) && set < (AD9783_MAX_SET - 1));

		table[smp][SET] = set;
	}

	for (smp = -1, i = 0; i < AD9783_MAX_SAMPL_DLY; i++) {
		if (table[i][SEEK] == 1 && table[i][SET] < table[i][HLD]) {
			ret = table[i][HLD] - table[i][SET];
			if (ret <= min) {
				min = ret;
				set = table[i][SET];
				hld = table[i][HLD];
				smp = i;
			}
		}
	}
	if (smp < 0) {
		xil_printf("Could not find and optimal value for the port timing \r\n");
		return;
	}

	ret = 0;
	if (!((table[smp][HLD] + table[smp][SET]) > 8))
		ret = 1;
	if (smp == 0) {
		if (table[smp + 1][SEEK] == 0)
			ret = 1;
	} else if (smp == AD9783_MAX_SAMPL_DLY - 1) {
		if (table[smp - 1][SEEK] == 0)
			ret = 1;
	} else {
		if (!(table[smp - 1][SEEK] == table[smp + 1][SEEK] &&
			  table[smp - 1][SEEK] == 1))
			ret = 1;
	}
	if (ret)
		xil_printf("Please check for excessive on the input clock line.\r\n");

	ad9783_write(AD9783_REG_TIMING_ADJUST, smp);

	regmap_update_bits(AD9783_REG_SETUP_AND_HOLD, AD9783_SET, set << 4);
	regmap_update_bits(AD9783_REG_SETUP_AND_HOLD, AD9783_HLD, hld);

	xil_printf("ad9783: smp:%d, set:%d, hld:%d\r\n", smp, set, hld);
}

void ad9783_InitTXADac(void)
{
	XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_DAC_RESET, 0x1);
	vTaskDelay(pdMS_TO_TICKS( 10 ));
	XGpioPs_WritePin(&hw_device.GpioInstance, GPIO_DAC_RESET, 0x0);
	vTaskDelay(pdMS_TO_TICKS( 100 ));

//    uint8_t rValue = ad9783_read(AD9783_REG_DAC1_FSC);
//    xil_printf("ad9783: DAC1 FSC 0x%02X\n", rValue);
    ad9783_write(AD9783_REG_DATA_CONTROL, (1 << 4));
    ad9783_write(AD9783_REG_MIX_MODE, 0);

    ad9783_timing_adjust();

	ad9783_SetTxDacImage(1023);
	ad9783_SetTxDacReal(1023);

}

static void ad9783_SetTxDacImage(uint32_t value)
{
	ad9783_write(AD9783_REG_DAC1_FSC, value & 0xFF);  // DAC1 FSC
	ad9783_write(AD9783_REG_DAC1_FSC_MSBS, (value >> 8) & 0x03);  // DAC1 FSC
}

static void ad9783_SetTxDacReal(uint32_t value)
{
	ad9783_write(AD9783_REG_DAC2_FSC, value & 0xFF);  // DAC2 FSC
	ad9783_write(AD9783_REG_DAC2_FSC_MSBS, (value >> 8) & 0x03);  // DAC2 FSC
}

static uint8_t ad9783_read(uint8_t reg)
{
    uint8_t send[2] = {(uint8_t)(reg & 0x7F), 0};
    uint8_t rcv[2] = {0};
    send[0] |= 0x80;

    xSemaphoreTake( xSPI1Sem, pdMS_TO_TICKS( 4000 ));
    XSpiPs_SetSlaveSelect(&Spi1Instance, AD9783_SPI_SELECT);
    XSpiPs_PolledTransfer(&Spi1Instance, send, rcv, 2);
    xSemaphoreGive(xSPI1Sem);

    return rcv[1];
}

static void ad9783_write(uint8_t reg, uint8_t value)
{
    uint8_t send[2] = {(uint8_t)(reg & 0x7F), value};
    xSemaphoreTake( xSPI1Sem, pdMS_TO_TICKS( 4000 ));
    XSpiPs_SetSlaveSelect(&Spi1Instance, AD9783_SPI_SELECT);
    XSpiPs_PolledTransfer(&Spi1Instance, send, NULL, 2);
    xSemaphoreGive(xSPI1Sem);
}

void _ad9783_write(uint8_t reg, uint8_t value)
{
	ad9783_write(reg, value);
}
