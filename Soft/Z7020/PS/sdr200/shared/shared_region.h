/*
 * shared_region.h
 *
 *  Created on: 19 июн. 2026 г.
 *      Author: VictorT
 */

#ifndef SHARED_SHARED_REGION_H_
#define SHARED_SHARED_REGION_H_

#define OCM_SHARED_SECTION 	0xFFFF0000
#define SGI_TO_CORE1 		0  // ID прерывания для Core 1
#define TARGET_CORE1 		2  // Битовая маска для Core 1 (Core 0 = 1, Core 1 = 2)
#define CORE1_START_REG 	0xFFFFFFF0
#define SHARED_BUFFER_SIZE	16384

typedef struct tag_shared_buffer {
	uint32_t rd_cnt;
	uint32_t wr_cnt;
	uint32_t type;
	uint32_t lenght;
	uint32_t data;
} s_shared_buffer;

extern volatile s_shared_buffer* Core0toCore1;
extern volatile s_shared_buffer* Core1toCore0;

#endif /* SHARED_SHARED_REGION_H_ */
