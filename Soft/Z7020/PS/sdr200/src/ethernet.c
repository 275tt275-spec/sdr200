/*
 * ethernet.c
 *
 *  Created on: 20 окт. 2025 г.
 *      Author: VictorT
 */

#include <string.h>

#include "xparameters.h"
#include "netif/xadapter.h"
#include "xil_printf.h"
#include "lwip/init.h"
#include "lwip/inet.h"
#include "lwip/netif.h"
#include "lwip/sockets.h"
#include "lwip/sys.h"
#if (LWIP_DHCP == 1)
#include "lwip/dhcp.h"
#endif

#include "ethernet.h"
#include "hw.h"
#include "eeprom.h"
#include "KenwoodCmd.h"

struct netif server_netif;
static int nw_thread_done = 0;
struct udp_pcb *pcb;
static uint32_t mServerIP = 0;
static uint16_t mServerIQPort = PORT_DDC0_DEFAULT;
#define ETH_LINK_DETECT_INTERVAL	250
static int mEnableDDC = 0;

extern void link_detect_thread(void *p);
static void network_thread(void *p);
static void ethernet_thread(void *p);
static void ethernet_application(void);
static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);
static void print_ip(char *msg, ip_addr_t *ip);
static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw);

void ethernet_init(void)
{
	sys_thread_new("ethernet_thread", (void(*)(void*))ethernet_thread, NULL,
			MAIN_THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
}


int ethernet_SendUdp(uint32_t destIp, uint16_t destPort, uint8_t* buf, uint32_t len)
{
	err_t err = ERR_OK;
	ip_addr_t dst_ip;
	dst_ip.addr = destIp;

	struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, len, PBUF_POOL);
	if (!p) {
		xil_printf("Error allocating pbuf\r\n");
		return ERR_MEM;
	}
	memcpy(p->payload, buf, len);

	err = udp_sendto(pcb, p, &dst_ip, destPort);

	if (err != ERR_OK)
		xil_printf("UDP send error\r\n");

	pbuf_free(p);
	return err;
}

void ethernet_SendIQ(uint8_t* buf, uint32_t len)
{
	if((mServerIP != 0) && (mEnableDDC == 1))
	{
		ethernet_SendUdp(mServerIP, mServerIQPort, buf, len);
	}
}

void ethernet_deinit(void)
{
	struct netif *netif = &server_netif;

	udp_remove(pcb);
	netif_set_down(netif);
}

/** Receive data on a udp session */
static void udp_recv_traffic(void *arg, struct udp_pcb *tpcb,
		struct pbuf *p, const ip_addr_t *addr, u16_t port)
{
//	s32_t recv_id = ntohl(*((int *)(p->payload)));

	uint64_t value64;
	uint32_t value32;
	s_extio* pExtio = (s_extio*)p->payload;

		switch(pExtio->cmd)
		{
		case EXTIO_COMMAND_STARTHW:
			xil_printf("udp_recv_traffic: EXTIO_COMMAND_STARTHW\n");
			mEnableDDC = 1;
			mServerIP = addr->addr;
			memcpy(&mServerIQPort, pExtio->payload, sizeof(mServerIQPort));
			ethernet_SendUdp(mServerIP, port, p->payload, p->len);
			break;
		case EXTIO_COMMAND_STOPHW:
			xil_printf("udp_recv_traffic: EXTIO_COMMAND_STOPHW\n");
			mEnableDDC = 0;
			break;
		case EXTIO_COMMAND_SETHWLO:
			memcpy(&value64, pExtio->payload, sizeof(value64));
//			xil_printf("udp_recv_traffic: EXTIO_COMMAND_SETHWLO %u\n", (uint32_t)value64);
			e_vars->vfoA = (uint32_t)value64;
			hw_SetRXAFreq(e_vars->vfoA);
//			hw_SetTXAFreq((uint32_t)value64);
			kenwood_SetFrequency((uint32_t)value64);
			eeprom_vars_changed();
			break;
		case EXTIO_COMMAND_SETATT:
			memcpy(&value32, pExtio->payload, sizeof(value32));
			switch(value32)
			{
			case 0: e_vars->RXAATT = 0; break;
			case 1: e_vars->RXAATT = 10; break;
			case 2: e_vars->RXAATT = 20; break;
			case 3: e_vars->RXAATT = 30; break;
			}
			hw_SetRXAAtt((float)e_vars->RXAATT);
			eeprom_vars_changed();
			break;
		case EXTIO_COMMAND_SETAGC:
			memcpy(&value32, pExtio->payload, sizeof(value32));
			hw_SetAGC(value32);
			e_vars->AGCType = value32;
			eeprom_vars_changed();
			break;
		case EXTIO_COMMAND_SETMODE:
			memcpy(&value32, pExtio->payload, sizeof(value32));
			hw_SetRXAMode(value32);
			hw_SetTXAMode(value32);
			kenwood_SetMode(value32);
			e_vars->mode = value32;
			eeprom_vars_changed();
			break;
		}

