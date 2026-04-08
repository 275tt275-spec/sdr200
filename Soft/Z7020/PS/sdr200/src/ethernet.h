/*
 * ethernet.h
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#ifndef SRC_ETHERNET_H_
#define SRC_ETHERNET_H_

#ifdef XPAR_XEMACPS_3_BASEADDR
#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_3_BASEADDR
#endif
#ifdef XPAR_XEMACPS_2_BASEADDR
#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_2_BASEADDR
#endif
#ifdef XPAR_XEMACPS_1_BASEADDR
#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_1_BASEADDR
#endif
#ifdef XPAR_XEMACPS_0_BASEADDR
#define PLATFORM_EMAC_BASEADDR XPAR_XEMACPS_0_BASEADDR
#endif


#define PORT_DDC0_DEFAULT       1035
#define THREAD_STACKSIZE        1024
#define MAIN_THREAD_STACKSIZE   2048
#define MAX_FILENAME 			256
#define HTTP_PORT    			80
#define UDP_SERVER_PORT_IN		1024
#define	UDPIO_PACKET_SIZE		1440

#define DEFAULT_IP_ADDRESS      "10.1.1.147"
#define DEFAULT_IP_MASK         "255.255.255.0"
#define DEFAULT_GW_ADDRESS      "10.1.1.254"

#define EXTIO_COMMAND_STARTHW           2
#define EXTIO_COMMAND_STOPHW            3
#define EXTIO_COMMAND_SETHWLO           4
#define EXTIO_COMMAND_SETATT            5
#define EXTIO_COMMAND_SETAGC            6
#define EXTIO_COMMAND_SETMODE           7

#define EXTIO_SETAGC_OFF                0
#define EXTIO_SETAGC_LONG               1
#define EXTIO_SETAGC_SLOW               2
#define EXTIO_SETAGC_MEDIUM             3
#define EXTIO_SETAGC_FAST               4

#pragma pack(push, 1)
typedef struct tag_extio
{
    uint32_t    cmd;
    uint8_t     payload[1024];
} s_extio;
#pragma pack(pop)

void ethernet_init(void);
void ethernet_deinit(void);
int ethernet_SendUdp(uint32_t destIp, uint16_t destPort, uint8_t* buf, uint32_t len);
void ethernet_SendIQ(uint8_t* buf, uint32_t len);

#endif /* SRC_ETHERNET_H_ */
