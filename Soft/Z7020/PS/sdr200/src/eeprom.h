/*
 * eeprom.h
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#ifndef SRC_EEPROM_H_
#define SRC_EEPROM_H_

#define EEPROM_SPI_SELECT	0x01

#define EEPROM_CONST_OFFSET	0
#define EEPROM_VARS_OFFSET	16384
#define EEPROM_VARS_SIZE	49152
#define EEPROM_VARS_LENGHT	2048
#define EEPROM_FREQ_POINTS	256

typedef struct tag_eeprom_message
{
	uint8_t type;
	uint16_t address;
	size_t bytes;
	uint8_t* data;
} s_eeprom_message;

typedef struct tag_eeprom_freq
{
	uint32_t freq;
	uint8_t att;
} s_eeprom_freq;

typedef struct tag_eeprom_const
{
	uint32_t rxa_cnt;
	s_eeprom_freq rxa_att[EEPROM_FREQ_POINTS];
	uint8_t txa_cnt;
	s_eeprom_freq txa_att[EEPROM_FREQ_POINTS];
	uint8_t txafbV_cnt;
	s_eeprom_freq txafbV_att[EEPROM_FREQ_POINTS];
	uint8_t txafbC_cnt;
	s_eeprom_freq txafbC_att[EEPROM_FREQ_POINTS];
} s_eeprom_const;

typedef struct tag_eeprom_vars
{
	uint32_t vfoA;
	uint32_t vfoB;
	uint8_t AFGain;
	uint8_t RFGain;
	uint8_t AGCType;
	uint8_t mode;
	uint8_t RFPower;
	uint8_t RXAATT;
	int16_t vRef;
	uint8_t lim_en;
	uint8_t lim_in;
	uint8_t lim_out;
} s_eeprom_vars;

extern s_eeprom_vars* e_vars;

void eeprom_init(void);
void eeprom_read(uint32_t address, size_t bytes, uint8_t* data);
void eeprom_write(uint32_t address, size_t bytes, uint8_t* data);
void eeprom_write_const(void);
void eeprom_write_vars(void);
void eeprom_read_const(void);
void eeprom_read_vars(void);
void eeprom_vars_changed(void);
uint8_t eeprom_rxa_att(uint32_t freq);
uint8_t eeprom_txa_att(uint32_t freq);
uint8_t eeprom_txafbV_att(uint32_t freq);
uint8_t eeprom_txafbC_att(uint32_t freq);

#endif /* SRC_EEPROM_H_ */
