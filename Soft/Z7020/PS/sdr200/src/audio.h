/*
 * audio.h
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#ifndef SRC_AUDIO_H_
#define SRC_AUDIO_H_

#define IIC_AUDIO_SLAVE_ADDR		0x1A

typedef enum tag_audio_input {
	AUDIO_IN_MIC,
	AUDIO_IN_USB
} e_audio_input;

void audio_init(void);
void audio_speaker_volume(uint8_t left, uint8_t right);
void audio_headphone_volume(uint8_t left, uint8_t right);
void audio_dac_volume(uint8_t left, uint8_t right);
void audio_set_input(e_audio_input in);

#endif /* SRC_AUDIO_H_ */
