/*
 * audio.c
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#include "xparameters.h"
#include "xil_printf.h"
#include "FreeRTOS.h"
#include "semphr.h"
#include "event_groups.h"

#include "nau8822.h"
#include "audio.h"
#include "hw.h"

static void nau8822_register_write(uint8_t reg_number, uint16_t reg_value);

void audio_init(void)
{
	/* Reset the codec */
	nau8822_register_write(NAU8822_REG_RESET, 0x00);

	/* R49 Bit 2, SPKBST; Bit 3, AUX2BST; Bit 4, AUX1BST, set to logic = 1 */
	nau8822_register_write(NAU8822_REG_OUTPUT_CONTROL, (1 << 6) | (1 << 5) | (1 << 4) | (1 << 3) |  (1 << 2) | (1 << 1));

	/* Power Management 1 */
	uint16_t value = 0x104;
	nau8822_register_write(NAU8822_REG_POWER_MANAGEMENT_1, value); /* Power control for AUX1 MIXER supporting AUXOUT1 analog output */
	value = 0x10D;
	nau8822_register_write(NAU8822_REG_POWER_MANAGEMENT_1, value);
	/* After this, outputs may be enabled, but with the drivers still in the mute condition. Unless power management
requires outputs to be turned off when not used, it is best for pops and clicks to leave outputs enabled at all times,
and to use the output mute controls to silence the outputs as needed.
Next, the NAU8822 can be programmed as needed for a specific application. The final step in most applications
will be to unmute any outputs, and then begin normal operation.
*/
	vTaskDelay(pdMS_TO_TICKS( 250 ));
	value |= (1 << 7);
	nau8822_register_write(NAU8822_REG_POWER_MANAGEMENT_1, value);
	/* Power Management 2 */
	nau8822_register_write(NAU8822_REG_POWER_MANAGEMENT_2, (1 << 8) | (1 << 7) | (1 << 5) |
			(1 << 4) | (1 << 3) | (1 << 2) | (1 << 1) | (1 << 0));
	/* Power Management 3 */
	nau8822_register_write(NAU8822_REG_POWER_MANAGEMENT_3, 0x1FF);
	/* Audio Interface */
	nau8822_register_write(NAU8822_REG_AUDIO_INTERFACE, (3 << 5));
	/* Clock control 1 */
	nau8822_register_write(NAU8822_REG_CLOCKING, 3 << 5); /* master clock source divide by 3 */
	/* Clock control 2 */
	nau8822_register_write(NAU8822_REG_ADDITIONAL_CONTROL, NAU8822_SMPLR_16K);
	nau8822_register_write(NAU8822_REG_ADC_CONTROL, (1 << 8) | (1 << 7) | (4 << 4) | (1 << 2));

	/*  AUX1 MIXER */
	nau8822_register_write(NAU8822_REG_AUX1_MIXER, (1 << 0)); /* Right DAC output to AUX1 MIXER input path control */
	/* Right Speaker Submixer */
	nau8822_register_write(NAU8822_REG_RIGHT_SPEAKER_CONTROL, (1 << 4)); /* right speaker amplifier connected to submixer output (inverts RMIX for BTL) */
	audio_speaker_volume(56, 56);
	audio_headphone_volume(56, 56);
	audio_dac_volume(255, 255);

	nau8822_register_write(NAU8822_REG_DAC_CONTROL, (1 << 3)); /* 128x oversampling */
}

void audio_speaker_volume(uint8_t left, uint8_t right)
{
	if(left >= 64) { left = 63;	}
	if(right >= 64) { right = 63; }

	nau8822_register_write(NAU8822_REG_RSPKOUT_VOLUME, right);
	nau8822_register_write(NAU8822_REG_LSPKOUT_VOLUME, (1 << 8) | left);
};

void audio_headphone_volume(uint8_t left, uint8_t right)
{
	if(left >= 64) { left = 63;	}
	if(right >= 64) { right = 63; }

	nau8822_register_write(NAU8822_REG_RHP_VOLUME, right);
	nau8822_register_write(NAU8822_REG_LHP_VOLUME, (1 << 8) | left);
};

void audio_dac_volume(uint8_t left, uint8_t right)
{
	nau8822_register_write(NAU8822_REG_RIGHT_DAC_DIGITAL_VOLUME, right);
	nau8822_register_write(NAU8822_REG_LEFT_DAC_DIGITAL_VOLUME, (1 << 8) | left);
};

void audio_set_input(e_audio_input in)
{
	if(in == AUDIO_IN_USB)
	{
		nau8822_register_write(NAU8822_REG_INPUT_CONTROL, 0);
//		nau8822_register_write(NAU8822_REG_LEFT_MIXER_CONTROL, (0 << 6) | ( 1 << 5));
//		nau8822_register_write(NAU8822_REG_RIGHT_MIXER_CONTROL, (0 << 6) | ( 1 << 5));

		nau8822_register_write(NAU8822_REG_LEFT_INP_PGA_CONTROL, (1 << 6));
		nau8822_register_write(NAU8822_REG_RIGHT_INP_PGA_CONTROL, (1 << 8) | (1 << 6));

		nau8822_register_write(NAU8822_REG_LEFT_ADC_BOOST_CONTROL, (5 << 0));
		nau8822_register_write(NAU8822_REG_RIGHT_ADC_BOOST_CONTROL, (5 << 0));
	}
	else
	{
		nau8822_register_write(NAU8822_REG_INPUT_CONTROL, (3 << 4) | ( 3 << 0));
//		nau8822_register_write(NAU8822_REG_LEFT_MIXER_CONTROL, 0);
//		nau8822_register_write(NAU8822_REG_RIGHT_MIXER_CONTROL, 0);

		nau8822_register_write(NAU8822_REG_LEFT_INP_PGA_CONTROL, 16);
		nau8822_register_write(NAU8822_REG_RIGHT_INP_PGA_CONTROL, (1 << 8) | 16);

		nau8822_register_write(NAU8822_REG_LEFT_ADC_BOOST_CONTROL, (1 << 8));
		nau8822_register_write(NAU8822_REG_RIGHT_ADC_BOOST_CONTROL, (1 << 8));
	}
}

static void nau8822_register_write(uint8_t reg_number, uint16_t reg_value)
{
	uint8_t data[2] = {(reg_number & 0x7F) << 1 | ((reg_value & 0x0100) >> 8), (uint8_t)(reg_value & 0xFF)};
	hw_iic_write(IIC_AUDIO_SLAVE_ADDR, data, sizeof(data));
}


