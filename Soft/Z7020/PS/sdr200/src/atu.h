/*
 * atu.h
 *
 *  Created on: 13 февр. 2026 г.
 *      Author: VictorT
 */

#ifndef SRC_ATU_H_
#define SRC_ATU_H_

#ifdef __cplusplus
extern "C" {
#endif

void atu_tune(uint32_t freq);
int atu_GetBypass(void);

#ifdef __cplusplus
}
#endif


#endif /* SRC_ATU_H_ */
