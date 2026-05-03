/*
 * ext_amp.h
 *
 *  Created on: 22 мар. 2026 г.
 *      Author: user
 */

#ifndef SRC_EXT_AMP_H_
#define SRC_EXT_AMP_H_

void extAmpInit(void);
void extAmpSend(uint8_t* data, size_t len);
void extAmpSetFreq(uint32_t freq);

#endif /* SRC_EXT_AMP_H_ */
