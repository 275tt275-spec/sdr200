/*
 * crc16.h
 *
 *  Created on: 02.09.2013
 *      Author: V.Titov
 */

#ifndef CRC16_H_
#define CRC16_H_

#define LOBYTE(w) ((unsigned char)(w))
#define HIBYTE(w) ((unsigned char)(((unsigned short)(w) >> 8) & 0xFF))

unsigned short CalcCrc (unsigned char* Str, unsigned short NumBytes);
unsigned short CalcCrcFast(unsigned char* puchMsg , unsigned short usDataLen);


#endif /* CRC16_H_ */