	pbuf_free(p);
	return;
}

static void ethernet_application(void)
{
	err_t err;

	/* Create Server PCB */
	pcb = udp_new();
	if (!pcb) {
		xil_printf("UDP server: Error creating PCB. Out of Memory\r\n");
		return;
	}

	err = udp_bind(pcb, IP_ADDR_ANY, UDP_SERVER_PORT_IN);
	if (err != ERR_OK) {
		xil_printf("UDP server: Unable to bind to port");
		xil_printf(" %d: err = %d\r\n", UDP_SERVER_PORT_IN, err);
		udp_remove(pcb);
		return;
	}

	xil_printf("UDP server: Bind port %d\r\n", UDP_SERVER_PORT_IN);

	/* specify callback to use for incoming connections */
	udp_recv(pcb, udp_recv_traffic, NULL);
}

static void ethernet_thread(void *p)
{
#if (LWIP_DHCP == 1)
	int mscnt = 0;
#endif

	/* initialize lwIP before calling sys_thread_new */
	lwip_init();

	/* any thread using lwIP should be created using sys_thread_new */
	sys_thread_new("nw_thread", network_thread, NULL,
			THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);

	/* wait for nw thread to finish initialization */
	while (!nw_thread_done)
		vTaskDelay(pdMS_TO_TICKS(100)); /* 100 millisecond */

#if (LWIP_DHCP == 1)
	while (1) {
		vTaskDelay(pdMS_TO_TICKS(DHCP_FINE_TIMER_MSECS));

		if (server_netif.ip_addr.addr) {
			xil_printf("DHCP request success\r\n");
			break;
		}

		mscnt += DHCP_FINE_TIMER_MSECS;
		if (mscnt >= 10000) {
			xil_printf("ERROR: DHCP request timed out\r\n");
			assign_default_ip(&(server_netif.ip_addr),
				&(server_netif.netmask), &(server_netif.gw));
			break;
		}
	}
#else
	assign_default_ip(&(server_netif.ip_addr), &(server_netif.netmask),
			&(server_netif.gw));
#endif

	print_ip_settings(&server_netif.ip_addr, &server_netif.netmask,
			&server_netif.gw);

	/* start the application */
	ethernet_application();

	vTaskDelete(NULL);
}

static void network_thread(void *p)
{
#if (LWIP_DHCP == 1)
	int mscnt = 0;
#endif
	/* the mac address of the board. this should be unique per board */
	u8 mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };

	/* Add network interface to the netif_list, and set it as default */
	if (!xemac_add(&server_netif, NULL, NULL, NULL,
			mac_ethernet_address, PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\r\n");
		return;
	}

	netif_set_default(&server_netif);

	/* specify that the network if is up */
	netif_set_up(&server_netif);

	/* start packet receive thread - required for lwIP operation */
	sys_thread_new("xemacif_input_thread",
			(void(*)(void*))xemacif_input_thread, &server_netif,
			THREAD_STACKSIZE, DEFAULT_THREAD_PRIO);
	/* Start thread to detect link periodically for Hot Plug autodetect */
	sys_thread_new("link_detect_thread", link_detect_thread, &server_netif,
			THREAD_STACKSIZE, tskIDLE_PRIORITY);

#if (LWIP_DHCP == 1)
	dhcp_start(&server_netif);
	nw_thread_done = 1;
	while (1) {
		vTaskDelay(pdMS_TO_TICKS(DHCP_FINE_TIMER_MSECS));
		dhcp_fine_tmr();
		mscnt += DHCP_FINE_TIMER_MSECS;
		if (mscnt >= DHCP_COARSE_TIMER_SECS*1000) {
			dhcp_coarse_tmr();
			mscnt = 0;
		}
	}
#else
	nw_thread_done = 1;
	vTaskDelete(NULL);
#endif
}

static void assign_default_ip(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
	int err;

	xil_printf("Configuring default IP %s\r\n", DEFAULT_IP_ADDRESS);

	err = inet_aton(DEFAULT_IP_ADDRESS, ip);
	if(!err)
		xil_printf("Invalid default IP address: %d\r\n", err);

	err = inet_aton(DEFAULT_IP_MASK, mask);
	if(!err)
		xil_printf("Invalid default IP MASK: %d\r\n", err);

	err = inet_aton(DEFAULT_GW_ADDRESS, gw);
	if(!err)
		xil_printf("Invalid default gateway address: %d\r\n", err);
}

static void print_ip(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\r\n", ip4_addr1(ip), ip4_addr2(ip),
				ip4_addr3(ip), ip4_addr4(ip));
}

static void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
	print_ip("Board IP:       ", ip);
	print_ip("Netmask :       ", mask);
	print_ip("Gateway :       ", gw);
	xil_printf("\r\n");
}
